import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Terms of Service — Memory App",
  description: "Memory App Terms of Service. Read our terms and conditions governing your use of the Memory private short-video application.",
};

export default function TermsOfService() {
  const effective = "15 July 2025";

  return (
    <div style={{ background: "#F4C430", minHeight: "100vh", fontFamily: "'Inter', -apple-system, sans-serif" }}>
      {/* Nav */}
      <nav style={{ borderBottom: "1.5px solid rgba(0,0,0,0.1)", padding: "0 24px", height: "64px", display: "flex", alignItems: "center", position: "sticky", top: 0, background: "#F4C430", zIndex: 100 }}>
        <div style={{ maxWidth: "860px", width: "100%", margin: "0 auto", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <Link href="/" style={{ display: "flex", alignItems: "center", gap: "10px", textDecoration: "none", color: "#000", fontWeight: 800, fontSize: "17px", letterSpacing: "-0.4px" }}>
            <img src="/logo.png" alt="Memory" width={24} height={24} style={{ objectFit: "contain" }} />
            Memory
          </Link>
          <Link href="/" style={{ fontSize: "14px", fontWeight: 600, color: "rgba(0,0,0,0.55)", textDecoration: "none" }}>← Back to Home</Link>
        </div>
      </nav>

      {/* Content */}
      <main style={{ maxWidth: "860px", margin: "0 auto", padding: "64px 24px 100px" }}>
        {/* Header */}
        <div style={{ marginBottom: "56px" }}>
          <p style={{ fontSize: "11px", fontWeight: 700, letterSpacing: "2px", textTransform: "uppercase", opacity: 0.4, marginBottom: "12px" }}>Legal</p>
          <h1 style={{ fontSize: "clamp(36px, 6vw, 60px)", fontWeight: 900, letterSpacing: "-2px", lineHeight: 1.05, color: "#000", marginBottom: "16px" }}>
            Terms of Service
          </h1>
          <p style={{ fontSize: "15px", color: "rgba(0,0,0,0.5)", fontWeight: 500 }}>
            Effective date: {effective} &nbsp;·&nbsp; Governed by the Laws of Kenya
          </p>
        </div>

        {/* Legal doc */}
        <div style={{ background: "#fff", borderRadius: "16px", padding: "clamp(32px, 5vw, 56px)" }}>
          <Legal>

            <Section title="1. Agreement to Terms">
              <P>These Terms of Service (&ldquo;Terms&rdquo;) constitute a legally binding agreement between you (&ldquo;User&rdquo;, &ldquo;you&rdquo;) and Memory App (&ldquo;Memory&rdquo;, &ldquo;we&rdquo;, &ldquo;our&rdquo; or &ldquo;us&rdquo;), a company incorporated and operating in <strong>Kenya</strong>, governing your access to and use of the Memory mobile application and website at <strong>mymemoriestoday.site</strong> (collectively, the &ldquo;Service&rdquo;).</P>
              <P>By downloading, installing, registering for, or using the Service, you confirm that you have read, understood, and agree to be bound by these Terms and our <Link href="/privacy" style={{ color: "#000", fontWeight: 600 }}>Privacy Policy</Link>. If you do not agree, you must immediately discontinue use of the Service.</P>
              <P>These Terms are governed by and construed in accordance with the <strong>Laws of Kenya</strong>, including but not limited to the <strong>Contract Act (Cap 23)</strong>, the <strong>Consumer Protection Act, 2012</strong>, and the <strong>Computer Misuse and Cybercrimes Act, 2018</strong>.</P>
            </Section>

            <Section title="2. Eligibility">
              <P>To use the Service, you must:</P>
              <ul style={ulStyle}>
                <li>Be at least <strong>18 years of age</strong>. Persons aged 13–17 may only use the Service with verifiable parental or guardian consent, in accordance with the Kenya Data Protection Act, 2019.</li>
                <li>Have the legal capacity to enter into a binding contract under Kenyan law.</li>
                <li>Not be prohibited from using the Service under any applicable law or court order.</li>
                <li>Provide accurate, current, and complete registration information.</li>
              </ul>
              <P>By using the Service, you represent and warrant that you meet all of the above eligibility requirements.</P>
            </Section>

            <Section title="3. Account Registration">
              <P>To access the full features of Memory, you must create an account. You agree to:</P>
              <ul style={ulStyle}>
                <li>Provide truthful, accurate, and complete information during registration.</li>
                <li>Keep your login credentials confidential and not share them with third parties.</li>
                <li>Notify us immediately at <strong>support@mymemoriestoday.site</strong> if you suspect unauthorised access to your account.</li>
                <li>Be solely responsible for all activity that occurs under your account.</li>
              </ul>
              <P>We reserve the right to suspend or terminate accounts that violate these Terms or that contain false or misleading information.</P>
            </Section>

            <Section title="4. The Service — Memory Circles">
              <P>Memory is a <strong>private short-video application</strong> that enables you to record and share video content exclusively with specific groups of people you choose, called &ldquo;Circles&rdquo;. Key features include:</P>
              <ul style={ulStyle}>
                <li>Recording and uploading short video &ldquo;memories&rdquo; from your mobile device.</li>
                <li>Creating and managing private Circles comprising friends, family, or other individuals you designate.</li>
                <li>Viewing memories shared by Circle members within your designated groups.</li>
              </ul>
              <P>Memory does <strong>not</strong> provide public-facing social media features. Content shared on Memory is strictly private and accessible only to designated Circle members. We do not operate a public feed, discovery algorithm, or follower system.</P>
            </Section>

            <Section title="5. User Content">
              <SubSection title="5.1 Your Ownership">
                <P>You retain full ownership of all video content, images, and other materials you upload or share via the Service (&ldquo;User Content&rdquo;). By uploading User Content, you grant Memory a <strong>limited, non-exclusive, royalty-free, revocable licence</strong> to store, process, and transmit your User Content solely for the purpose of providing the Service to you and your Circle members.</P>
              </SubSection>
              <SubSection title="5.2 Prohibited Content">
                <P>You agree not to upload, share, or distribute any content that:</P>
                <ul style={ulStyle}>
                  <li>Is obscene, pornographic, or sexually explicit, in violation of the <strong>Sexual Offences Act, 2006</strong>.</li>
                  <li>Constitutes hate speech, incitement to violence, or discrimination based on race, ethnicity, religion, gender, disability, or sexual orientation, in violation of the <strong>National Cohesion and Integration Act, 2008</strong>.</li>
                  <li>Harasses, intimidates, threatens, or bullies any individual.</li>
                  <li>Infringes the intellectual property rights of any third party, in violation of the <strong>Copyright Act (Cap 130)</strong>.</li>
                  <li>Contains malicious code, spyware, or any material intended to disrupt, damage, or gain unauthorised access to any system, in violation of the <strong>Computer Misuse and Cybercrimes Act, 2018</strong>.</li>
                  <li>Involves the unauthorised recording or sharing of another person&apos;s image or likeness without their consent, contrary to <strong>Article 31(c) of the Constitution of Kenya, 2010</strong>.</li>
                  <li>Constitutes fraud, deception, or misrepresentation.</li>
                  <li>Violates any applicable Kenyan or international law or regulation.</li>
                </ul>
              </SubSection>
              <SubSection title="5.3 Content Moderation">
                <P>Memory reserves the right — but not the obligation — to review, remove, or disable access to User Content that violates these Terms or applicable law. We will cooperate with Kenyan law enforcement authorities in investigations of unlawful content as required by law.</P>
              </SubSection>
            </Section>

            <Section title="6. Intellectual Property">
              <P>All intellectual property rights in the Memory application, including its software, design, trademarks, logos, and content (excluding User Content) are owned by or licensed to Memory and are protected under the <strong>Kenya Industrial Property Act, 2001</strong>, the <strong>Copyright Act (Cap 130)</strong>, and applicable international treaties.</P>
              <P>You are granted a limited, non-transferable, revocable licence to use the Service for personal, non-commercial purposes only. You must not:</P>
              <ul style={ulStyle}>
                <li>Copy, modify, distribute, sell, or sublicense any part of the Service or its intellectual property.</li>
                <li>Reverse-engineer, decompile, or disassemble the Memory application.</li>
                <li>Use Memory&apos;s trademarks, logos, or brand assets without prior written consent.</li>
              </ul>
            </Section>

            <Section title="7. Privacy and Data Protection">
              <P>Your use of the Service is also governed by our <Link href="/privacy" style={{ color: "#000", fontWeight: 600 }}>Privacy Policy</Link>, which is incorporated into these Terms by reference. We process your personal data in accordance with the <strong>Kenya Data Protection Act, 2019</strong>. Please review our Privacy Policy carefully before using the Service.</P>
            </Section>

            <Section title="8. Acceptable Use Policy">
              <P>You agree to use the Service only for lawful purposes and in a manner that does not infringe the rights of others. You must not:</P>
              <ul style={ulStyle}>
                <li>Attempt to gain unauthorised access to Memory&apos;s systems or other users&apos; accounts.</li>
                <li>Use automated tools (bots, scrapers) to access or collect data from the Service.</li>
                <li>Impersonate any person or entity, or falsely claim an affiliation with any person or organisation.</li>
                <li>Interfere with or disrupt the integrity or performance of the Service.</li>
                <li>Attempt to circumvent any security or privacy feature of the Service.</li>
                <li>Use the Service to engage in commercial advertising or spam without our consent.</li>
              </ul>
            </Section>

            <Section title="9. Disclaimers and Limitation of Liability">
              <SubSection title="9.1 Service Availability">
                <P>The Service is provided on an &ldquo;as is&rdquo; and &ldquo;as available&rdquo; basis. We do not warrant that the Service will be uninterrupted, error-free, or free from viruses or harmful components.</P>
              </SubSection>
              <SubSection title="9.2 Limitation of Liability">
                <P>To the maximum extent permitted by Kenyan law, Memory and its officers, directors, employees, and agents shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising out of or in connection with your use of the Service, including but not limited to loss of data, loss of revenue, or reputational harm.</P>
                <P>Our total liability to you for any claim arising out of or relating to these Terms shall not exceed the amount paid by you, if any, to access the Service in the <strong>3 months</strong> preceding the claim.</P>
                <P>Nothing in these Terms shall exclude liability for death or personal injury caused by negligence, fraud, or any other liability that cannot be excluded under Kenyan law.</P>
              </SubSection>
            </Section>

            <Section title="10. Indemnification">
              <P>You agree to indemnify, defend, and hold harmless Memory and its affiliates, officers, directors, and employees from and against any claims, liabilities, damages, losses, and expenses (including legal fees) arising out of or in any way connected with your access to or use of the Service, your User Content, or your breach of these Terms.</P>
            </Section>

            <Section title="11. Termination">
              <P>Memory may suspend or terminate your access to the Service at any time, with or without notice, if we reasonably believe you have breached these Terms, applicable law, or pose a risk to the Service or other users.</P>
              <P>You may terminate your account at any time through the in-app settings. Upon termination, your account data will be deleted in accordance with our <Link href="/privacy" style={{ color: "#000", fontWeight: 600 }}>Privacy Policy</Link>.</P>
              <P>Provisions of these Terms that by their nature should survive termination shall survive, including Sections 5, 6, 9, 10, 12, and 13.</P>
            </Section>

            <Section title="12. Governing Law and Dispute Resolution">
              <P>These Terms shall be governed by and construed in accordance with the <strong>Laws of Kenya</strong>. Any dispute arising from or in connection with these Terms shall be subject to the exclusive jurisdiction of the <strong>courts of Kenya</strong>.</P>
              <P>Before initiating formal legal proceedings, the parties agree to attempt resolution of any dispute through good-faith negotiation for at least <strong>30 days</strong> following written notice of the dispute. If negotiation fails, disputes may be referred to mediation under the <strong>Civil Procedure Act (Cap 21)</strong> before proceeding to litigation.</P>
            </Section>

            <Section title="13. Changes to These Terms">
              <P>We reserve the right to modify these Terms at any time. Where changes are material, we will notify you via the app or email at least <strong>14 days</strong> before the changes take effect. Your continued use of the Service after the effective date of any changes constitutes your acceptance of the revised Terms.</P>
            </Section>

            <Section title="14. Contact Information">
              <P>For any questions regarding these Terms, please contact us:</P>
              <ul style={ulStyle}>
                <li><strong>Email:</strong> legal@mymemoriestoday.site</li>
                <li><strong>Website:</strong> mymemoriestoday.site</li>
                <li><strong>Country of incorporation:</strong> Kenya</li>
              </ul>
            </Section>

          </Legal>
        </div>
      </main>

      {/* Footer */}
      <footer style={{ borderTop: "1.5px solid rgba(0,0,0,0.1)", padding: "32px 24px", textAlign: "center" }}>
        <p style={{ fontSize: "13px", color: "rgba(0,0,0,0.38)" }}>
          &copy; {new Date().getFullYear()} Memory App &nbsp;·&nbsp;{" "}
          <Link href="/privacy" style={{ color: "rgba(0,0,0,0.38)", textDecoration: "underline" }}>Privacy Policy</Link>
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
