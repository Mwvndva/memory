import type { Metadata, Viewport } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  display: "swap",
});

export const viewport: Viewport = {
  themeColor: "#F4C430",
};

export const metadata: Metadata = {
  title: "Memory — Share memories with your Circle",
  description:
    "Memory is a private short-video app where life's best moments stay with the people who actually experienced them. Share only with those who matter.",
  metadataBase: new URL("https://mymemoriestoday.site"),
  openGraph: {
    title: "Memory — Share memories with your Circle",
    description:
      "Memory is a private short-video app. Share life's best moments only with the people who were actually there.",
    url: "https://mymemoriestoday.site",
    type: "website",
  },
  icons: {
    icon: [
      { url: "/favicon-16x16.png", sizes: "16x16", type: "image/png" },
      { url: "/favicon-32x32.png", sizes: "32x32", type: "image/png" },
      { url: "/favicon.ico" },
    ],
    apple: [{ url: "/apple-touch-icon.png" }],
    other: [
      { rel: "manifest", url: "/site.webmanifest" },
    ],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={inter.className}>
      <head>
        <link rel="icon" type="image/x-icon" href="/favicon.ico" />
        <link rel="icon" type="image/png" sizes="16x16" href="/favicon-16x16.png" />
        <link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png" />
        <link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png" />
        <link rel="manifest" href="/site.webmanifest" />
        <meta name="theme-color" content="#F4C430" />
      </head>
      <body>{children}</body>
    </html>
  );
}
