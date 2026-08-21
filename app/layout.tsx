import type { Metadata } from "next";
import { Poppins } from "next/font/google";
import "./globals.css";

const poppins = Poppins({
  weight: ["400", "500", "600", "700", "800"],
  subsets: ["latin", "latin-ext"],
  variable: "--font-poppins",
  display: "swap",
});

export const metadata: Metadata = {
  title: "RADAR · Defensa institucional en el entorno digital",
  description:
    "Identificación, diagnóstico y respuesta coordinada ante desinformación, campañas coordinadas y hostigamiento digital. Municipalidad de San Miguel de Tucumán.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="es-AR">
      <body className={`${poppins.variable} font-sans`}>{children}</body>
    </html>
  );
}
