import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Voice Chat App",
  description: "Voice Chat Application with Real-time Transcription",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="pt">
      <body className="antialiased">
        {children}
      </body>
    </html>
  );
}
