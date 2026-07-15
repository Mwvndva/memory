import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  display: "swap",
});

export const metadata: Metadata = {
  title: "Memory — Share memories with your Circle",
  description: "Memory is a private short-video app where life's best moments stay with the people who actually experienced them. Share only with those who matter.",
  metadataBase: new URL("https://mymemoriestoday.site"),
  openGraph: {
    title: "Memory — Share memories with your Circle",
    description: "Memory is a private short-video app. Share life's best moments only with the people who were actually there.",
    url: "https://mymemoriestoday.site",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={inter.className}>
      <body>{children}</body>
    </html>
  );
}
