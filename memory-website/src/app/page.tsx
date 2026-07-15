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

  useEffect(() => {
    // Navbar scroll
    const onScroll = () => setScrolled(window.scrollY > 32);
    window.addEventListener("scroll", onScroll, { passive: true });

    // Scroll reveal
    const io = new IntersectionObserver(
      (entries) => entries.forEach((e) => e.isIntersecting && e.target.classList.add("_v")),
      { threshold: 0.07, rootMargin: "0px 0px -36px 0px" }
    );
    document.querySelectorAll("._r").forEach((el) => io.observe(el));

    return () => {
      window.removeEventListener("scroll", onScroll);
      io.disconnect();
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

        /* Reveal */
        ._r {
          opacity: 0;
          transform: translateY(22px);
          transition: opacity 0.7s ease, transform 0.7s ease;
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

        /* Responsive */
        @media (max-width: 900px) {
          .hero-grid { grid-template-columns: 1fr; text-align: center; gap: 48px; padding-bottom: 60px; }
          .hero-text { align-items: center; }
          .hero-btns { justify-content: center; }
          .what-grid { grid-template-columns: 1fr; gap: 48px; }
          .how-cards { grid-template-columns: 1fr; }
          .why-cards { grid-template-columns: 1fr; }
          .nav-links { display: none; }
          .mockup-img { max-height: 460px; }
        }
        @media (max-width: 600px) {
          .sec { padding: 72px 20px; }
          .hero-btns { flex-direction: column; width: 100%; }
          .btn-black, .btn-white, .btn-white-cta { width: 100%; }
        }
      `}</style>

      {/* ─── NAV ────────────────────────────────────────────────────────── */}
      <nav className={`mem-nav ${scrolled ? "scrolled" : ""}`}>
        <div className="nav-in">
          <a href="#hero" className="nav-brand">
            <Ghost size={24} fill="#000" eyeFill="#F4C430" />
            Memory
          </a>
          <ul className="nav-links">
            <li><a href="#what">What is Memory</a></li>
            <li><a href="#how">How it works</a></li>
            <li><a href="#why">Why Memory</a></li>
            <li><a href="#faq">FAQ</a></li>
          </ul>
          <a href="#cta" className="btn-black" style={{ padding: "10px 20px", fontSize: "13px" }}>
            Download
          </a>
        </div>
      </nav>

      {/* ─── HERO ───────────────────────────────────────────────────────── */}
      <section id="hero">
        <div className="wrap hero-grid">

          {/* Text */}
          <div className="hero-text">
            <div className="_r" style={{ display: "flex", alignItems: "center", gap: "12px" }}>
              <Ghost size={52} fill="#000" eyeFill="#F4C430" />
            </div>

            <h1 className="h1 _r _d1" style={{ color: "#000", maxWidth: "560px" }}>
              Share memories with the people who made them.
            </h1>

            <p className="_r _d2 body-lg" style={{ maxWidth: "440px" }}>
              Memory is a private short-video app where life&apos;s best moments stay with the people who actually experienced them.
            </p>

            <div className="hero-btns _r _d3" style={{ display: "flex", gap: "12px", flexWrap: "wrap", paddingTop: "8px" }}>
              <a href="#cta" className="btn-black">
                <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                  <rect x="5" y="2" width="14" height="20" rx="2" />
                  <line x1="12" y1="18" x2="12" y2="18.01" />
                </svg>
                Download for Android
              </a>
              <a href="#how" className="btn-white">Learn how it works</a>
            </div>

            <p className="_r _d4" style={{ fontSize: "13px", color: "rgba(0,0,0,0.38)", fontWeight: 500 }}>
              Free · No ads · Private by default
            </p>
          </div>

          {/* Phone mockup */}
          <div className="_r _d2" style={{ display: "flex", justifyContent: "center", alignItems: "flex-end" }}>
            <img
              src="/mockup.jpg"
              alt="Memory app — login screen showing the yellow interface with ghost logo and Memory branding"
              className="mockup-img"
              style={{
                maxHeight: "680px",
                width: "auto",
                objectFit: "contain",
                filter: "drop-shadow(0 20px 40px rgba(0,0,0,0.2))",
              }}
              width={480}
              height={640}
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
            <Ghost size={60} fill="#F4C430" eyeFill="#000" />
          </div>

          <h2 className="h1 _r _d1" style={{ color: "#fff" }}>
            Keep it<br />between us.
          </h2>

          <p className="_r _d2" style={{ fontSize: "clamp(16px,2vw,19px)", color: "rgba(255,255,255,0.48)", lineHeight: 1.65, maxWidth: "400px" }}>
            Start sharing life&apos;s best moments with the people who were actually there.
          </p>

          <a href="#" className="btn-white-cta _r _d3">
            Download for Android
          </a>

          <p className="_r _d4" style={{ fontSize: "13px", color: "rgba(255,255,255,0.28)", fontWeight: 500 }}>
            Free to download · iOS coming soon
          </p>
        </div>
      </section>

      {/* ─── FOOTER ─────────────────────────────────────────────────────── */}
      <footer>
        <div className="foot-in">
          <div className="foot-top">
            <a href="#hero" className="foot-brand">
              <Ghost size={20} fill="#000" eyeFill="#F4C430" />
              Memory
            </a>
            <div className="foot-links">
              {["Privacy Policy", "Terms", "Instagram", "TikTok"].map((l) => (
                <a key={l} href="#">{l}</a>
              ))}
            </div>
          </div>
          <div className="foot-bottom">
            &copy; {new Date().getFullYear()} Memory App. All rights reserved.
          </div>
        </div>
      </footer>
    </>
  );
}
