"use client";

import React, { useState, useEffect } from "react";

// ── Brand constants ──────────────────────────────────────────────────────────
const Y = "#F4C430"; // Memory Yellow
const B = "#000000"; // Pure Black
const W = "#FFFFFF"; // White

// ── Logo ─────────────────────────────────────────────────────────────────────
const LogoMark = ({ size = 24, color = B }: { size?: number; color?: string }) => (
  <svg width={size} height={size} viewBox="0 0 100 100" fill="none" aria-hidden="true">
    <circle cx="50" cy="50" r="38" stroke={color} strokeWidth="10" />
    <circle cx="50" cy="50" r="18" fill={color} />
    <circle cx="50" cy="18" r="8" fill={color} />
  </svg>
);

// ── Data ──────────────────────────────────────────────────────────────────────
const PHILOSOPHY = [
  {
    headline: "Not every moment needs an audience.",
    body: "The best experiences in your life don't need to be broadcast. They need to be held.",
  },
  {
    headline: "People matter more than followers.",
    body: "A hundred strangers seeing your video means less than one person who was actually there.",
  },
  {
    headline: "The best memories are shared, not performed.",
    body: "When you stop recording for an audience, you start recording the truth.",
  },
  {
    headline: "Some moments belong in your circle, not your feed.",
    body: "Authenticity lives in privacy.",
  },
];

const COMPARISON = [
  { social: "Followers",       memory: "Circle"        },
  { social: "Likes",           memory: "People"        },
  { social: "Algorithms",      memory: "Real Moments"  },
  { social: "Performance",     memory: "Private"       },
  { social: "Public",          memory: "Belonging"     },
  { social: "Endless Scroll",  memory: "Kept Close"    },
];

const MOMENTS = [
  "Friends laughing",
  "Family dinner",
  "Road trip",
  "Airport goodbye",
  "Camping",
  "Birthday",
  "Playing football",
  "Late-night conversations",
  "Sunset together",
];

const QUOTES = [
  "I forgot what it felt like to record something without thinking about likes.",
  "This reminds me why I started recording memories.",
  "The people make the memory.",
];

const FAQS = [
  {
    q: "What makes Memory different?",
    a: "Memory isn't about public followers or metrics. It's a private space where short videos are shared only with the specific people who experienced the moment.",
  },
  {
    q: "Who can see my memories?",
    a: "Only members of the circle you choose when capturing the memory. No global feed. No public discovery. No strangers.",
  },
  {
    q: "Can I create multiple circles?",
    a: "Yes. A circle for family, another for your closest friends, another for a specific trip. Each memory stays exactly where it belongs.",
  },
  {
    q: "Are memories public?",
    a: "Never. Memories are fully enclosed within their circles. They cannot be shared externally or exposed.",
  },
  {
    q: "Is Memory free?",
    a: "Yes. Memory's core features are completely free.",
  },
];

// ── Page Component ────────────────────────────────────────────────────────────
export default function Home() {
  const [isScrolled, setIsScrolled]   = useState(false);
  const [activeSection, setActive]    = useState("hero");
  const [faqOpen, setFaqOpen]         = useState<number | null>(null);
  const [mounted, setMounted]         = useState(false);

  useEffect(() => {
    setMounted(true);

    const onScroll = () => {
      setIsScrolled(window.scrollY > 64);

      const ids = ["hero", "philosophy", "how", "difference", "moments", "quotes", "faq", "cta"];
      const pos = window.scrollY + 200;
      for (const id of ids) {
        const el = document.getElementById(id);
        if (el && pos >= el.offsetTop && pos < el.offsetTop + el.offsetHeight) {
          setActive(id);
          break;
        }
      }
    };

    window.addEventListener("scroll", onScroll, { passive: true });

    // Scroll-reveal observer
    const obs = new IntersectionObserver(
      (entries) => entries.forEach((e) => e.isIntersecting && e.target.classList.add("_rv")),
      { threshold: 0.08, rootMargin: "0px 0px -48px 0px" }
    );
    document.querySelectorAll("._r").forEach((el) => obs.observe(el));

    return () => {
      window.removeEventListener("scroll", onScroll);
      obs.disconnect();
    };
  }, []);

  const toggleFaq = (i: number) => setFaqOpen(faqOpen === i ? null : i);

  if (!mounted) return null;

  return (
    <>
      {/* ─── Global Styles ──────────────────────────────────────────────────── */}
      <style>{`
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

        html {
          scroll-behavior: smooth;
          background: ${Y};
          color: ${B};
          font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
          -webkit-font-smoothing: antialiased;
          overflow-x: hidden;
        }

        body { background: ${Y}; overflow-x: hidden; }

        /* Scroll-reveal */
        ._r {
          opacity: 0;
          transform: translateY(28px);
          transition: opacity 0.9s cubic-bezier(0.16,1,0.3,1),
                      transform 0.9s cubic-bezier(0.16,1,0.3,1);
        }
        ._rv { opacity: 1; transform: translateY(0); }
        ._d1 { transition-delay: 80ms; }
        ._d2 { transition-delay: 160ms; }
        ._d3 { transition-delay: 240ms; }
        ._d4 { transition-delay: 320ms; }

        /* Buttons */
        .btn-black {
          display: inline-flex; align-items: center; justify-content: center;
          background: ${B}; color: ${W};
          border: 2px solid ${B};
          padding: 15px 36px;
          font-size: 15px; font-weight: 700; letter-spacing: -0.2px;
          text-decoration: none;
          transition: background 0.18s, color 0.18s;
          cursor: pointer; white-space: nowrap;
        }
        .btn-black:hover { background: ${W}; color: ${B}; }

        .btn-outline-white {
          display: inline-flex; align-items: center; justify-content: center;
          background: transparent; color: ${W};
          border: 2px solid rgba(255,255,255,0.45);
          padding: 15px 36px;
          font-size: 15px; font-weight: 700; letter-spacing: -0.2px;
          text-decoration: none;
          transition: border-color 0.18s, background 0.18s;
          cursor: pointer; white-space: nowrap;
        }
        .btn-outline-white:hover { border-color: ${W}; background: rgba(255,255,255,0.08); }

        .btn-outline-black {
          display: inline-flex; align-items: center; justify-content: center;
          background: transparent; color: ${B};
          border: 2px solid rgba(0,0,0,0.25);
          padding: 15px 36px;
          font-size: 15px; font-weight: 700; letter-spacing: -0.2px;
          text-decoration: none;
          transition: border-color 0.18s;
          cursor: pointer; white-space: nowrap;
        }
        .btn-outline-black:hover { border-color: ${B}; }

        /* Nav links */
        .nl {
          font-size: 14px; font-weight: 500;
          text-decoration: none; color: ${B};
          opacity: 0.45;
          transition: opacity 0.18s;
        }
        .nl:hover, .nl.active { opacity: 1; }

        /* FAQ accordion */
        .faq-btn {
          width: 100%; display: flex; justify-content: space-between;
          align-items: flex-start; gap: 24px;
          background: transparent; border: none;
          cursor: pointer; padding: 32px 0; text-align: left;
          color: ${B};
        }
        .faq-body {
          overflow: hidden; max-height: 0;
          transition: max-height 0.4s cubic-bezier(0.16,1,0.3,1),
                      padding 0.4s cubic-bezier(0.16,1,0.3,1);
        }
        .faq-body.open { max-height: 300px; padding-bottom: 28px; }

        /* Scrollbar */
        ::-webkit-scrollbar { width: 8px; }
        ::-webkit-scrollbar-track { background: ${Y}; }
        ::-webkit-scrollbar-thumb { background: rgba(0,0,0,0.2); border-radius: 99px; }
        ::-webkit-scrollbar-thumb:hover { background: rgba(0,0,0,0.4); }

        /* Responsive helpers */
        @media (max-width: 768px) {
          .hide-sm { display: none !important; }
          .moments-grid { grid-template-columns: repeat(2, 1fr) !important; }
          .comp-row { grid-template-columns: 1fr 1fr !important; }
          .flex-col-sm { flex-direction: column !important; }
        }
      `}</style>

      {/* ─── NAVBAR ─────────────────────────────────────────────────────────── */}
      <header
        id="nav"
        style={{
          position: "fixed", top: 0, left: 0, width: "100%", zIndex: 1000,
          height: "68px",
          display: "flex", alignItems: "center",
          padding: "0 24px",
          backgroundColor: isScrolled ? Y : "transparent",
          borderBottom: isScrolled ? `1px solid rgba(0,0,0,0.1)` : "1px solid transparent",
          transition: "background-color 0.35s, border-bottom 0.35s",
        }}
      >
        <div style={{ maxWidth: "1200px", width: "100%", margin: "0 auto", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          {/* Logo */}
          <a href="#hero" style={{ display: "flex", alignItems: "center", gap: "10px", textDecoration: "none", color: B }}>
            <LogoMark size={22} color={B} />
            <span style={{ fontWeight: 800, fontSize: "17px", letterSpacing: "-0.4px" }}>Memory</span>
          </a>

          {/* Nav links */}
          <nav className="hide-sm" style={{ display: "flex", gap: "36px" }}>
            {[
              { id: "philosophy", label: "Philosophy" },
              { id: "how",        label: "How It Works" },
              { id: "difference", label: "The Difference" },
              { id: "moments",    label: "Moments" },
              { id: "faq",        label: "FAQ" },
            ].map((l) => (
              <a key={l.id} href={`#${l.id}`} className={`nl ${activeSection === l.id ? "active" : ""}`}>
                {l.label}
              </a>
            ))}
          </nav>

          {/* CTA */}
          <a href="#cta" className="btn-black" style={{ padding: "10px 20px", fontSize: "13px" }}>
            Download
          </a>
        </div>
      </header>

      {/* ─── HERO ───────────────────────────────────────────────────────────── */}
      <section
        id="hero"
        style={{
          position: "relative", width: "100%", minHeight: "100svh",
          backgroundColor: B,
          display: "flex", alignItems: "flex-end",
          overflow: "hidden",
        }}
      >
        {/* Background video */}
        <video
          autoPlay muted loop playsInline
          aria-hidden="true"
          style={{
            position: "absolute", inset: 0,
            width: "100%", height: "100%", objectFit: "cover",
            opacity: 0.65,
          }}
        >
          <source src="/assets/hero.mp4" type="video/mp4" />
        </video>

        {/* Gradient overlay */}
        <div style={{
          position: "absolute", inset: 0,
          background: "linear-gradient(to top, rgba(0,0,0,0.9) 0%, rgba(0,0,0,0.3) 55%, rgba(0,0,0,0.05) 100%)",
        }} />

        {/* Content */}
        <div style={{
          position: "relative", zIndex: 2,
          maxWidth: "1200px", margin: "0 auto", width: "100%",
          padding: "clamp(100px,14vw,140px) 24px 72px",
        }}>
          {/* Eyebrow */}
          <div
            className="_r"
            style={{
              display: "inline-flex", alignItems: "center", gap: "8px",
              backgroundColor: Y, color: B,
              padding: "5px 14px",
              fontSize: "11px", fontWeight: 700, letterSpacing: "1.5px",
              textTransform: "uppercase",
              marginBottom: "28px",
            }}
          >
            <span style={{ width: "6px", height: "6px", borderRadius: "50%", backgroundColor: B, display: "inline-block" }} />
            Private · Authentic · For your circle
          </div>

          {/* Headline */}
          <h1
            className="_r _d1"
            style={{
              fontSize: "clamp(52px, 10vw, 96px)",
              fontWeight: 800,
              letterSpacing: "clamp(-2px, -0.04em, -4px)",
              lineHeight: 1.0,
              color: W,
              marginBottom: "32px",
              maxWidth: "800px",
            }}
          >
            For the people<br />who were there.
          </h1>

          {/* Sub-copy — emotional first */}
          <p
            className="_r _d2"
            style={{
              fontSize: "clamp(17px, 2.5vw, 22px)",
              color: "rgba(255,255,255,0.75)",
              maxWidth: "520px",
              lineHeight: 1.6,
              marginBottom: "4px",
              fontWeight: 400,
            }}
          >
            Some moments aren't meant for everyone.
          </p>
          <p
            className="_r _d2"
            style={{
              fontSize: "clamp(17px, 2.5vw, 22px)",
              color: "rgba(255,255,255,0.55)",
              maxWidth: "520px",
              lineHeight: 1.6,
              marginBottom: "20px",
              fontWeight: 400,
            }}
          >
            They're shared with the people who made them unforgettable.
          </p>
          <p
            className="_r _d3"
            style={{
              fontSize: "15px",
              color: "rgba(255,255,255,0.38)",
              maxWidth: "460px",
              lineHeight: 1.7,
              marginBottom: "52px",
              fontWeight: 400,
            }}
          >
            Memory is a private short-video app where life's best moments stay with the people who lived them.
          </p>

          {/* Buttons */}
          <div className="_r _d4 flex-col-sm" style={{ display: "flex", gap: "14px", flexWrap: "wrap" }}>
            <a href="#cta" className="btn-black" style={{ backgroundColor: W, color: B, borderColor: W }}>
              Download Memory
            </a>
            <a href="#how" className="btn-outline-white">
              Watch a Memory
            </a>
          </div>
        </div>

        {/* Scroll line */}
        <div
          style={{
            position: "absolute", bottom: "36px", right: "32px", zIndex: 2,
            display: "flex", flexDirection: "column", alignItems: "center", gap: "8px",
            opacity: 0.35,
          }}
        >
          <span style={{ fontSize: "10px", fontWeight: 700, letterSpacing: "2px", textTransform: "uppercase", color: W }}>Scroll</span>
          <div style={{ width: "1px", height: "48px", backgroundColor: W }} />
        </div>
      </section>

      {/* ─── PHILOSOPHY ─────────────────────────────────────────────────────── */}
      <section id="philosophy" style={{ backgroundColor: Y }}>
        {/* Section label row */}
        <div style={{ borderTop: `1px solid rgba(0,0,0,0.1)`, padding: "72px 24px 0" }}>
          <div style={{ maxWidth: "1200px", margin: "0 auto" }}>
            <p
              className="_r"
              style={{
                fontSize: "11px", fontWeight: 700, letterSpacing: "2px",
                textTransform: "uppercase", opacity: 0.35,
              }}
            >
              What we believe
            </p>
          </div>
        </div>

        {/* Philosophy statements — alternating bg */}
        {PHILOSOPHY.map((s, i) => (
          <div
            key={i}
            style={{
              borderTop: `1px solid ${i % 2 === 0 ? "rgba(0,0,0,0.1)" : "rgba(255,255,255,0.1)"}`,
              padding: "72px 24px",
              backgroundColor: i % 2 === 1 ? B : Y,
              color: i % 2 === 1 ? W : B,
            }}
          >
            <div style={{ maxWidth: "1200px", margin: "0 auto", display: "flex", gap: "32px", alignItems: "flex-start" }}>
              <span
                style={{
                  fontSize: "13px", fontWeight: 700, letterSpacing: "1px",
                  opacity: 0.25, paddingTop: "6px", minWidth: "36px",
                  flexShrink: 0,
                }}
              >
                0{i + 1}
              </span>
              <div>
                <h2
                  className={`_r _d${(i % 3) + 1}`}
                  style={{
                    fontSize: "clamp(28px, 5vw, 60px)",
                    fontWeight: 800,
                    letterSpacing: "clamp(-1px, -0.03em, -2.5px)",
                    lineHeight: 1.08,
                    marginBottom: "20px",
                    maxWidth: "900px",
                  }}
                >
                  {s.headline}
                </h2>
                <p
                  className={`_r _d${(i % 3) + 2}`}
                  style={{
                    fontSize: "clamp(16px, 2vw, 19px)",
                    opacity: 0.55,
                    maxWidth: "540px",
                    lineHeight: 1.75,
                    fontWeight: 400,
                  }}
                >
                  {s.body}
                </p>
              </div>
            </div>
          </div>
        ))}
      </section>

      {/* ─── HOW IT WORKS ───────────────────────────────────────────────────── */}
      <section
        id="how"
        style={{
          backgroundColor: Y,
          padding: "120px 24px",
          borderTop: `1px solid rgba(0,0,0,0.1)`,
        }}
      >
        <div style={{ maxWidth: "1200px", margin: "0 auto" }}>
          <p className="_r" style={{ fontSize: "11px", fontWeight: 700, letterSpacing: "2px", textTransform: "uppercase", opacity: 0.35, marginBottom: "16px" }}>
            Simple by design
          </p>
          <h2
            className="_r _d1"
            style={{
              fontSize: "clamp(36px, 6vw, 68px)",
              fontWeight: 800,
              letterSpacing: "clamp(-1.5px, -0.03em, -3px)",
              lineHeight: 1.05,
              marginBottom: "96px",
              maxWidth: "560px",
            }}
          >
            Three steps.<br />That's all.
          </h2>

          {/* Steps */}
          {[
            {
              n: "01",
              title: "Record",
              body: "Capture authentic short videos. Not edited posts — just real moments as they happen, from your phone.",
            },
            {
              n: "02",
              title: "Choose Your Circle",
              body: "Share only with the people who were part of the moment. No followers. No strangers. No algorithm.",
            },
            {
              n: "03",
              title: "Keep It Close",
              body: "Your memories stay with the people who lived them. Private. Permanent. Yours forever.",
            },
          ].map((step, i) => (
            <div
              key={i}
              className={`_r _d${i + 1}`}
              style={{
                borderTop: `1px solid rgba(0,0,0,0.1)`,
                padding: "60px 0",
                display: "flex",
                alignItems: "flex-start",
                gap: "clamp(24px, 4vw, 64px)",
              }}
            >
              <span
                style={{
                  fontSize: "clamp(40px, 8vw, 80px)",
                  fontWeight: 800,
                  letterSpacing: "-3px",
                  color: "rgba(0,0,0,0.1)",
                  lineHeight: 1,
                  flexShrink: 0,
                  minWidth: "clamp(80px, 12vw, 120px)",
                }}
              >
                {step.n}
              </span>
              <div>
                <h3
                  style={{
                    fontSize: "clamp(22px, 3.5vw, 40px)",
                    fontWeight: 800,
                    letterSpacing: "-0.8px",
                    marginBottom: "14px",
                  }}
                >
                  {step.title}
                </h3>
                <p style={{ fontSize: "clamp(15px, 1.8vw, 18px)", lineHeight: 1.75, opacity: 0.55, maxWidth: "480px" }}>
                  {step.body}
                </p>
              </div>
            </div>
          ))}
          <div style={{ borderTop: `1px solid rgba(0,0,0,0.1)` }} />
        </div>
      </section>

      {/* ─── THE DIFFERENCE ─────────────────────────────────────────────────── */}
      <section
        id="difference"
        style={{
          backgroundColor: B,
          color: W,
          padding: "120px 24px",
        }}
      >
        <div style={{ maxWidth: "1200px", margin: "0 auto" }}>
          <p className="_r" style={{ fontSize: "11px", fontWeight: 700, letterSpacing: "2px", textTransform: "uppercase", color: Y, opacity: 0.8, marginBottom: "16px" }}>
            A different philosophy
          </p>
          <h2
            className="_r _d1"
            style={{
              fontSize: "clamp(36px, 6vw, 68px)",
              fontWeight: 800,
              letterSpacing: "clamp(-1.5px, -0.03em, -3px)",
              lineHeight: 1.05,
              marginBottom: "80px",
              maxWidth: "640px",
            }}
          >
            Not another<br />social platform.
          </h2>

          {/* Column headers */}
          <div
            style={{
              display: "grid", gridTemplateColumns: "1fr 1fr",
              borderBottom: `1px solid rgba(255,255,255,0.1)`,
              paddingBottom: "16px",
            }}
          >
            <div style={{ paddingLeft: "20px" }}>
              <span style={{ fontSize: "11px", fontWeight: 700, letterSpacing: "2px", textTransform: "uppercase", opacity: 0.3 }}>
                Traditional Social
              </span>
            </div>
            <div style={{ paddingLeft: "20px" }}>
              <span style={{ fontSize: "11px", fontWeight: 700, letterSpacing: "2px", textTransform: "uppercase", color: Y }}>
                Memory
              </span>
            </div>
          </div>

          {COMPARISON.map((row, i) => (
            <div
              key={i}
              className={`_r _d${(i % 4) + 1} comp-row`}
              style={{
                display: "grid", gridTemplateColumns: "1fr 1fr",
                borderBottom: `1px solid rgba(255,255,255,0.07)`,
              }}
            >
              <div style={{ padding: "24px 20px", borderRight: `1px solid rgba(255,255,255,0.07)` }}>
                <span style={{ fontSize: "clamp(17px, 2.5vw, 22px)", fontWeight: 600, opacity: 0.3, letterSpacing: "-0.4px" }}>
                  {row.social}
                </span>
              </div>
              <div style={{ padding: "24px 20px" }}>
                <span style={{ fontSize: "clamp(17px, 2.5vw, 22px)", fontWeight: 700, color: Y, letterSpacing: "-0.4px" }}>
                  {row.memory}
                </span>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* ─── MOMENTS GRID ───────────────────────────────────────────────────── */}
      <section
        id="moments"
        style={{
          backgroundColor: Y,
          padding: "120px 24px",
          borderTop: `1px solid rgba(0,0,0,0.1)`,
        }}
      >
        <div style={{ maxWidth: "1200px", margin: "0 auto" }}>
          <p className="_r" style={{ fontSize: "11px", fontWeight: 700, letterSpacing: "2px", textTransform: "uppercase", opacity: 0.35, marginBottom: "16px" }}>
            Real moments
          </p>
          <h2
            className="_r _d1"
            style={{
              fontSize: "clamp(36px, 6vw, 68px)",
              fontWeight: 800,
              letterSpacing: "clamp(-1.5px, -0.03em, -3px)",
              lineHeight: 1.05,
              marginBottom: "64px",
              maxWidth: "560px",
            }}
          >
            This is what<br />Memory looks like.
          </h2>

          <div
            className="moments-grid"
            style={{
              display: "grid",
              gridTemplateColumns: "repeat(3, 1fr)",
              gap: "12px",
            }}
          >
            {MOMENTS.map((label, i) => (
              <div
                key={i}
                className={`_r _d${(i % 3) + 1}`}
                style={{
                  aspectRatio: "9/16",
                  backgroundColor: B,
                  position: "relative",
                  overflow: "hidden",
                }}
              >
                {/* Autoplay muted video — drop files into /public/assets/moments/ */}
                <video
                  autoPlay muted loop playsInline
                  aria-label={label}
                  style={{
                    position: "absolute", inset: 0,
                    width: "100%", height: "100%", objectFit: "cover",
                  }}
                >
                  <source src={`/assets/moments/moment-${i + 1}.mp4`} type="video/mp4" />
                </video>

                {/* Label overlay */}
                <div
                  style={{
                    position: "absolute", inset: 0,
                    background: "linear-gradient(to top, rgba(0,0,0,0.65) 0%, transparent 55%)",
                    display: "flex", alignItems: "flex-end",
                    padding: "16px",
                  }}
                >
                  <span style={{ fontSize: "12px", fontWeight: 600, color: "rgba(255,255,255,0.75)", letterSpacing: "0.3px" }}>
                    {label}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ─── QUOTES ─────────────────────────────────────────────────────────── */}
      <section
        id="quotes"
        style={{
          backgroundColor: B,
          color: W,
          padding: "120px 24px",
        }}
      >
        <div style={{ maxWidth: "880px", margin: "0 auto" }}>
          {QUOTES.map((q, i) => (
            <div
              key={i}
              className={`_r _d${i + 1}`}
              style={{
                borderTop: `1px solid rgba(255,255,255,0.09)`,
                padding: "72px 0",
              }}
            >
              <p
                style={{
                  fontSize: "clamp(22px, 4vw, 38px)",
                  fontWeight: 400,
                  lineHeight: 1.45,
                  letterSpacing: "-0.5px",
                  fontStyle: "italic",
                  opacity: 0.88,
                }}
              >
                &ldquo;{q}&rdquo;
              </p>
            </div>
          ))}
          <div style={{ borderTop: `1px solid rgba(255,255,255,0.09)` }} />
        </div>
      </section>

      {/* ─── FAQ ────────────────────────────────────────────────────────────── */}
      <section
        id="faq"
        style={{
          backgroundColor: Y,
          padding: "120px 24px",
          borderTop: `1px solid rgba(0,0,0,0.1)`,
        }}
      >
        <div style={{ maxWidth: "800px", margin: "0 auto" }}>
          <p className="_r" style={{ fontSize: "11px", fontWeight: 700, letterSpacing: "2px", textTransform: "uppercase", opacity: 0.35, marginBottom: "16px" }}>
            Questions
          </p>
          <h2
            className="_r _d1"
            style={{
              fontSize: "clamp(36px, 6vw, 60px)",
              fontWeight: 800,
              letterSpacing: "clamp(-1.5px, -0.03em, -2.5px)",
              lineHeight: 1.05,
              marginBottom: "80px",
            }}
          >
            Everything you<br />need to know.
          </h2>

          {FAQS.map((item, i) => (
            <div key={i} style={{ borderTop: `1px solid rgba(0,0,0,0.1)` }}>
              <button
                className={`faq-btn _r _d${(i % 3) + 1}`}
                onClick={() => toggleFaq(i)}
                aria-expanded={faqOpen === i}
              >
                <span
                  style={{
                    fontSize: "clamp(17px, 2.5vw, 22px)",
                    fontWeight: 700,
                    letterSpacing: "-0.4px",
                    lineHeight: 1.3,
                    flex: 1,
                  }}
                >
                  {item.q}
                </span>
                <span
                  style={{
                    fontSize: "28px",
                    fontWeight: 300,
                    opacity: 0.35,
                    flexShrink: 0,
                    lineHeight: 1,
                    marginTop: "2px",
                    transition: "transform 0.3s",
                    transform: faqOpen === i ? "rotate(45deg)" : "rotate(0deg)",
                    display: "inline-block",
                  }}
                >
                  +
                </span>
              </button>
              <div className={`faq-body ${faqOpen === i ? "open" : ""}`}>
                <p style={{ fontSize: "clamp(15px, 1.8vw, 17px)", lineHeight: 1.8, opacity: 0.6, maxWidth: "600px" }}>
                  {item.a}
                </p>
              </div>
            </div>
          ))}
          <div style={{ borderTop: `1px solid rgba(0,0,0,0.1)` }} />
        </div>
      </section>

      {/* ─── FINAL CTA ──────────────────────────────────────────────────────── */}
      <section
        id="cta"
        style={{
          position: "relative",
          backgroundColor: B,
          color: W,
          padding: "160px 24px",
          overflow: "hidden",
          textAlign: "center",
        }}
      >
        {/* Background video */}
        <video
          autoPlay muted loop playsInline
          aria-hidden="true"
          style={{
            position: "absolute", inset: 0,
            width: "100%", height: "100%", objectFit: "cover",
            opacity: 0.2,
          }}
        >
          <source src="/assets/cta.mp4" type="video/mp4" />
        </video>

        <div style={{ position: "relative", zIndex: 2, maxWidth: "720px", margin: "0 auto" }}>
          {/* Badge */}
          <div
            className="_r"
            style={{
              display: "inline-flex", alignItems: "center", gap: "8px",
              border: `1px solid rgba(255,255,255,0.18)`,
              padding: "5px 14px",
              fontSize: "11px", fontWeight: 700, letterSpacing: "1.5px",
              textTransform: "uppercase",
              color: "rgba(255,255,255,0.4)",
              marginBottom: "40px",
            }}
          >
            Coming soon on iOS & Android
          </div>

          <h2
            className="_r _d1"
            style={{
              fontSize: "clamp(52px, 10vw, 96px)",
              fontWeight: 800,
              letterSpacing: "clamp(-2px, -0.04em, -4px)",
              lineHeight: 1.0,
              marginBottom: "28px",
            }}
          >
            Keep it<br />between us.
          </h2>

          <p
            className="_r _d2"
            style={{
              fontSize: "clamp(16px, 2vw, 20px)",
              color: "rgba(255,255,255,0.55)",
              maxWidth: "440px",
              lineHeight: 1.65,
              margin: "0 auto 52px",
            }}
          >
            Start sharing memories with the people who matter most.
          </p>

          <div className="_r _d3 flex-col-sm" style={{ display: "flex", gap: "14px", justifyContent: "center", flexWrap: "wrap" }}>
            <a href="#" className="btn-black" style={{ backgroundColor: W, color: B, borderColor: W }}>
              Download Memory
            </a>
          </div>
        </div>
      </section>

      {/* ─── FOOTER ─────────────────────────────────────────────────────────── */}
      <footer
        style={{
          backgroundColor: Y,
          padding: "56px 24px",
          borderTop: `1px solid rgba(0,0,0,0.1)`,
        }}
      >
        <div style={{ maxWidth: "1200px", margin: "0 auto" }}>
          {/* Top row */}
          <div
            style={{
              display: "flex", justifyContent: "space-between", alignItems: "center",
              flexWrap: "wrap", gap: "24px", marginBottom: "48px",
            }}
          >
            {/* Brand */}
            <a href="#hero" style={{ display: "flex", alignItems: "center", gap: "10px", textDecoration: "none", color: B }}>
              <LogoMark size={20} color={B} />
              <span style={{ fontWeight: 800, fontSize: "15px", letterSpacing: "-0.4px" }}>Memory</span>
            </a>

            {/* Links */}
            <div style={{ display: "flex", gap: "28px", flexWrap: "wrap" }}>
              {["Privacy", "Terms", "Instagram", "TikTok"].map((l) => (
                <a
                  key={l}
                  href="#"
                  style={{
                    textDecoration: "none", color: B, fontSize: "14px", fontWeight: 500,
                    opacity: 0.5, transition: "opacity 0.18s",
                  }}
                  onMouseEnter={(e) => (e.currentTarget.style.opacity = "1")}
                  onMouseLeave={(e) => (e.currentTarget.style.opacity = "0.5")}
                >
                  {l}
                </a>
              ))}
            </div>
          </div>

          {/* Bottom row */}
          <div
            style={{
              borderTop: `1px solid rgba(0,0,0,0.1)`, paddingTop: "28px",
              display: "flex", justifyContent: "space-between",
              flexWrap: "wrap", gap: "12px",
            }}
          >
            <span style={{ fontSize: "13px", opacity: 0.35 }}>
              © {new Date().getFullYear()} Memory App. All rights reserved.
            </span>
            <span style={{ fontSize: "13px", opacity: 0.35 }}>
              Life is better remembered together.
            </span>
          </div>
        </div>
      </footer>
    </>
  );
}
