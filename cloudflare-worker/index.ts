export interface Env {
  ORIGIN_URL: string; // The backend API origin, e.g. "https://api.memoryapp.com"
  RATE_LIMIT_KV: any; // Cloudflare KV Namespace binding
}

export default {
  async fetch(request: Request, env: Env, ctx: any): Promise<Response> {
    const url = new URL(request.url);
    const clientIp = request.headers.get("CF-Connecting-IP") || "127.0.0.1";

    // 1. Edge Rate Limiting (IP-based sliding window using Workers KV)
    const isRateLimited = await handleRateLimit(clientIp, env);
    if (isRateLimited) {
      return new Response("Too Many Requests (Rate limit exceeded at Cloudflare Edge)", {
        status: 429,
        headers: { "Content-Type": "text/plain" },
      });
    }

    // 2. Edge Caching Rules
    const cache = (caches as any).default;

    // Cache rule for Username Check (GET /auth/username-check)
    if (request.method === "GET" && url.pathname === "/auth/username-check") {
      let response = await cache.match(request);
      if (response) {
        return response;
      }

      // Fetch from origin
      response = await fetchFromOrigin(request, env);
      
      // If 200 OK, cache for 5 minutes
      if (response.status === 200) {
        const cacheResponse = new Response(response.body, response);
        cacheResponse.headers.set("Cache-Control", "public, max-age=300");
        ctx.waitUntil(cache.put(request, cacheResponse.clone()));
        return cacheResponse;
      }
      return response;
    }

    // Cache rule for Memories Feed (GET /memories/feed) - User-specific cache key
    if (request.method === "GET" && url.pathname === "/memories/feed") {
      const authHeader = request.headers.get("Authorization");
      if (authHeader && authHeader.startsWith("Bearer ")) {
        const token = authHeader.substring(7);
        const tokenHash = await hashString(token);
        
        // Construct a unique user-specific cache URL key
        const cacheUrl = new URL(request.url);
        cacheUrl.searchParams.set("__user_token_hash", tokenHash);
        const cacheKey = new Request(cacheUrl.toString(), request);

        let response = await cache.match(cacheKey);
        if (response) {
          return response;
        }

        // Fetch from origin
        response = await fetchFromOrigin(request, env);

        // If 200 OK, cache for 30 seconds
        if (response.status === 200) {
          const cacheResponse = new Response(response.body, response);
          cacheResponse.headers.set("Cache-Control", "public, max-age=30");
          ctx.waitUntil(cache.put(cacheKey, cacheResponse.clone()));
          return cacheResponse;
        }
        return response;
      }
    }

    // 3. Fallback: Proxy all other requests to the origin backend
    return fetchFromOrigin(request, env);
  }
};

async function fetchFromOrigin(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  // Rewrite destination host to origin backend URL
  const originUrl = env.ORIGIN_URL || "http://localhost:3000";
  const originRequestUrl = `${originUrl.endsWith('/') ? originUrl.slice(0, -1) : originUrl}${url.pathname}${url.search}`;
  
  // Clone request headers and proxy
  const newRequest = new Request(originRequestUrl, {
    method: request.method,
    headers: request.headers,
    body: request.body,
    redirect: "manual"
  });

  return fetch(newRequest);
}

// Compute SHA-256 hash using Web Crypto API
async function hashString(str: string): Promise<string> {
  const msgUint8 = new TextEncoder().encode(str);
  const hashBuffer = await crypto.subtle.digest("SHA-256", msgUint8);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, "0")).join("");
}

// Rate Limiting helper: max 100 requests per 60 seconds per IP address
async function handleRateLimit(ip: string, env: Env): Promise<boolean> {
  if (!env.RATE_LIMIT_KV) {
    // If KV binding is not configured, skip edge rate limiting to avoid failure
    return false;
  }

  const limit = 100;
  const windowSeconds = 60;
  const currentMinute = Math.floor(Date.now() / 1000 / windowSeconds);
  const key = `rl:${ip}:${currentMinute}`;

  try {
    const value = await env.RATE_LIMIT_KV.get(key);
    const count = value ? parseInt(value, 10) : 0;

    if (count >= limit) {
      return true; // Rate limited
    }

    // Increment count
    await env.RATE_LIMIT_KV.put(key, (count + 1).toString(), {
      expirationTtl: windowSeconds * 2 // Expire key after 2 minutes
    });
    return false;
  } catch {
    // Fail-open: if KV errors, allow the request to proceed to the origin
    return false;
  }
}
