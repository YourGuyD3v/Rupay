"use client"

import { ConnectButton } from "@rainbow-me/rainbowkit"
import { FaGithub } from "react-icons/fa"
import Image from "next/image"
import Link from "next/link"

export default function Header() {
    return (
        <nav className="
            px-4 sm:px-6 md:px-8 lg:px-10
            py-3 sm:py-4 md:py-4.5
            border-b-[1px] border-zinc-100 
            flex flex-row justify-between items-center 
            bg-white 
            xl:min-h-[77px]
            gap-2 sm:gap-4
        ">
            <div className="flex items-center gap-1.5 sm:gap-2.5 md:gap-6 flex-shrink-0">
                <Link href="/" className="flex items-center gap-0.5 sm:gap-1 text-zinc-800">
                    <Image 
                        src="/logo.svg" 
                        alt="Rupay" 
                        width={70} 
                        height={70}
                        className="w-12 h-12 sm:w-14 sm:h-14 md:w-16 md:h-16 lg:w-[70px] lg:h-[70px]"
                    />
                    <h1 className="
                        font-bold 
                        text-lg sm:text-xl md:text-2xl
                        hidden xs:block
                    ">
                        Rupay
                    </h1>
                </Link>
                 <Link
                    href="https://github.com/YourGuyD3v/Rupay/tree/d90fbb5eae242cbe8d2ae604895718217ed87483"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="
                        p-1 sm:p-1.5
                        rounded-lg 
                        bg-zinc-900 hover:bg-zinc-800 
                        transition-colors 
                        border-2 border-zinc-600 hover:border-zinc-500 
                        cursor-alias
                    "
                    aria-label="View on GitHub"
                >
                    <FaGithub className="h-4 w-4 sm:h-5 sm:w-5 text-white" />
                </Link>
            </div>
            <h3 className="
                italic 
                text-sm lg:text-base
                text-zinc-500 
                hidden lg:block
                flex-grow
                text-center
                px-4
            ">
                Welcome to Rupay, stablecoin that flows flawlessly.
            </h3>
            <div className="flex items-center gap-2 sm:gap-4 flex-shrink-0">
                <ConnectButton />
            </div>
        </nav>
    )
}