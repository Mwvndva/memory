import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import * as crypto from 'crypto';

const ALGORITHM = 'aes-256-cbc';
const ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'default-secret-key-32-chars-long-x';
const KEY = crypto.scryptSync(ENCRYPTION_KEY, 'salt', 32);
const IV = crypto.scryptSync(ENCRYPTION_KEY, 'iv-salt', 16);

function encrypt(text: string): string {
  if (!text) return text;
  const cipher = crypto.createCipheriv(ALGORITHM, KEY, IV);
  let encrypted = cipher.update(text, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  return encrypted;
}

function decrypt(ciphertext: string): string {
  if (!ciphertext) return ciphertext;
  try {
    const decipher = crypto.createDecipheriv(ALGORITHM, KEY, IV);
    let decrypted = decipher.update(ciphertext, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
  } catch (err) {
    return ciphertext; // Fallback if not encrypted (e.g. migration phase)
  }
}

// Recursively traverse returned objects to decrypt User PII transparently
function decryptUserPII(obj: any): any {
  if (!obj || typeof obj !== 'object') return obj;
  if (Array.isArray(obj)) {
    return obj.map(decryptUserPII);
  }
  
  const decryptedObj = { ...obj };
  
  // If this object is a User model, decrypt its PII
  if (decryptedObj.id && (decryptedObj.email !== undefined || decryptedObj.phone !== undefined)) {
    if (decryptedObj.email) decryptedObj.email = decrypt(decryptedObj.email);
    if (decryptedObj.phone) decryptedObj.phone = decrypt(decryptedObj.phone);
    if (decryptedObj.phoneNormalized) decryptedObj.phoneNormalized = decrypt(decryptedObj.phoneNormalized);
  }
  
  // Recurse into nested fields (e.g., relations)
  for (const key of Object.keys(decryptedObj)) {
    if (typeof decryptedObj[key] === 'object') {
      decryptedObj[key] = decryptUserPII(decryptedObj[key]);
    }
  }
  
  return decryptedObj;
}

// Encrypt query arguments transparently
function encryptUserPIIQueryArgs(model: string, args: any) {
  if (!args) return args;
  
  // 1. Encrypt filters in where clause
  if (args.where && model === 'User') {
    if (typeof args.where.email === 'string') {
      args.where.email = encrypt(args.where.email);
    } else if (args.where.email && Array.isArray(args.where.email.in)) {
      args.where.email.in = args.where.email.in.map(encrypt);
    }
    
    if (typeof args.where.phone === 'string') {
      args.where.phone = encrypt(args.where.phone);
    }
    
    if (typeof args.where.phoneNormalized === 'string') {
      args.where.phoneNormalized = encrypt(args.where.phoneNormalized);
    } else if (args.where.phoneNormalized && Array.isArray(args.where.phoneNormalized.in)) {
      args.where.phoneNormalized.in = args.where.phoneNormalized.in.map(encrypt);
    }
  }
  
  // 2. Encrypt input data in create/update
  if (model === 'User' && args.data) {
    if (typeof args.data.email === 'string') {
      args.data.email = encrypt(args.data.email);
    }
    if (typeof args.data.phone === 'string') {
      args.data.phone = encrypt(args.data.phone);
    }
    if (typeof args.data.phoneNormalized === 'string') {
      args.data.phoneNormalized = encrypt(args.data.phoneNormalized);
    }
  }
  
  // 3. Encrypt input data in upsert
  if (model === 'User' && (args.create || args.update)) {
    if (args.create) {
      if (typeof args.create.email === 'string') args.create.email = encrypt(args.create.email);
      if (typeof args.create.phone === 'string') args.create.phone = encrypt(args.create.phone);
      if (typeof args.create.phoneNormalized === 'string') args.create.phoneNormalized = encrypt(args.create.phoneNormalized);
    }
    if (args.update) {
      if (typeof args.update.email === 'string') args.update.email = encrypt(args.update.email);
      if (typeof args.update.phone === 'string') args.update.phone = encrypt(args.update.phone);
      if (typeof args.update.phoneNormalized === 'string') args.update.phoneNormalized = encrypt(args.update.phoneNormalized);
    }
  }

  return args;
}

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private extendedClient: any;

  constructor() {
    const pool = new Pool({
      connectionString: process.env.DATABASE_URL,
    });
    const adapter = new PrismaPg(pool);
    super({ adapter });

    const client = this.$extends({
      query: {
        $allModels: {
          async $allOperations({ model, operation, args, query }) {
            encryptUserPIIQueryArgs(model, args);
            const result = await (proxy as any).softDeleteQueryMiddleware(model, operation, args, query, client);
            return decryptUserPII(result);
          }
        }
      }
    });

    this.extendedClient = client;

    const proxy = new Proxy(this, {
      get: (target, prop, receiver) => {
        if (prop in target.extendedClient) {
          const value = target.extendedClient[prop];
          if (typeof value === 'function') {
            return value.bind(target.extendedClient);
          }
          return value;
        }
        return Reflect.get(target, prop, receiver);
      }
    });
    return proxy;
  }


  async softDeleteQueryMiddleware(model: string, operation: string, args: any, query: (args: any) => Promise<any>, client: any) {
    const softDeleteModels = ['User', 'Memory', 'Message', 'CircleMembership'];
    if (!softDeleteModels.includes(model)) {
      return query(args);
    }

    const modelKey = model.charAt(0).toLowerCase() + model.slice(1);

    if (operation === 'findUnique') {
      return (client as any)[modelKey].findFirst(args);
    }
    if (operation === 'findUniqueOrThrow') {
      return (client as any)[modelKey].findFirstOrThrow(args);
    }

    if (operation === 'findFirst' || operation === 'findFirstOrThrow' || operation === 'findMany' || operation === 'count') {
      args.where = args.where || {};
      if ((args.where as any).deletedAt === undefined) {
        (args.where as any).deletedAt = null;
      }
    }

    if (operation === 'delete') {
      (args as any).data = { deletedAt: new Date() };
      return (client as any)[modelKey].update(args);
    }

    if (operation === 'deleteMany') {
      (args as any).data = (args as any).data || {};
      (args as any).data.deletedAt = new Date();
      return (client as any)[modelKey].updateMany(args);
    }

    return query(args);
  }

  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
