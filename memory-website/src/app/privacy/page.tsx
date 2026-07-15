import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Privacy Policy — Memory App",
  description: "Memory App Privacy Policy. Learn how we collect, use, and protect your personal data in accordance with the Kenya Data Protection Act, 2019.",
};

export default function PrivacyPolicy() {
  const effective = "15 July 2025";

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
          <p style={{ fontSize: "11px", fontWeight: 700, letterSpacing: "2px", textTransform: "uppercase", opacity: 0.4, marginBottom: "12px" }}>Legal</p>
          <h1 style={{ fontSize: "clamp(36px, 6vw, 60px)", fontWeight: 900, letterSpacing: "-2px", lineHeight: 1.05, color: "#000", marginBottom: "16px" }}>
            Privacy Policy
          </h1>
          <p style={{ fontSize: "15px", color: "rgba(0,0,0,0.5)", fontWeight: 500 }}>
            Effective date: {effective} &nbsp;·&nbsp; Governed by the Laws of Kenya
          </p>
        </div>

        {/* Legal doc */}
        <div style={{ background: "#fff", borderRadius: "16px", padding: "clamp(32px, 5vw, 56px)" }}>
          <Legal>

            <Section title="1. Introduction">
              <P>Memory App (&ldquo;Memory&rdquo;, &ldquo;we&rdquo;, &ldquo;our&rdquo; or &ldquo;us&rdquo;) is a private short-video application developed and operated in Kenya. We are committed to protecting your personal data and respecting your right to privacy as guaranteed under <strong>Article 31 of the Constitution of Kenya, 2010</strong>, and in full compliance with the <strong>Kenya Data Protection Act No. 24 of 2019</strong> (&ldquo;the Act&rdquo;) and its subsidiary legislation.</P>
              <P>This Privacy Policy explains how we collect, use, store, share and protect your personal information when you use the Memory mobile application and website at <strong>mymemoriestoday.site</strong> (collectively, the &ldquo;Service&rdquo;).</P>
              <P>By using our Service, you consent to the collection and use of your information as described in this Policy. If you do not agree, please discontinue use of the Service.</P>
            </Section>

            <Section title="2. Legal Framework">
              <P>Our data practices are governed by and consistent with:</P>
              <ul style={ulStyle}>
                <li>Constitution of Kenya, 2010 — Article 31 (Right to Privacy)</li>
                <li>Kenya Data Protection Act, 2019 (No. 24 of 2019)</li>
                <li>Data Protection (General) Regulations, 2021</li>
                <li>Data Protection (Registration of Data Controllers and Data Processors) Regulations, 2021</li>
                <li>Computer Misuse and Cybercrimes Act, 2018 (No. 5 of 2018)</li>
                <li>Kenya Information and Communications Act (Cap 411A)</li>
                <li>Consumer Protection Act, 2012</li>
              </ul>
              <P>We are registered as a Data Controller with the <strong>Office of the Data Protection Commissioner (ODPC)</strong> of Kenya as required by the Act.</P>
            </Section>

            <Section title="3. Data We Collect">
              <P>We collect only the minimum personal data necessary to provide the Service (&ldquo;data minimisation principle&rdquo; under Section 25(b) of the Act):</P>
              <SubSection title="3.1 Information You Provide">
                <ul style={ulStyle}>
                  <li><strong>Account information:</strong> name, email address, phone number, and username when you register.</li>
                  <li><strong>Profile information:</strong> profile photo and bio (optional).</li>
                  <li><strong>Content:</strong> short video recordings you capture and share within the app.</li>
                  <li><strong>Circle information:</strong> the contacts you invite or add to your Circles.</li>
                  <li><strong>Communications:</strong> messages, feedback, or support requests you send to us.</li>
                </ul>
              </SubSection>
              <SubSection title="3.2 Information Collected Automatically">
                <ul style={ulStyle}>
                  <li><strong>Device information:</strong> device model, operating system, unique device identifiers.</li>
                  <li><strong>Log data:</strong> IP address, access times, app features used, crash reports.</li>
                  <li><strong>Usage data:</strong> frequency of use, feature interactions (collected in aggregate, non-identifiable form).</li>
                </ul>
              </SubSection>
              <SubSection title="3.3 Information We Do Not Collect">
                <ul style={ulStyle}>
                  <li>We do not collect financial or payment information.</li>
                  <li>We do not collect sensitive personal data (health, biometric, political affiliation) as defined under Section 2 of the Act, unless you explicitly provide it.</li>
                  <li>We do not sell, rent, or trade your personal data to third parties.</li>
                </ul>
              </SubSection>
            </Section>

            <Section title="4. How We Use Your Information">
              <P>We use your personal data only for the lawful purposes stated at the time of collection, consistent with Section 30 of the Act:</P>
              <ul style={ulStyle}>
                <li>To create and manage your account and Circle memberships.</li>
                <li>To enable you to record, store, and share video memories within your chosen Circle.</li>
                <li>To send you service-related notifications (e.g. new memories shared with you).</li>
                <li>To improve and troubleshoot the Service using anonymised analytics.</li>
                <li>To respond to your support requests and enquiries.</li>
                <li>To comply with our legal obligations under Kenyan law.</li>
                <li>To detect, prevent, or investigate fraud, security breaches, or abuse of the Service.</li>
              </ul>
              <P>We will not use your data for any purpose incompatible with the above without obtaining your prior, explicit consent.</P>
            </Section>

            <Section title="5. Data Sharing">
              <P>We do not share your personal data with third parties except in the following limited circumstances:</P>
              <ul style={ulStyle}>
                <li><strong>Within your Circle:</strong> Videos and content you share are visible only to Circle members you have selected. No content is publicly accessible.</li>
                <li><strong>Service providers:</strong> We may engage trusted third-party processors (e.g. cloud storage, push notification services) bound by data processing agreements that require equivalent data protection standards.</li>
                <li><strong>Legal obligations:</strong> We may disclose your data where required by a court order, regulatory authority, or applicable Kenyan law, including the Computer Misuse and Cybercrimes Act, 2018.</li>
                <li><strong>Business transfers:</strong> In the event of a merger, acquisition, or sale of assets, your data may be transferred subject to equivalent privacy protections and notice to you.</li>
              </ul>
            </Section>

            <Section title="6. Data Storage and Security">
              <P>Your data is stored on secure servers. We implement appropriate technical and organisational measures to protect your personal data against unauthorised access, loss, destruction, or alteration, consistent with Section 41 of the Act and industry best practices, including:</P>
              <ul style={ulStyle}>
                <li>Encryption of data in transit (TLS/SSL) and at rest.</li>
                <li>Access controls and authentication mechanisms.</li>
                <li>Regular security audits and vulnerability assessments.</li>
                <li>Incident response procedures in accordance with the Data Protection (General) Regulations, 2021.</li>
              </ul>
              <P>In the event of a personal data breach that poses a risk to your rights and freedoms, we will notify the Office of the Data Protection Commissioner within <strong>72 hours</strong> of becoming aware, and notify you without undue delay, as required under Section 43 of the Act.</P>
            </Section>

            <Section title="7. Data Retention">
              <P>We retain your personal data only for as long as necessary to fulfil the purposes for which it was collected, or as required by applicable Kenyan law. Specifically:</P>
              <ul style={ulStyle}>
                <li>Account data is retained for the duration of your active account.</li>
                <li>Upon deletion of your account, your personal data will be erased within <strong>30 days</strong>, except where retention is required by law.</li>
                <li>Video content is deleted from our servers immediately upon your deletion of the memory.</li>
                <li>Log data may be retained for up to <strong>12 months</strong> for security purposes.</li>
              </ul>
            </Section>

            <Section title="8. Your Rights as a Data Subject">
              <P>Under the Kenya Data Protection Act, 2019 (Sections 26–36), you have the following rights with respect to your personal data:</P>
              <ul style={ulStyle}>
                <li><strong>Right to be informed</strong> — You have the right to know how your data is collected and used.</li>
                <li><strong>Right of access</strong> — You may request a copy of the personal data we hold about you.</li>
                <li><strong>Right to rectification</strong> — You may request correction of inaccurate or incomplete data.</li>
                <li><strong>Right to erasure</strong> — You may request deletion of your personal data (&ldquo;right to be forgotten&rdquo;).</li>
                <li><strong>Right to object</strong> — You may object to the processing of your data in certain circumstances.</li>
                <li><strong>Right to data portability</strong> — You may request your data in a portable, machine-readable format.</li>
                <li><strong>Right to withdraw consent</strong> — Where processing is based on consent, you may withdraw it at any time without affecting prior processing.</li>
                <li><strong>Right to lodge a complaint</strong> — You have the right to lodge a complaint with the <strong>Office of the Data Protection Commissioner (ODPC)</strong> at <em>www.odpc.go.ke</em>.</li>
              </ul>
              <P>To exercise any of these rights, contact us at <strong>privacy@mymemoriestoday.site</strong>. We will respond within <strong>21 days</strong> as required by the Act.</P>
            </Section>

            <Section title="9. Children&apos;s Privacy">
              <P>Memory is not directed to children under the age of <strong>18 years</strong>. We do not knowingly collect personal data from children under 18. If we become aware that a child under 18 has provided us with personal data without verifiable parental consent, we will delete such data immediately and terminate the account.</P>
              <P>If you believe a child has provided us with their data, please contact us at <strong>privacy@mymemoriestoday.site</strong>.</P>
            </Section>

            <Section title="10. Cookies and Tracking">
              <P>Our mobile application does not use traditional browser cookies. Our website may use essential cookies for session management and security purposes only. We do not use advertising, tracking, or profiling cookies. You may control cookie settings through your browser preferences.</P>
            </Section>

            <Section title="11. Cross-Border Data Transfers">
              <P>Where your data is processed or stored outside Kenya, we ensure that the recipient country or organisation provides an adequate level of data protection, or we apply appropriate safeguards (such as contractual clauses), consistent with Section 49 of the Data Protection Act, 2019.</P>
            </Section>

            <Section title="12. Changes to This Policy">
              <P>We may update this Privacy Policy from time to time. Where changes are material, we will notify you via the app or by email at least <strong>14 days</strong> before the changes take effect. Your continued use of the Service after the effective date constitutes acceptance of the updated Policy.</P>
            </Section>

            <Section title="13. Contact Us">
              <P>For questions, concerns, or to exercise your data rights, contact our Data Protection Officer:</P>
              <ul style={ulStyle}>
                <li><strong>Email:</strong> privacy@mymemoriestoday.site</li>
                <li><strong>Website:</strong> mymemoriestoday.site</li>
                <li><strong>Country of registration:</strong> Kenya</li>
              </ul>
              <P>You may also contact the Office of the Data Protection Commissioner (ODPC):</P>
              <ul style={ulStyle}>
                <li>Website: <a href="https://www.odpc.go.ke" target="_blank" rel="noopener noreferrer" style={{ color: "#000" }}>www.odpc.go.ke</a></li>
                <li>P.O. Box 41079 – 00100, Nairobi, Kenya</li>
              </ul>
            </Section>

          </Legal>
        </div>
      </main>

      {/* Footer */}
      <footer style={{ borderTop: "1.5px solid rgba(0,0,0,0.1)", padding: "32px 24px", textAlign: "center" }}>
        <p style={{ fontSize: "13px", color: "rgba(0,0,0,0.38)" }}>
          &copy; {new Date().getFullYear()} Memory App &nbsp;·&nbsp;{" "}
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

function SubSection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div style={{ marginTop: "8px" }}>
      <h3 style={{ fontSize: "15px", fontWeight: 700, color: "#000", marginBottom: "8px" }}>{title}</h3>
      {children}
    </div>
  );
}

function P({ children }: { children: React.ReactNode }) {
  return <p style={{ fontSize: "15px", lineHeight: 1.8, color: "rgba(0,0,0,0.65)" }}>{children}</p>;
}
