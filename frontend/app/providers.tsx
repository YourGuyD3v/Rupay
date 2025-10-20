"use client"

import { ReactNode, useState } from "react";
import { WagmiProvider } from "wagmi";
import config from "./rainbowKitConfig"
import { QueryClient, QueryClientProvider } from "@tanstack/react-query"
import { RainbowKitProvider } from "@rainbow-me/rainbowkit";
import "@rainbow-me/rainbowkit/styles.css"

export function Provider(props: {children: ReactNode}) {
    const [queryClient] = useState(() => new QueryClient())

    return (
        <WagmiProvider config={config}>
            <QueryClientProvider client={queryClient}>
                <RainbowKitProvider>
                    {props.children}
                </RainbowKitProvider>
            </QueryClientProvider>

        </WagmiProvider>
    )
}