"use client";

import React, { useState, useEffect, useRef } from "react";
import Script from "next/script";

// Inline SVGs for beautiful minimal design
const LogoSVG = ({ className = "w-8 h-8", color = "currentColor" }) => (
  <svg className={className} viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg">
    <circle cx="50" cy="50" r="38" stroke={color} strokeWidth="10" />
    <circle cx="50" cy="50" r="18" fill={color} />
    <circle cx="50" cy="18" r="8" fill={color} />
  </svg>
);

const LockSVG = ({ className = "w-16 h-16" }) => (
  <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
    <rect x="3" y="11" width="18" height="11" rx="8" ry="8" />
    <path d="M7 11V7a5 5 0 0 1 10 0v4" />
  </svg>
);

const CheckSVG = () => (
  <svg className="w-5 h-5 text-emerald-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
    <polyline points="20 6 9 17 4 12" />
  </svg>
);

const CrossSVG = () => (
  <svg className="w-5 h-5 text-red-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <line x1="18" y1="6" x2="6" y2="18" />
    <line x1="6" y1="6" x2="18" y2="18" />
  </svg>
);

export default function Home() {
  const [activeSection, setActiveSection] = useState("hero");
  const [isScrolled, setIsScrolled] = useState(false);
  const [faqOpen, setFaqOpen] = useState<number | null>(null);
  const [phoneRotation, setPhoneRotation] = useState(0);
  const phoneRef = useRef<HTMLDivElement>(null);

  // Scroll reveal logic
  useEffect(() => {
    const handleScroll = () => {
      // Navbar background state
      setIsScrolled(window.scrollY > 50);

      // Phone rotation parallax
      if (phoneRef.current) {
        const rect = phoneRef.current.getBoundingClientRect();
        const viewportHeight = window.innerHeight;
        if (rect.top < viewportHeight && rect.bottom > 0) {
          const progress = (viewportHeight - rect.top) / (viewportHeight + rect.height);
          // Rotate between -12 and 12 degrees
          setPhoneRotation(-12 + progress * 24);
        }
      }

      // Active section highlighting
      const sections = ["hero", "why", "how", "difference", "moments", "privacy", "preview", "faq"];
      const scrollPos = window.scrollY + 200;

      for (const section of sections) {
        const el = document.getElementById(section);
        if (el) {
          const top = el.offsetTop;
          const height = el.offsetHeight;
          if (scrollPos >= top && scrollPos < top + height) {
            setActiveSection(section);
            break;
          }
        }
      }
    };

    window.addEventListener("scroll", handleScroll);
    
    // Intersection Observer for scroll animations
    const observerOptions = {
      root: null,
      threshold: 0.1,
      rootMargin: "0px 0px -50px 0px"
    };

    const observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("reveal-active");
        }
      });
    }, observerOptions);

    const revealElements = document.querySelectorAll(".scroll-reveal");
    revealElements.forEach((el) => observer.observe(el));

    return () => {
      window.removeEventListener("scroll", handleScroll);
      observer.disconnect();
    };
  }, []);

  const toggleFaq = (index: number) => {
    setFaqOpen(faqOpen === index ? null : index);
  };

  return (
    <>
      {/* Styles for scroll reveals, transitions, and customized styling */}
      <style jsx global>{`
        .scroll-reveal {
          opacity: 0;
          transform: translateY(30px);
          filter: blur(5px);
          transition: opacity 1.2s cubic-bezier(0.16, 1, 0.3, 1),
                      transform 1.2s cubic-bezier(0.16, 1, 0.3, 1),
                      filter 1.2s cubic-bezier(0.16, 1, 0.3, 1);
        }
        .reveal-active {
          opacity: 1;
          transform: translateY(0);
          filter: blur(0);
        }
        .stagger-1 { transition-delay: 100ms; }
        .stagger-2 { transition-delay: 200ms; }
        .stagger-3 { transition-delay: 300ms; }
        .stagger-4 { transition-delay: 400ms; }

        /* Custom buttons & hover states */
        .btn-primary {
          background-color: var(--color-black);
          color: var(--color-white);
          border: 1px solid var(--color-black);
          border-radius: var(--border-radius-full);
          padding: 16px 32px;
          font-weight: 600;
          font-size: 15px;
          cursor: pointer;
          transition: var(--transition-fast);
          display: inline-flex;
          align-items: center;
          justify-content: center;
          text-decoration: none;
        }
        .btn-primary:hover {
          background-color: var(--color-yellow);
          color: var(--color-black);
          border-color: var(--color-yellow);
          transform: translateY(-2px);
        }
        .btn-secondary {
          background-color: transparent;
          color: var(--color-black);
          border: 1px solid var(--color-gray-mid);
          border-radius: var(--border-radius-full);
          padding: 16px 32px;
          font-weight: 600;
          font-size: 15px;
          cursor: pointer;
          transition: var(--transition-fast);
          display: inline-flex;
          align-items: center;
          justify-content: center;
          text-decoration: none;
        }
        .btn-secondary:hover {
          border-color: var(--color-black);
          background-color: rgba(0, 0, 0, 0.02);
          transform: translateY(-2px);
        }

        /* Glassmorphism Navigation */
        .navbar {
          position: fixed;
          top: 0;
          left: 0;
          width: 100%;
          z-index: 1000;
          transition: var(--transition-smooth);
          padding: 24px;
        }
        .navbar-scrolled {
          background-color: var(--color-glass);
          backdrop-filter: blur(20px);
          -webkit-backdrop-filter: blur(20px);
          border-bottom: 1px solid var(--color-glass-border);
          padding: 16px 24px;
        }
        
        /* Interactive Circle Diagram */
        .circle-container {
          position: relative;
          width: 100%;
          aspect-ratio: 1;
          max-width: 440px;
          margin: 0 auto;
        }
        .circle-center {
          position: absolute;
          top: 50%;
          left: 50%;
          transform: translate(-50%, -50%);
          width: 90px;
          height: 90px;
          background: var(--color-yellow);
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
          z-index: 10;
          box-shadow: 0 0 40px rgba(244, 196, 48, 0.3);
        }
        .circle-orbit {
          position: absolute;
          top: 50%;
          left: 50%;
          transform: translate(-50%, -50%);
          border: 1px dashed var(--color-gray-mid);
          border-radius: 50%;
        }
        .orbit-1 { width: 60%; height: 60%; }
        .orbit-2 { width: 90%; height: 90%; }
        
        .bubble {
          position: absolute;
          background: var(--color-white);
          border: 1px solid var(--color-glass-border);
          border-radius: var(--border-radius-full);
          padding: 12px 20px;
          box-shadow: 0 4px 20px rgba(0, 0, 0, 0.04);
          font-weight: 600;
          font-size: 13px;
          display: flex;
          align-items: center;
          gap: 8px;
          transition: var(--transition-smooth);
        }
        .bubble:hover {
          transform: scale(1.08) translateY(-4px);
          box-shadow: 0 8px 30px rgba(0, 0, 0, 0.08);
          border-color: var(--color-yellow);
        }

        .avatar-dot {
          width: 8px;
          height: 8px;
          border-radius: 50%;
          background: var(--color-yellow);
        }

        /* Comparison Row Styles */
        .comparison-grid {
          display: grid;
          grid-template-columns: 1fr 1fr;
          gap: 24px;
        }
        @media (max-width: 768px) {
          .comparison-grid {
            grid-template-columns: 1fr;
          }
        }

        /* Masonry Gallery */
        .masonry-grid {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
          grid-gap: 24px;
          grid-auto-rows: 280px;
        }
        .gallery-item {
          position: relative;
          overflow: hidden;
          border-radius: var(--border-radius-md);
          background-color: var(--color-gray-light);
          cursor: pointer;
          transition: var(--transition-smooth);
        }
        .gallery-item-wide {
          grid-column: span 2;
        }
        .gallery-item-tall {
          grid-row: span 2;
        }
        @media (max-width: 640px) {
          .gallery-item-wide {
            grid-column: span 1;
          }
          .gallery-item-tall {
            grid-row: span 1;
          }
        }
        .gallery-img-container {
          width: 100%;
          height: 100%;
          position: relative;
          background-size: cover;
          background-position: center;
          transition: transform 0.8s cubic-bezier(0.16, 1, 0.3, 1);
        }
        .gallery-item:hover .gallery-img-container {
          transform: scale(1.04);
        }
        .gallery-caption {
          position: absolute;
          bottom: 0;
          left: 0;
          width: 100%;
          padding: 24px;
          background: linear-gradient(transparent, rgba(0, 0, 0, 0.4));
          color: var(--color-white);
          opacity: 0;
          transform: translateY(10px);
          transition: var(--transition-smooth);
          font-weight: 500;
          font-size: 14px;
        }
        .gallery-item:hover .gallery-caption {
          opacity: 1;
          transform: translateY(0);
        }

        /* Accordion style */
        .accordion-item {
          border-bottom: 1px solid var(--color-gray-mid);
        }
        .accordion-trigger {
          width: 100%;
          display: flex;
          justify-content: space-between;
          align-items: center;
          padding: 24px 0;
          background: transparent;
          border: none;
          cursor: pointer;
          text-align: left;
          font-size: 18px;
          font-weight: 600;
          color: var(--color-black);
          transition: var(--transition-fast);
        }
        .accordion-trigger:hover {
          color: var(--color-yellow);
        }
        .accordion-content {
          max-height: 0;
          overflow: hidden;
          transition: max-height 0.4s cubic-bezier(0.16, 1, 0.3, 1);
          color: var(--color-gray-dark);
          font-size: 15px;
          line-height: 1.6;
        }
        .accordion-content.open {
          max-height: 200px;
          padding-bottom: 24px;
        }
      `}</style>

      {/* Navigation Header */}
      <header className={`navbar ${isScrolled ? "navbar-scrolled" : ""}`}>
        <div className="container-custom flex justify-between items-center" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <a href="#hero" className="flex items-center gap-3" style={{ display: 'flex', alignItems: 'center', gap: '12px', textDecoration: 'none', color: 'inherit' }}>
            <LogoSVG className="w-7 h-7" color="#F4C430" />
            <span style={{ fontWeight: 800, fontSize: '20px', letterSpacing: '-0.5px' }}>Memory</span>
          </a>
          <nav className="hidden md:flex items-center gap-8" style={{ display: 'flex', alignItems: 'center', gap: '32px' }}>
            <a href="#why" className={`text-sm font-medium transition-colors`} style={{ textDecoration: 'none', color: activeSection === 'why' ? '#F4C430' : '#7E7E82', fontSize: '14px', fontWeight: 500 }}>Philosophy</a>
            <a href="#how" className={`text-sm font-medium transition-colors`} style={{ textDecoration: 'none', color: activeSection === 'how' ? '#F4C430' : '#7E7E82', fontSize: '14px', fontWeight: 500 }}>How It Works</a>
            <a href="#difference" className={`text-sm font-medium transition-colors`} style={{ textDecoration: 'none', color: activeSection === 'difference' ? '#F4C430' : '#7E7E82', fontSize: '14px', fontWeight: 500 }}>The Difference</a>
            <a href="#moments" className={`text-sm font-medium transition-colors`} style={{ textDecoration: 'none', color: activeSection === 'moments' ? '#F4C430' : '#7E7E82', fontSize: '14px', fontWeight: 500 }}>Moments</a>
            <a href="#faq" className={`text-sm font-medium transition-colors`} style={{ textDecoration: 'none', color: activeSection === 'faq' ? '#F4C430' : '#7E7E82', fontSize: '14px', fontWeight: 500 }}>FAQ</a>
          </nav>
          <div>
            <a href="#cta" className="btn-primary" style={{ padding: '10px 20px', fontSize: '13px' }}>Get Started</a>
          </div>
        </div>
      </header>

      {/* Hero Section */}
      <section id="hero" className="flex items-center justify-center min-h-screen section-padding" style={{ display: 'flex', flexDirection: 'column', justifyContent: 'center', alignItems: 'center', minHeight: '100vh', textAlign: 'center', backgroundColor: 'var(--color-white)', position: 'relative' }}>
        <div className="container-custom flex flex-col items-center gap-6" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '24px' }}>
          <div className="animate-fade-in flex items-center gap-2" style={{ border: '1px solid var(--color-glass-border)', padding: '6px 16px', borderRadius: 'var(--border-radius-full)', backgroundColor: 'var(--color-gray-light)', fontSize: '13px', fontWeight: 600, color: 'var(--color-gray-dark)', display: 'inline-flex' }}>
            <span className="w-2 h-2 rounded-full" style={{ width: '8px', height: '8px', borderRadius: '50%', backgroundColor: 'var(--color-yellow)' }}></span>
            A new way to keep memories.
          </div>
          <div className="animate-fade-in stagger-1" style={{ margin: '16px 0' }}>
            <LogoSVG className="w-16 h-16 animate-float" color="#F4C430" />
          </div>
          <h1 className="animate-fade-in-blur stagger-2" style={{ fontFamily: 'var(--font-sans)', fontSize: 'clamp(40px, 8vw, 76px)', fontWeight: 800, letterSpacing: '-2px', lineHeight: 1.05, maxWidth: '800px' }}>
            For the people who were there.
          </h1>
          <p className="animate-fade-in stagger-3" style={{ fontSize: 'clamp(16px, 2.5vw, 20px)', color: 'var(--color-gray-dark)', maxWidth: '640px', lineHeight: 1.6, fontWeight: 400 }}>
            Memory is a private short-video app where life's best moments stay with the people who actually experienced them. Instead of sharing with hundreds of followers, you create circles around the people that mattered in that moment.
          </p>
          <div className="animate-fade-in stagger-4 flex flex-col sm:flex-row gap-4" style={{ display: 'flex', gap: '16px', marginTop: '16px', flexDirection: 'row' }}>
            <a href="#cta" className="btn-primary">Download Memory</a>
            <a href="#why" className="btn-secondary">See How It Works</a>
          </div>
        </div>
      </section>

      {/* Section 2 — Why Memory Exists */}
      <section id="why" className="section-padding scroll-reveal" style={{ backgroundColor: 'var(--color-gray-light)' }}>
        <div className="container-custom">
          <h2 className="scroll-reveal stagger-1" style={{ fontSize: 'clamp(28px, 4vw, 44px)', fontWeight: 800, letterSpacing: '-1.5px', marginBottom: '80px', maxWidth: '800px', lineHeight: 1.2 }}>
            Social media helped us share everything. But it made memories feel less personal.
          </h2>
          
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '80px', alignItems: 'center' }}>
            {/* Left side text */}
            <div className="scroll-reveal stagger-2" style={{ display: 'flex', flexDirection: 'column', gap: '32px' }}>
              <p style={{ fontSize: '18px', lineHeight: 1.7, color: 'var(--color-gray-dark)' }}>
                Birthdays, road trips, graduations, late-night conversations, vacations and random funny moments become more meaningful when shared only with the people who lived them.
              </p>
              <p style={{ fontSize: '18px', lineHeight: 1.7, color: 'var(--color-gray-dark)' }}>
                By removing the audience, the likes, and the performance, we make room for actual, unedited reality. Memory is a vault where moments aren't broadcasted to the crowd, but treasured within your circle.
              </p>
            </div>

            {/* Right side illustration */}
            <div className="scroll-reveal stagger-3">
              <div className="circle-container">
                <div className="circle-center">
                  <LogoSVG className="w-10 h-10" color="#0A0A0A" />
                </div>
                <div className="circle-orbit orbit-1"></div>
                <div className="circle-orbit orbit-2"></div>
                
                {/* Simulated Floating Circle Tags */}
                <div className="bubble" style={{ top: '15%', left: '15%' }}>
                  <span className="avatar-dot"></span> Road Trip '26
                </div>
                <div className="bubble" style={{ top: '35%', right: '-5%' }}>
                  <span className="avatar-dot" style={{ backgroundColor: '#0A0A0A' }}></span> Nairobi Crew
                </div>
                <div className="bubble" style={{ bottom: '20%', left: '0%' }}>
                  <span className="avatar-dot"></span> Family Dinner
                </div>
                <div className="bubble" style={{ bottom: '10%', right: '15%' }}>
                  <span className="avatar-dot" style={{ backgroundColor: '#7E7E82' }}></span> Camping Trip
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Section 3 — How It Works */}
      <section id="how" className="section-padding scroll-reveal">
        <div className="container-custom">
          <div style={{ textAlign: 'center', marginBottom: '80px' }}>
            <span style={{ fontSize: '14px', fontWeight: 700, color: 'var(--color-yellow)', textTransform: 'uppercase', letterSpacing: '2px' }}>Handcrafted Flow</span>
            <h2 style={{ fontSize: 'clamp(28px, 4vw, 44px)', fontWeight: 800, letterSpacing: '-1.5px', marginTop: '12px' }}>How it works</h2>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '32px' }}>
            {/* Capture */}
            <div className="scroll-reveal stagger-1" style={{ backgroundColor: 'var(--color-gray-light)', padding: '48px 32px', borderRadius: 'var(--border-radius-md)', display: 'flex', flexDirection: 'column', gap: '20px' }}>
              <div style={{ width: '48px', height: '48px', borderRadius: '12px', backgroundColor: 'var(--color-yellow)', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '12px' }}>
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-6 h-6"><path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/></svg>
              </div>
              <h3 style={{ fontSize: '20px', fontWeight: 700 }}>Capture</h3>
              <p style={{ color: 'var(--color-gray-dark)', lineHeight: 1.6 }}>
                Record a short video. Not a perfectly edited post. Just the moment.
              </p>
            </div>

            {/* Choose Your Circle */}
            <div className="scroll-reveal stagger-2" style={{ backgroundColor: 'var(--color-gray-light)', padding: '48px 32px', borderRadius: 'var(--border-radius-md)', display: 'flex', flexDirection: 'column', gap: '20px' }}>
              <div style={{ width: '48px', height: '48px', borderRadius: '12px', backgroundColor: 'var(--color-yellow)', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '12px' }}>
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-6 h-6"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="4"/></svg>
              </div>
              <h3 style={{ fontSize: '20px', fontWeight: 700 }}>Choose Your Circle</h3>
              <p style={{ color: 'var(--color-gray-dark)', lineHeight: 1.6 }}>
                Select only the people who were there. No followers. No public feed. No strangers.
              </p>
            </div>

            {/* Relive Together */}
            <div className="scroll-reveal stagger-3" style={{ backgroundColor: 'var(--color-gray-light)', padding: '48px 32px', borderRadius: 'var(--border-radius-md)', display: 'flex', flexDirection: 'column', gap: '20px' }}>
              <div style={{ width: '48px', height: '48px', borderRadius: '12px', backgroundColor: 'var(--color-yellow)', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '12px' }}>
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-6 h-6"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>
              </div>
              <h3 style={{ fontSize: '20px', fontWeight: 700 }}>Relive Together</h3>
              <p style={{ color: 'var(--color-gray-dark)', lineHeight: 1.6 }}>
                Everyone in that circle keeps the memory forever. Comments, reactions and conversations stay attached.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Section 4 — The Difference */}
      <section id="difference" className="section-padding scroll-reveal" style={{ backgroundColor: 'var(--color-gray-light)' }}>
        <div className="container-custom">
          <div style={{ textAlign: 'center', marginBottom: '80px' }}>
            <span style={{ fontSize: '14px', fontWeight: 700, color: 'var(--color-yellow)', textTransform: 'uppercase', letterSpacing: '2px' }}>Comparing Philosophies</span>
            <h2 style={{ fontSize: 'clamp(28px, 4vw, 44px)', fontWeight: 800, letterSpacing: '-1.5px', marginTop: '12px' }}>A new model</h2>
          </div>

          <div className="comparison-grid">
            {/* Memory Card */}
            <div className="scroll-reveal stagger-1" style={{ backgroundColor: 'var(--color-white)', padding: '48px', borderRadius: 'var(--border-radius-lg)', border: '1px solid var(--color-glass-border)', display: 'flex', flexDirection: 'column', gap: '32px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
                <LogoSVG className="w-10 h-10" color="#F4C430" />
                <h3 style={{ fontSize: '24px', fontWeight: 800 }}>Memory</h3>
              </div>
              <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '20px' }}>
                <li style={{ display: 'flex', alignItems: 'center', gap: '12px', fontWeight: 500 }}><CheckSVG /> Private circles</li>
                <li style={{ display: 'flex', alignItems: 'center', gap: '12px', fontWeight: 500 }}><CheckSVG /> Short videos</li>
                <li style={{ display: 'flex', alignItems: 'center', gap: '12px', fontWeight: 500 }}><CheckSVG /> Shared experiences</li>
                <li style={{ display: 'flex', alignItems: 'center', gap: '12px', fontWeight: 500 }}><CheckSVG /> Real friends</li>
                <li style={{ display: 'flex', alignItems: 'center', gap: '12px', fontWeight: 500 }}><CheckSVG /> No public audience</li>
                <li style={{ display: 'flex', alignItems: 'center', gap: '12px', fontWeight: 500 }}><CheckSVG /> Built for memories</li>
              </ul>
            </div>

            {/* Traditional Social Media */}
            <div className="scroll-reveal stagger-2" style={{ backgroundColor: 'var(--color-white)', padding: '48px', borderRadius: 'var(--border-radius-lg)', border: '1px solid var(--color-glass-border)', display: 'flex', flexDirection: 'column', gap: '32px', opacity: 0.7 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
                <h3 style={{ fontSize: '24px', fontWeight: 800, color: 'var(--color-gray-dark)' }}>Traditional Social</h3>
              </div>
              <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '20px' }}>
                <li style={{ display: 'flex', alignItems: 'center', gap: '12px', color: 'var(--color-gray-dark)' }}><CrossSVG /> Followers</li>
                <li style={{ display: 'flex', alignItems: 'center', gap: '12px', color: 'var(--color-gray-dark)' }}><CrossSVG /> Likes</li>
                <li style={{ display: 'flex', alignItems: 'center', gap: '12px', color: 'var(--color-gray-dark)' }}><CrossSVG /> Algorithms</li>
                <li style={{ display: 'flex', alignItems: 'center', gap: '12px', color: 'var(--color-gray-dark)' }}><CrossSVG /> Everyone</li>
                <li style={{ display: 'flex', alignItems: 'center', gap: '12px', color: 'var(--color-gray-dark)' }}><CrossSVG /> Endless scrolling</li>
                <li style={{ display: 'flex', alignItems: 'center', gap: '12px', color: 'var(--color-gray-dark)' }}><CrossSVG /> Performative posting</li>
              </ul>
            </div>
          </div>
        </div>
      </section>

      {/* Section 5 — Real Moments */}
      <section id="moments" className="section-padding scroll-reveal">
        <div className="container-custom">
          <div style={{ textAlign: 'center', marginBottom: '80px' }}>
            <span style={{ fontSize: '14px', fontWeight: 700, color: 'var(--color-yellow)', textTransform: 'uppercase', letterSpacing: '2px' }}>Authentic Masonry Grid</span>
            <h2 style={{ fontSize: 'clamp(28px, 4vw, 44px)', fontWeight: 800, letterSpacing: '-1.5px', marginTop: '12px' }}>Real moments</h2>
          </div>

          <div className="masonry-grid">
            {/* Item 1 */}
            <div className="gallery-item gallery-item-wide scroll-reveal stagger-1">
              <div className="gallery-img-container" style={{ backgroundImage: 'url("/assets/images/beach_sunset.png")' }}></div>
              <div className="gallery-caption">Beach Sunset • Maui</div>
            </div>
            {/* Item 2 */}
            <div className="gallery-item gallery-item-tall scroll-reveal stagger-2">
              <div className="gallery-img-container" style={{ backgroundImage: 'url("/assets/images/camping_trip.png")' }}></div>
              <div className="gallery-caption">Camping • Mt. Kenya</div>
            </div>
            {/* Item 3 */}
            <div className="gallery-item scroll-reveal stagger-3">
              <div className="gallery-img-container" style={{ backgroundImage: 'url("/assets/images/family_dinner.png")' }}></div>
              <div className="gallery-caption">Family Dinner • Nairobi</div>
            </div>
            {/* Item 4 */}
            <div className="gallery-item scroll-reveal stagger-4">
              <div className="gallery-img-container" style={{ backgroundImage: 'url("/assets/images/road_trip.png")' }}></div>
              <div className="gallery-caption">Road Trip • Rift Valley</div>
            </div>
            {/* Item 5 */}
            <div className="gallery-item gallery-item-wide scroll-reveal stagger-1">
              <div className="gallery-img-container" style={{ backgroundImage: 'url("/assets/images/birthday_candles.png")' }}></div>
              <div className="gallery-caption">Birthday Candles • July 2026</div>
            </div>
          </div>
        </div>
      </section>

      {/* Section 6 — Privacy */}
      <section id="privacy" className="section-padding scroll-reveal" style={{ backgroundColor: 'var(--color-black)', color: 'var(--color-white)' }}>
        <div className="container-custom" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', gap: '32px' }}>
          <div style={{ color: 'var(--color-yellow)', marginBottom: '16px' }}>
            <LockSVG className="w-16 h-16 animate-float" />
          </div>
          <h2 style={{ fontSize: 'clamp(32px, 5vw, 54px)', fontWeight: 800, letterSpacing: '-1.5px', maxWidth: '800px', lineHeight: 1.1 }}>
            Your memories belong to your circle.
          </h2>
          <p style={{ fontSize: '18px', color: 'var(--color-gray-dark)', maxWidth: '640px', lineHeight: 1.7 }}>
            Memory isn't about broadcasting your life. It is about preserving it with the people who matter. We don't trace tracking cookies, we don't sell ads, and we encrypt files in transit and at rest.
          </p>
        </div>
      </section>

      {/* Section 7 — App Preview */}
      <section id="preview" className="section-padding scroll-reveal" style={{ overflow: 'hidden' }}>
        <div className="container-custom" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '80px' }}>
          <div style={{ textAlign: 'center' }}>
            <span style={{ fontSize: '14px', fontWeight: 700, color: 'var(--color-yellow)', textTransform: 'uppercase', letterSpacing: '2px' }}>Interactive Device Parallax</span>
            <h2 style={{ fontSize: 'clamp(28px, 4vw, 44px)', fontWeight: 800, letterSpacing: '-1.5px', marginTop: '12px' }}>Designed for your pocket</h2>
          </div>

          <div ref={phoneRef} style={{ perspective: '1000px', width: '100%', display: 'flex', justifyContent: 'center' }}>
            <div style={{ 
              width: '320px', 
              height: '640px', 
              borderRadius: '40px', 
              border: '12px solid var(--color-black)',
              boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.25)',
              background: 'var(--color-white)',
              overflow: 'hidden',
              position: 'relative',
              transform: `rotateY(${phoneRotation}deg) rotateX(10deg)`,
              transition: 'transform 0.1s ease-out'
            }}>
              {/* Phone Status Bar */}
              <div style={{ height: '24px', backgroundColor: 'var(--color-black)', color: 'var(--color-white)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '0 24px', fontSize: '11px', fontWeight: 600 }}>
                <span>9:41</span>
                <div style={{ display: 'flex', gap: '4px' }}>
                  <span style={{ width: '12px', height: '12px', borderRadius: '2px', border: '1px solid var(--color-white)', display: 'inline-block' }}></span>
                </div>
              </div>

              {/* Simulated Feed View inside the mockup */}
              <div style={{ padding: '24px', display: 'flex', flexDirection: 'column', gap: '20px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                  <div style={{ width: '32px', height: '32px', borderRadius: '50%', backgroundColor: 'var(--color-yellow)' }}></div>
                  <div>
                    <div style={{ fontSize: '12px', fontWeight: 700 }}>Amara</div>
                    <div style={{ fontSize: '10px', color: 'var(--color-gray-dark)' }}>Nairobi Crew • 8 min ago</div>
                  </div>
                </div>
                
                {/* Card memory frame simulator */}
                <div style={{ 
                  height: '360px', 
                  borderRadius: '24px', 
                  background: 'linear-gradient(135deg, #ff826e 0%, #ffc857 42%, #5ed6b3 100%)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  color: 'var(--color-white)',
                  fontWeight: 800,
                  fontSize: '14px',
                  boxShadow: 'inset 0 -60px 80px rgba(0,0,0,0.3)',
                  padding: '24px',
                  alignContent: 'flex-end',
                  flexWrap: 'wrap'
                }}>
                  "The ridiculous cake moment 🎂"
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Section 8 — FAQ */}
      <section id="faq" className="section-padding scroll-reveal" style={{ backgroundColor: 'var(--color-gray-light)' }}>
        <div className="container-custom" style={{ maxWidth: '800px' }}>
          <div style={{ textAlign: 'center', marginBottom: '60px' }}>
            <span style={{ fontSize: '14px', fontWeight: 700, color: 'var(--color-yellow)', textTransform: 'uppercase', letterSpacing: '2px' }}>Common Queries</span>
            <h2 style={{ fontSize: 'clamp(28px, 4vw, 44px)', fontWeight: 800, letterSpacing: '-1.5px', marginTop: '12px' }}>Frequently asked questions</h2>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            {[
              {
                q: "What makes Memory different?",
                a: "Memory isn't about public followers or metrics. It is an invite-only space where you share short-video updates with specific, private circles representing groups of real-life friends."
              },
              {
                q: "Who can see my memories?",
                a: "Only members of the specific circle you choose when capturing the memory. There is no global feed, public discovery, or stalker profiles."
              },
              {
                q: "Can I create multiple circles?",
                a: "Yes, you can create distinct circles for different groups—such as one for your family, one for your childhood friends, and one for a weekend trip."
              },
              {
                q: "Are memories public?",
                a: "Never. Memories are fully enclosed within their circles. They cannot be shared externally or exposed to search engines."
              },
              {
                q: "Is Memory free?",
                a: "Yes, Memory's core features are completely free to use with all of your close circles."
              }
            ].map((item, idx) => (
              <div key={idx} className="accordion-item scroll-reveal">
                <button className="accordion-trigger" onClick={() => toggleFaq(idx)}>
                  <span>{item.q}</span>
                  <span>{faqOpen === idx ? "−" : "+"}</span>
                </button>
                <div className={`accordion-content ${faqOpen === idx ? "open" : ""}`}>
                  <p>{item.a}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Final CTA Section */}
      <section id="cta" className="section-padding scroll-reveal" style={{ textAlign: 'center' }}>
        <div className="container-custom flex flex-col items-center gap-8" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '32px' }}>
          <LogoSVG className="w-16 h-16 animate-float" color="#F4C430" />
          <h2 style={{ fontSize: 'clamp(36px, 6vw, 64px)', fontWeight: 800, letterSpacing: '-2px', lineHeight: 1.1 }}>
            Keep it between us.
          </h2>
          <p style={{ fontSize: '18px', color: 'var(--color-gray-dark)', maxWidth: '560px', lineHeight: 1.6 }}>
            Life happens once. Share it with the people who were actually there.
          </p>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px', alignItems: 'center' }}>
            <a href="#" className="btn-primary">Download Memory</a>
            <span style={{ fontSize: '13px', fontWeight: 600, color: 'var(--color-gray-dark)' }}>Coming Soon on Android & iPhone</span>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer style={{ borderTop: '1px solid var(--color-glass-border)', padding: '60px 24px', backgroundColor: 'var(--color-white)' }}>
        <div className="container-custom" style={{ display: 'flex', flexDirection: 'column', gap: '40px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '24px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              <LogoSVG className="w-8 h-8" color="#F4C430" />
              <span style={{ fontWeight: 800, fontSize: '18px', letterSpacing: '-0.5px' }}>Memory</span>
            </div>
            <div style={{ display: 'flex', gap: '32px', flexWrap: 'wrap' }}>
              <a href="#" style={{ textDecoration: 'none', color: 'var(--color-gray-dark)', fontSize: '14px', fontWeight: 500 }}>Privacy</a>
              <a href="#" style={{ textDecoration: 'none', color: 'var(--color-gray-dark)', fontSize: '14px', fontWeight: 500 }}>Terms</a>
              <a href="#" style={{ textDecoration: 'none', color: 'var(--color-gray-dark)', fontSize: '14px', fontWeight: 500 }}>Instagram</a>
              <a href="#" style={{ textDecoration: 'none', color: 'var(--color-gray-dark)', fontSize: '14px', fontWeight: 500 }}>TikTok</a>
            </div>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '16px', borderTop: '1px solid var(--color-gray-light)', paddingTop: '40px', fontSize: '13px', color: 'var(--color-gray-dark)' }}>
            <span>&copy; {new Date().getFullYear()} Memory App. All rights reserved.</span>
            <span>Designed with premium minimalism.</span>
          </div>
        </div>
      </footer>
    </>
  );
}
