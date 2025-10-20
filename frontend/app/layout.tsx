import type { Metadata } from "next";
import "./globals.css";
import { Provider } from "./providers";
import { ReactNode } from "react";

export const metadata: Metadata = {
  title: "Rupay",
  description: "Rupay is a stablecoin which flow flowless",
};

export default function RootLayout(props: {children: ReactNode}) {
  return (
    <html>
      <body>
        <Provider>
        {props.children}
        </Provider>
      </body>
      </html>
  );
}
