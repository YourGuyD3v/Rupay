"use client"

import {useAccount} from "wagmi"
import Image from "next/image"
import { RupayContent } from "./RupayContent"

export function DappContent() {
    const { isConnected } = useAccount()
    return (
        <main>

            {!isConnected ? (
                <div className="flex flex-col items-center justify-center min-h-screen gap-6">
                    <h2 className="text-xl font-medium text-zinc-600">
                        Please, connect your wallet...
                    </h2>
                    <Image src="/waiting.svg" alt="Waiting" width={600} height={600} />
                </div>
            ) : (
                <RupayContent />
            )}
            
        </main>
    )
}