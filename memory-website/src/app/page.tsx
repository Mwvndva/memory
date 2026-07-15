"use client";

import React, { useState, useEffect } from "react";

// ─── Ghost Logo SVG ──────────────────────────────────────────────────────────
function Ghost({ size = 32, fill = "#000", eyeFill = "#fff" }: { size?: number; fill?: string; eyeFill?: string }) {
  return (
    <svg
      width={size}
      height={Math.round(size * 1.08)}
      viewBox="0 0 80 90"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
    >
      <path
        d="M40 4C20 4 8 18 8 36V84L16.5 76L25 84L33.5 76L40 82L46.5 76L55 84L63.5 76L72 84V36C72 18 60 4 40 4Z"
        fill={fill}
      />
      <ellipse cx="30" cy="37" rx="7" ry="8.5" fill={eyeFill} />
      <ellipse cx="50" cy="37" rx="7" ry="8.5" fill={eyeFill} />
      <path d="M34 53Q40 60 46 53" stroke={eyeFill} strokeWidth="3.5" strokeLinecap="round" fill="none" />
    </svg>
  );
}

// ─── How It Works icons ───────────────────────────────────────────────────────
function IconRecord() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#000" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M15 10l4.553-2.069A1 1 0 0121 8.845v6.31a1 1 0 01-1.447.894L15 14" />
      <rect x="3" y="6" width="12" height="12" rx="2" />
    </svg>
  );
}
function IconCircle() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#000" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="8" r="3" />
      <path d="M6.168 18.849A4 4 0 0110 16h4a4 4 0 013.834 2.855" />
      <circle cx="18" cy="8" r="2.5" />
      <circle cx="6" cy="8" r="2.5" />
    </svg>
  );
}
function IconShare() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#000" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 12v8a2 2 0 002 2h12a2 2 0 002-2v-8" />
      <polyline points="16 6 12 2 8 6" />
      <line x1="12" y1="2" x2="12" y2="15" />
    </svg>
  );
}

// ─── Data ─────────────────────────────────────────────────────────────────────
const STEPS = [
  {
    num: "01",
    icon: <IconRecord />,
    title: "Record",
    body: "Capture authentic short videos as life happens. No pressure. No performance. Just real moments.",
  },
  {
    num: "02",
    icon: <IconCircle />,
    title: "Choose Your Circle",
    body: "Select the friends or family who were part of that experience. Your memories stay within your Circle — no one else.",
  },
  {
    num: "03",
    icon: <IconShare />,
    title: "Share",
    body: "Your Circle receives the memory privately. No public audience. No strangers. No chasing likes.",
  },
];

const WHY = [
  {
    title: "Real moments.\nNot performances.",
    body: "Record life as it actually happens — not a highlight reel designed for strangers.",
  },
  {
    title: "Your Circle.\nNot your followers.",
    body: "The people who matter to you, not a number on a profile. Quality over quantity.",
  },
  {
    title: "Private by design.\nNot public by default.",
    body: "Every memory starts private. Nothing is ever made public unless you decide.",
  },
  {
    title: "Share experiences.\nNot attention.",
    body: "Memory isn't built around likes, views, or reach. It's built around connection.",
  },
];

const FAQS = [
  {
    q: "Is Memory free?",
    a: "Yes. Memory is completely free to download and use. No hidden fees, no paid tiers to share memories with your Circle.",
  },
  {
    q: "Can anyone see my memories?",
    a: "Only the people you choose. When you share a memory, you select exactly who receives it. Nobody else can view it — not the public, not strangers.",
  },
  {
    q: "Can I share photos?",
    a: "No. Memory is built specifically around short videos. We believe video captures the real emotion of a moment in a way photos can't.",
  },
  {
    q: "Why Circles?",
    a: "Because not every memory belongs on a public feed. A Circle lets you share exactly with the right people — family for a birthday, friends for a road trip, teammates for a win.",
  },
  {
    q: "When is Memory available?",
    a: "Memory is currently available for Android. iOS is coming soon.",
  },
];

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function Page() {
  const [faqOpen, setFaqOpen] = useState<number | null>(null);
  const [scrolled, setScrolled] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);

  // Close menu on resize to desktop
  useEffect(() => {
    const onResize = () => { if (window.innerWidth > 768) setMenuOpen(false); };
    window.addEventListener("resize", onResize);
    return () => window.removeEventListener("resize", onResize);
  }, []);

  useEffect(() => {
    // Navbar scroll
    const onScroll = () => setScrolled(window.scrollY > 32);
    window.addEventListener("scroll", onScroll, { passive: true });

    // Scroll reveal — progressive enhancement.
    // Elements are visible by default; we only hide + animate those below the fold.
    const vh = window.innerHeight;
    const allReveal = Array.from(document.querySelectorAll("._r"));

    allReveal.forEach((el) => {
      const rect = (el as HTMLElement).getBoundingClientRect();
      if (rect.top > vh + 40) {
        el.classList.add("_hide"); // hide only if truly off-screen
      } else {
        el.classList.add("_v");   // immediately visible if in/near viewport
      }
    });

    const io = new IntersectionObserver(
      (entries) =>
        entries.forEach((e) => {
          if (e.isIntersecting) {
            e.target.classList.remove("_hide");
            e.target.classList.add("_v");
            io.unobserve(e.target);
          }
        }),
      { threshold: 0.05, rootMargin: "0px 0px -20px 0px" }
    );
    allReveal.forEach((el) => io.observe(el));

    // Safety fallback: force-reveal everything after 2 seconds
    // in case the observer doesn't fire (e.g. old mobile browsers)
    const fallback = setTimeout(() => {
      document.querySelectorAll("._r").forEach((el) => {
        el.classList.remove("_hide");
        el.classList.add("_v");
      });
    }, 2000);

    return () => {
      window.removeEventListener("scroll", onScroll);
      io.disconnect();
      clearTimeout(fallback);
    };
  }, []);

  const toggleFaq = (i: number) => setFaqOpen(faqOpen === i ? null : i);

  return (
    <>
      {/* ─── Styles ──────────────────────────────────────────────────────── */}
      <style>{`
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

        html { scroll-behavior: smooth; font-size: 16px; }

        body {
          font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
          background: #F4C430;
          color: #000;
          -webkit-font-smoothing: antialiased;
          overflow-x: hidden;
        }

        img { max-width: 100%; display: block; }
        a { text-decoration: none; }

        /* Reveal — elements visible by default, JS enhances */
        ._r {
          transition: opacity 0.6s ease, transform 0.6s ease;
        }
        /* Added by JS only for elements below the fold */
        ._hide {
          opacity: 0;
          transform: translateY(20px);
        }
        ._v { opacity: 1 !important; transform: translateY(0) !important; }
        ._d1 { transition-delay: 0.10s; }
        ._d2 { transition-delay: 0.18s; }
        ._d3 { transition-delay: 0.26s; }
        ._d4 { transition-delay: 0.34s; }

        /* Buttons */
        .btn-black {
          display: inline-flex; align-items: center; justify-content: center; gap: 8px;
          background: #000; color: #fff; border: 2px solid #000;
          padding: 14px 26px; font-size: 15px; font-weight: 700;
          border-radius: 8px; cursor: pointer; white-space: nowrap;
          transition: background 0.15s;
        }
        .btn-black:hover { background: #1a1a1a; }

        .btn-white {
          display: inline-flex; align-items: center; justify-content: center; gap: 8px;
          background: #fff; color: #000; border: 2px solid #000;
          padding: 14px 26px; font-size: 15px; font-weight: 700;
          border-radius: 8px; cursor: pointer; white-space: nowrap;
          transition: background 0.15s;
        }
        .btn-white:hover { background: #f5f5f5; }

        .btn-white-cta {
          display: inline-flex; align-items: center; justify-content: center;
          background: #fff; color: #000; border: 2px solid #fff;
          padding: 16px 36px; font-size: 16px; font-weight: 700;
          border-radius: 8px; cursor: pointer; white-space: nowrap;
          transition: background 0.15s;
        }
        .btn-white-cta:hover { background: #f0f0f0; }

        /* Nav */
        .mem-nav {
          position: sticky; top: 0; z-index: 100;
          background: #F4C430;
          height: 64px; padding: 0 24px;
          display: flex; align-items: center;
          transition: border-bottom 0.2s, box-shadow 0.2s;
        }
        .mem-nav.scrolled {
          border-bottom: 1.5px solid rgba(0,0,0,0.1);
          box-shadow: 0 2px 12px rgba(0,0,0,0.06);
        }
        .nav-in {
          max-width: 1160px; width: 100%; margin: 0 auto;
          display: flex; align-items: center; justify-content: space-between;
        }
        .nav-brand {
          display: flex; align-items: center; gap: 10px;
          color: #000; font-size: 18px; font-weight: 800; letter-spacing: -0.4px;
        }
        .nav-links { display: flex; gap: 28px; list-style: none; }
        .nav-links a {
          font-size: 14px; font-weight: 500;
          color: rgba(0,0,0,0.5); transition: color 0.15s;
        }
        .nav-links a:hover { color: #000; }

        /* Layout */
        .wrap { max-width: 1160px; margin: 0 auto; }
        .sec { padding: 100px 24px; }

        /* Hero */
        #hero { background: #F4C430; padding: 80px 24px 0; min-height: calc(100vh - 64px); display: flex; align-items: center; }
        .hero-grid {
          display: grid; grid-template-columns: 1fr 1fr;
          gap: 64px; align-items: center;
          padding-bottom: 80px;
        }
        .hero-text { display: flex; flex-direction: column; gap: 22px; }

        /* What is Memory */
        #what { background: #fff; }
        .what-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 80px; align-items: center; }
        .quote-block {
          border-left: 4px solid #F4C430; padding: 18px 22px;
          margin-bottom: 8px;
        }
        .quote-block.alt { border-left-color: #000; }
        .quote-lbl { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 1.5px; opacity: 0.4; margin-bottom: 6px; }
        .quote-txt { font-size: clamp(19px, 2.3vw, 25px); font-weight: 800; letter-spacing: -0.4px; line-height: 1.3; color: #000; }

        /* How it works */
        #how { background: #F4C430; }
        .how-cards { display: grid; grid-template-columns: repeat(3,1fr); gap: 18px; }
        .how-card {
          background: #fff; border-radius: 14px; padding: 36px 28px;
          display: flex; flex-direction: column; gap: 18px;
        }
        .how-icon {
          width: 50px; height: 50px; background: #F4C430;
          border-radius: 11px; display: flex; align-items: center; justify-content: center;
        }
        .step-lbl { font-size: 11px; font-weight: 800; letter-spacing: 2px; text-transform: uppercase; color: rgba(0,0,0,0.3); margin-bottom: 2px; }

        /* Why Memory */
        #why { background: #000; }
        .why-cards { display: grid; grid-template-columns: 1fr 1fr; gap: 18px; }
        .why-card { background: #F4C430; border-radius: 14px; padding: 36px 32px; display: flex; flex-direction: column; gap: 10px; }
        .why-title { font-size: clamp(19px, 2.2vw, 24px); font-weight: 800; letter-spacing: -0.4px; color: #000; white-space: pre-line; line-height: 1.2; }
        .why-body { font-size: 15px; line-height: 1.65; color: rgba(0,0,0,0.58); }

        /* FAQ */
        #faq { background: #F4C430; }
        .faq-list { max-width: 700px; }
        .faq-item { border-top: 1.5px solid rgba(0,0,0,0.13); }
        .faq-item:last-child { border-bottom: 1.5px solid rgba(0,0,0,0.13); }
        .faq-btn {
          width: 100%; display: flex; justify-content: space-between; align-items: center; gap: 24px;
          background: transparent; border: none; cursor: pointer; padding: 24px 0; text-align: left;
        }
        .faq-q { font-size: clamp(15px, 1.8vw, 18px); font-weight: 700; letter-spacing: -0.2px; line-height: 1.4; color: #000; }
        .faq-plus {
          font-size: 26px; font-weight: 300; opacity: 0.35; flex-shrink: 0;
          line-height: 1; transition: transform 0.28s ease;
          display: inline-block; color: #000;
        }
        .faq-plus.open { transform: rotate(45deg); opacity: 0.6; }
        .faq-body { overflow: hidden; max-height: 0; transition: max-height 0.35s ease, padding-bottom 0.35s ease; }
        .faq-body.open { max-height: 250px; padding-bottom: 22px; }
        .faq-body p { font-size: 15px; line-height: 1.75; color: rgba(0,0,0,0.58); max-width: 560px; }

        /* CTA */
        #cta { background: #000; padding: 120px 24px; text-align: center; }
        .cta-in { max-width: 620px; margin: 0 auto; display: flex; flex-direction: column; align-items: center; gap: 22px; }

        /* Footer */
        footer { background: #F4C430; border-top: 1.5px solid rgba(0,0,0,0.1); padding: 44px 24px; }
        .foot-in { max-width: 1160px; margin: 0 auto; }
        .foot-top { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 20px; margin-bottom: 32px; }
        .foot-brand { display: flex; align-items: center; gap: 10px; color: #000; font-size: 16px; font-weight: 800; }
        .foot-links { display: flex; gap: 24px; flex-wrap: wrap; }
        .foot-links a { font-size: 14px; font-weight: 500; color: rgba(0,0,0,0.45); transition: color 0.15s; }
        .foot-links a:hover { color: #000; }
        .foot-bottom { border-top: 1px solid rgba(0,0,0,0.1); padding-top: 22px; font-size: 13px; color: rgba(0,0,0,0.38); }

        /* Typography helpers */
        .label { font-size: 11px; font-weight: 700; letter-spacing: 2px; text-transform: uppercase; opacity: 0.4; margin-bottom: 12px; }
        .h1 { font-size: clamp(38px, 7vw, 70px); font-weight: 900; letter-spacing: -2.5px; line-height: 1.0; }
        .h2 { font-size: clamp(30px, 5.5vw, 54px); font-weight: 800; letter-spacing: -1.8px; line-height: 1.08; }
        .h3 { font-size: clamp(19px, 2.5vw, 26px); font-weight: 800; letter-spacing: -0.5px; line-height: 1.2; }
        .body { font-size: 16px; line-height: 1.7; color: rgba(0,0,0,0.58); }
        .body-lg { font-size: clamp(15px, 1.8vw, 18px); line-height: 1.75; color: rgba(0,0,0,0.58); }

        /* Scrollbar */
        ::-webkit-scrollbar { width: 6px; }
        ::-webkit-scrollbar-track { background: #F4C430; }
        ::-webkit-scrollbar-thumb { background: rgba(0,0,0,0.2); border-radius: 99px; }

        /* ─── Mobile menu overlay ───────────────────────────────────────── */
        .mobile-menu-btn {
          display: none;
          background: transparent;
          border: none;
          cursor: pointer;
          padding: 6px;
          flex-direction: column;
          gap: 5px;
          align-items: center;
          justify-content: center;
          flex-shrink: 0;
        }
        .mobile-menu-btn span {
          display: block;
          width: 22px;
          height: 2.5px;
          background: #000;
          border-radius: 99px;
          transition: transform 0.25s ease, opacity 0.2s ease;
        }
        .mobile-menu-btn.open span:nth-child(1) { transform: translateY(7.5px) rotate(45deg); }
        .mobile-menu-btn.open span:nth-child(2) { opacity: 0; transform: scaleX(0); }
        .mobile-menu-btn.open span:nth-child(3) { transform: translateY(-7.5px) rotate(-45deg); }

        .mobile-nav {
          display: none;
          position: fixed;
          top: 64px; left: 0; right: 0; bottom: 0;
          background: #F4C430;
          z-index: 99;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          gap: 0;
          overflow-y: auto;
        }
        .mobile-nav.open { display: flex; }
        .mobile-nav a {
          font-size: clamp(28px, 8vw, 40px);
          font-weight: 800;
          color: #000;
          letter-spacing: -1px;
          text-decoration: none;
          padding: 18px 24px;
          width: 100%;
          text-align: center;
          border-bottom: 1px solid rgba(0,0,0,0.08);
          transition: background 0.15s;
        }
        .mobile-nav a:first-child { border-top: 1px solid rgba(0,0,0,0.08); }
        .mobile-nav a:hover { background: rgba(0,0,0,0.04); }

        /* ─── Responsive — 4 breakpoints ──────────────────────────────────── */

        /* Tablet landscape: ≤1100px */
        @media (max-width: 1100px) {
          .hero-grid { gap: 40px; }
          .how-cards { grid-template-columns: repeat(2, 1fr); }
          .how-cards > *:last-child { grid-column: 1 / -1; max-width: 480px; margin: 0 auto; width: 100%; }
        }

        /* Tablet portrait: ≤768px */
        @media (max-width: 768px) {
          /* Nav */
          .nav-links { display: none; }
          .mobile-menu-btn { display: flex; }

          /* Hero */
          #hero {
            padding: 40px 20px 0;
            min-height: auto;
            align-items: flex-start;
          }
          .hero-grid {
            grid-template-columns: 1fr;
            text-align: center;
            gap: 36px;
            padding-bottom: 56px;
            padding-top: 0;
          }
          /* Mockup appears first on mobile for visual impact */
          .hero-mockup-col { order: -1; }
          .hero-text { align-items: center; }
          .hero-btns { justify-content: center; }
          .mockup-img { max-height: 480px !important; width: auto !important; max-width: 85% !important; margin: 0 auto; }

          /* Sections */
          .sec { padding: 72px 20px; }
          .what-grid { grid-template-columns: 1fr; gap: 40px; }
          .how-cards { grid-template-columns: 1fr; }
          .how-cards > *:last-child { grid-column: auto; max-width: 100%; }
          .why-cards { grid-template-columns: 1fr; }

          /* FAQ */
          .faq-list { max-width: 100%; }

          /* CTA */
          #cta { padding: 88px 20px; }

          /* Footer */
          .foot-top { flex-direction: column; align-items: flex-start; gap: 20px; }
          .foot-bottom { flex-direction: column !important; align-items: flex-start; gap: 6px; }
        }

        /* Phone landscape / small: ≤540px */
        @media (max-width: 540px) {
          .sec { padding: 60px 16px; }
          #hero { padding: 28px 16px 0; }
          #cta { padding: 72px 16px; }

          .hero-grid { gap: 28px; padding-bottom: 48px; }
          .mockup-img { max-height: 380px !important; max-width: 90% !important; }

          .how-card { padding: 28px 22px; }
          .why-card { padding: 28px 22px; }

          .btn-black, .btn-white, .btn-white-cta { width: 100%; justify-content: center; }
          .hero-btns { flex-direction: column; width: 100%; align-items: center; }

          .foot-links { gap: 14px; flex-wrap: wrap; }
          .what-grid { gap: 32px; }
        }

        /* Small phone: ≤380px */
        @media (max-width: 380px) {
          .sec { padding: 48px 14px; }
          #hero { padding: 20px 14px 0; }
          #cta { padding: 60px 14px; }
          .hero-grid { gap: 24px; padding-bottom: 40px; }
          .mockup-img { max-height: 320px !important; }
          .how-card, .why-card { padding: 24px 18px; }
          .foot-links { gap: 12px; }
        }
      `}</style>

      {/* ─── NAV ────────────────────────────────────────────────────────── */}
      <nav className={`mem-nav ${scrolled ? "scrolled" : ""}`}>
        <div className="nav-in">
          <a href="#hero" className="nav-brand" onClick={() => setMenuOpen(false)}>
            <img src="/logo.png" alt="Memory" width={28} height={28} style={{ objectFit: "contain" }} />
            Memory
          </a>
          {/* Desktop links */}
          <ul className="nav-links">
            <li><a href="#what">What is Memory</a></li>
            <li><a href="#how">How it works</a></li>
            <li><a href="#why">Why Memory</a></li>
            <li><a href="#faq">FAQ</a></li>
          </ul>
          {/* Hamburger button (mobile only) */}
          <button
            className={`mobile-menu-btn ${menuOpen ? "open" : ""}`}
            onClick={() => setMenuOpen(!menuOpen)}
            aria-label={menuOpen ? "Close menu" : "Open menu"}
            aria-expanded={menuOpen}
          >
            <span /><span /><span />
          </button>
        </div>
      </nav>

      {/* Mobile full-screen menu */}
      <div className={`mobile-nav ${menuOpen ? "open" : ""}`} role="navigation" aria-label="Mobile menu">
        {["#what", "#how", "#why", "#faq"].map((href, i) => (
          <a key={i} href={href} onClick={() => setMenuOpen(false)}>
            {["What is Memory", "How it works", "Why Memory", "FAQ"][i]}
          </a>
        ))}
      </div>

      {/* ─── HERO ───────────────────────────────────────────────────────── */}
      <section id="hero">
        <div className="wrap hero-grid">

          {/* Text */}
          <div className="hero-text">
            <div className="_r" style={{ display: "flex", alignItems: "center", gap: "12px" }}>
              <img src="/logo.png" alt="Memory ghost logo" width={56} height={56} style={{ objectFit: "contain" }} />
            </div>

            <h1 className="h1 _r _d1" style={{ color: "#000", maxWidth: "560px" }}>
              Share memories with the people who made them.
            </h1>

            <p className="_r _d2 body-lg" style={{ maxWidth: "440px" }}>
              Memory is a private short-video app where life&apos;s best moments stay with the people who actually experienced them.
            </p>

            <div className="hero-btns _r _d3" style={{ display: "flex", gap: "12px", flexWrap: "wrap", paddingTop: "8px" }}>
              <a href="#how" className="btn-black">Learn how it works</a>
            </div>

            <p className="_r _d4" style={{ fontSize: "13px", color: "rgba(0,0,0,0.38)", fontWeight: 500 }}>
              Private by default · No ads · No algorithms
            </p>
          </div>

          {/* Phone mockup */}
          <div className="_r _d2 hero-mockup-col" style={{ display: "flex", justifyContent: "center", alignItems: "flex-end" }}>
            <img
              src="/mockup.png"
              alt="Memory app — login screen showing the yellow interface with ghost logo and Memory branding"
              className="mockup-img"
              style={{
                maxHeight: "820px",
                width: "100%",
                maxWidth: "540px",
                objectFit: "contain",
                filter: "drop-shadow(0 24px 48px rgba(0,0,0,0.2))",
              }}
              width={540}
              height={820}
            />
          </div>

        </div>
      </section>

      {/* ─── WHAT IS MEMORY ─────────────────────────────────────────────── */}
      <section id="what" className="sec">
        <div className="wrap what-grid">

          {/* Left: contrast question */}
          <div style={{ display: "flex", flexDirection: "column", gap: "20px" }}>
            <p className="label _r">The difference</p>
            <div className="quote-block _r _d1">
              <div className="quote-lbl">Most social media asks:</div>
              <div className="quote-txt">&ldquo;Who should see this?&rdquo;</div>
            </div>
            <div className="quote-block alt _r _d2">
              <div className="quote-lbl">Memory asks:</div>
              <div className="quote-txt">&ldquo;Who was actually there?&rdquo;</div>
            </div>
          </div>

          {/* Right: answer */}
          <div style={{ display: "flex", flexDirection: "column", gap: "20px" }}>
            <h2 className="h2 _r">What is Memory?</h2>
            <p className="body-lg _r _d1">
              Instead of posting to everyone, share your short videos only with the people who lived that moment with you.
            </p>
            <p className="body-lg _r _d2">
              No followers. No public feed. No strangers. Just your Circle — the real people who were actually there.
            </p>
            <p className="body-lg _r _d3">
              Memory isn&apos;t about going viral.<br />
              Memory is about staying connected to the moments that actually matter.
            </p>
          </div>

        </div>
      </section>

      {/* ─── HOW IT WORKS ───────────────────────────────────────────────── */}
      <section id="how" className="sec">
        <div className="wrap">
          <p className="label _r">Simple by design</p>
          <h2 className="h2 _r _d1" style={{ marginBottom: "52px", maxWidth: "480px" }}>
            How Memory works
          </h2>

          <div className="how-cards">
            {STEPS.map((s, i) => (
              <div key={i} className={`how-card _r _d${i + 1}`}>
                <div>
                  <div className="step-lbl">Step {s.num}</div>
                  <div className="how-icon" style={{ marginTop: "8px" }}>{s.icon}</div>
                </div>
                <h3 className="h3">{s.title}</h3>
                <p className="body">{s.body}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ─── WHY MEMORY ─────────────────────────────────────────────────── */}
      <section id="why" className="sec">
        <div className="wrap">
          <p className="label _r" style={{ color: "#F4C430", opacity: 1 }}>Built differently</p>
          <h2 className="h2 _r _d1" style={{ color: "#fff", marginBottom: "52px" }}>
            Why Memory?
          </h2>

          <div className="why-cards">
            {WHY.map((w, i) => (
              <div key={i} className={`why-card _r _d${i + 1}`}>
                <div className="why-title">{w.title}</div>
                <p className="why-body">{w.body}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ─── FAQ ────────────────────────────────────────────────────────── */}
      <section id="faq" className="sec">
        <div className="wrap">
          <p className="label _r">Common questions</p>
          <h2 className="h2 _r _d1" style={{ marginBottom: "52px" }}>
            Frequently asked questions
          </h2>

          <div className="faq-list">
            {FAQS.map((item, i) => (
              <div key={i} className="faq-item">
                <button
                  className="faq-btn _r"
                  onClick={() => toggleFaq(i)}
                  aria-expanded={faqOpen === i}
                >
                  <span className="faq-q">{item.q}</span>
                  <span className={`faq-plus ${faqOpen === i ? "open" : ""}`} aria-hidden="true">+</span>
                </button>
                <div className={`faq-body ${faqOpen === i ? "open" : ""}`}>
                  <p>{item.a}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ─── FINAL CTA ──────────────────────────────────────────────────── */}
      <section id="cta">
        <div className="cta-in">
          <div className="_r">
            <img src="/logo.png" alt="Memory" width={64} height={64} style={{ objectFit: "contain" }} />
          </div>

          <h2 className="h1 _r _d1" style={{ color: "#fff" }}>
            Keep it<br />between us.
          </h2>

          <p className="_r _d2" style={{ fontSize: "clamp(16px,2vw,19px)", color: "rgba(255,255,255,0.48)", lineHeight: 1.65, maxWidth: "400px" }}>
            Start sharing life&apos;s best moments with the people who were actually there.
          </p>

          <p className="_r _d3" style={{ fontSize: "14px", color: "rgba(255,255,255,0.35)", fontWeight: 600, letterSpacing: "0.5px" }}>
            Coming soon on Android &amp; iOS
          </p>
        </div>
      </section>

      {/* ─── FOOTER ─────────────────────────────────────────────────────── */}
      <footer>
        <div className="foot-in">
          <div className="foot-top">
            <a href="#hero" className="foot-brand">
              <img src="/logo.png" alt="Memory" width={22} height={22} style={{ objectFit: "contain" }} />
              Memory
            </a>
            <div className="foot-links">
              <a href="/privacy">Privacy Policy</a>
              <a href="/terms">Terms</a>
              <a href="https://www.instagram.com/mymemoriestoday/" target="_blank" rel="noopener noreferrer">Instagram</a>
              <a href="https://www.tiktok.com/@memoryapp" target="_blank" rel="noopener noreferrer">TikTok</a>
            </div>
          </div>
          <div className="foot-bottom" style={{ display: "flex", justifyContent: "space-between", flexWrap: "wrap", gap: "8px" }}>
            <span>&copy; {new Date().getFullYear()} Memory App. All rights reserved.</span>
            <span style={{ opacity: 0.5 }}>Powered by <a href="#" style={{ color: "inherit", fontWeight: 700 }}>Evolve</a></span>
          </div>
        </div>
      </footer>
    </>
  );
}
