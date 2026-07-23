import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Child Safety Standards — Memory App",
  description: "Memory App Child Safety Standards & Protection Policy against Child Sexual Abuse Material (CSAM) and Child Sexual Exploitation and Abuse (CSAE).",
};

export default function ChildSafetyStandards() {
  const effective = "24 July 2026";

  return (
    <div style={{ background: "#F4C430", minHeight: "100vh", fontFamily: "'Inter', -apple-system, sans-serif" }}>
      {/* Nav */}
      <nav style={{ borderBottom: "1.5px solid rgba(0,0,0,0.1)", padding: "0 24px", height: "64px", display: "flex", alignItems: "center", position: "sticky", top: 0, background: "#F4C430", zIndex: 100 }}>
        <div style={{ maxWidth: "860px", width: "100%", margin: "0 auto", display: "flex", justifyContent: "space-between", alignItems: "center", gap: "12px" }}>
          <Link href="/" style={{ display: "flex", alignItems: "center", gap: "10px", textDecoration: "none", color: "#000", fontWeight: 800, fontSize: "clamp(15px, 4vw, 17px)", letterSpacing: "-0.4px", flexShrink: 0 }}>
            <img src="/logo.png" alt="Memory" width={24} height={24} style={{ objectFit: "contain" }} />
            Memory
          </Link>
          <Link href="/" style={{ fontSize: "clamp(12px, 3.5vw, 14px)", fontWeight: 600, color: "rgba(0,0,0,0.55)", textDecoration: "none", whiteSpace: "nowrap" }}>← Back to Home</Link>
        </div>
      </nav>

      {/* Content */}
      <main style={{ maxWidth: "860px", margin: "0 auto", padding: "clamp(32px, 8vw, 64px) clamp(16px, 5vw, 24px) clamp(60px, 12vw, 100px)" }}>
        {/* Header */}
        <div style={{ marginBottom: "56px" }}>
          <p style={{ fontSize: "11px", fontWeight: 700, letterSpacing: "2px", textTransform: "uppercase", opacity: 0.4, marginBottom: "12px" }}>Child Protection &amp; Safety</p>
          <h1 style={{ fontSize: "clamp(36px, 6vw, 60px)", fontWeight: 900, letterSpacing: "-2px", lineHeight: 1.05, color: "#000", marginBottom: "16px" }}>
            Child Safety Standards
          </h1>
          <p style={{ fontSize: "15px", color: "rgba(0,0,0,0.5)", fontWeight: 500 }}>
            Effective date: {effective} &nbsp;·&nbsp; Governed by the Laws of Kenya &amp; International Child Protection Standards
          </p>
        </div>

        {/* Legal doc */}
        <div style={{ background: "#fff", borderRadius: "16px", padding: "clamp(32px, 5vw, 56px)" }}>
          <Legal>

            <Section title="1. Overview & Commitment">
              <P>Memory App (&ldquo;Memory&rdquo;, &ldquo;we&rdquo;, &ldquo;our&rdquo; or &ldquo;us&rdquo;) maintains strict, zero-tolerance standards against Child Sexual Abuse Material (CSAM), Child Sexual Exploitation and Abuse (CSAE), and any conduct that threatens the safety or welfare of minors.</P>
              <P>Memory is a private short-video sharing platform operating under the laws of Kenya. We adhere fully to the <strong>Children Act, 2022 (Act No. 29 of 2022)</strong>, the <strong>Computer Misuse and Cybercrimes Act, 2018 (Act No. 5 of 2018)</strong>, the <strong>Kenya Data Protection Act, 2019</strong>, and global child safety standards enforced by the Google Play Store and international law enforcement agencies.</P>
            </Section>

            <Section title="2. Zero Tolerance Policy against CSAM / CSAE">
              <P>Any attempt to create, upload, solicit, transmit, or store content depicting child sexual abuse, child sexual exploitation, or grooming behaviors will result in:</P>
              <ul style={ulStyle}>
                <li><strong>Immediate Account Termination:</strong> Permanent ban of the user&apos;s account, IP address, and associated device identifiers.</li>
                <li><strong>Content Removal &amp; Preservation:</strong> Complete deletion of offending content from public view, while preserving evidentiary records in secure isolated storage for law enforcement investigation.</li>
                <li><strong>Reporting to Authorities:</strong> Mandatory reporting to national and international child protection organizations, including the <strong>National Center for Missing &amp; Exploited Children (NCMEC)</strong> and local Kenyan law enforcement agencies (Directorate of Criminal Investigations — DCI Anti-Human Trafficking and Child Protection Unit).</li>
              </ul>
            </Section>

            <Section title="3. In-App Reporting Requirements & Safety Tools">
              <P>Memory provides dedicated, accessible reporting mechanisms within the mobile application:</P>
              <ul style={ulStyle}>
                <li><strong>In-App Content Reporting:</strong> Users can flag any video or profile instantly by tapping and holding the content or selecting the flag icon.</li>
                <li><strong>Priority Moderation Queue:</strong> Reports categorized under child safety concerns bypass standard queues and are immediately dispatched to our emergency moderation personnel.</li>
                <li><strong>Blocking Controls:</strong> Users can block accounts instantly to prevent communication or media sharing.</li>
              </ul>
            </Section>

            <Section title="4. Designated Point of Contact">
              <P>We have established a dedicated point of contact responsible for addressing all child safety inquiries, law enforcement requests, and compliance matters regarding CSAM/CSAE prevention practices:</P>
              <div style={{ background: "#F4C43020", borderLeft: "4px solid #F4C430", padding: "16px 20px", borderRadius: "0 8px 8px 0", marginTop: "12px" }}>
                <p style={{ fontSize: "15px", fontWeight: 700, color: "#000", marginBottom: "4px" }}>Designated CSAM/CSAE Safety Contact</p>
                <p style={{ fontSize: "14px", color: "rgba(0,0,0,0.75)", marginBottom: "4px" }}>Email: <a href="mailto:evolvalabskenya@gmail.com" style={{ color: "#000", fontWeight: 700 }}>evolvalabskenya@gmail.com</a></p>
                <p style={{ fontSize: "13px", color: "rgba(0,0,0,0.5)" }}>Available to communicate directly regarding child safety prevention practices and regulatory compliance.</p>
              </div>
            </Section>

            <Section title="5. Legal Reporting Compliance">
              <P>Memory complies with all relevant regional, national, and international child protection laws. We actively assist statutory authorities in investigations concerning child exploitation or harm, operating under valid legal processes and emergency disclosure protocols.</P>
            </Section>

          </Legal>
        </div>
      </main>

      {/* Footer */}
      <footer style={{ borderTop: "1.5px solid rgba(0,0,0,0.1)", padding: "32px 24px", textAlign: "center" }}>
        <p style={{ fontSize: "13px", color: "rgba(0,0,0,0.38)" }}>
          &copy; {new Date().getFullYear()} Memory App &nbsp;·&nbsp;{" "}
          <Link href="/privacy" style={{ color: "rgba(0,0,0,0.38)", textDecoration: "underline" }}>Privacy Policy</Link>
          &nbsp;·&nbsp;{" "}
          <Link href="/terms" style={{ color: "rgba(0,0,0,0.38)", textDecoration: "underline" }}>Terms of Service</Link>
          &nbsp;·&nbsp; Powered by <strong>Evolve</strong>
        </p>
      </footer>
    </div>
  );
}

// ── Helpers ──────────────────────────────────────────────────────────────────
const ulStyle: React.CSSProperties = {
  marginLeft: "24px",
  marginBottom: "16px",
  display: "flex",
  flexDirection: "column",
  gap: "8px",
  color: "rgba(0,0,0,0.65)",
  lineHeight: 1.7,
  fontSize: "15px",
};

function Legal({ children }: { children: React.ReactNode }) {
  return <div style={{ display: "flex", flexDirection: "column", gap: "40px" }}>{children}</div>;
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div>
      <h2 style={{ fontSize: "clamp(18px, 2.5vw, 22px)", fontWeight: 800, letterSpacing: "-0.4px", color: "#000", marginBottom: "16px", paddingBottom: "12px", borderBottom: "1.5px solid rgba(0,0,0,0.08)" }}>
        {title}
      </h2>
      <div style={{ display: "flex", flexDirection: "column", gap: "12px" }}>{children}</div>
    </div>
  );
}

function P({ children }: { children: React.ReactNode }) {
  return <p style={{ fontSize: "15px", lineHeight: 1.8, color: "rgba(0,0,0,0.65)" }}>{children}</p>;
}
