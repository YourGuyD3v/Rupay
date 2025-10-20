import {Form, MintForm} from "./utils/ui/Form";
import { erc20Abi, rupayIssuerAbi, tokens, chainsTorupayIssuer, wrapTokens } from "./utils/constant/constants";
import { useState } from "react";
import { readContract } from '@wagmi/core'
import { useAccount, useConfig, useChainId } from "wagmi";

interface Token {
  name: string;
  symbol: string;
  address: string;
}

export function RupayContent() {
  const [amountIN, setAmountIn] = useState("")
  const [amountOut, setAmountOut] = useState("")
  const [amount, setAmount] = useState("")
  const [tokenAddress, setTokenAddress] = useState("")
  const account = useAccount()
  const config = useConfig()
  const chainId = useChainId()

  async function getApprovedToken(rupIssuerAddress: string | null, tokenAddress: string): Promise<number> {
      if (!rupIssuerAddress) {
            alert("This chain only has the sa ferversion!")
            return 0
        }

        const res = await readContract(config, {
          abi: erc20Abi,
          address: tokenAddress as "0x${string}",
          functionName: 'allowance',
          args: [account.address, rupIssuerAddress as "0x${string}"]
        })

        return res as number
  }

  async function handleSubmitForMint(data: { token: Token | null; amount: string }) {
    if (data.token) {
       setTokenAddress(data.token.address)
      setAmount(data.amount)
    }
    const rupayIssuer = chainsTorupayIssuer[chainId]
    const approveTokens = await getApprovedToken(rupayIssuer.rupayIssuer as "0x${string}", tokenAddress)
    console.log("approve tokens:", approveTokens)
    // deposit eth/btc and mint wrap tokenc

  }

  async function handleSubmitForDepositAndMint(data: { token: Token | null; amount1: string; amount2: string }) {
    if (data.token) {
      setTokenAddress(data.token.address) 
      setAmountIn(data.amount1)
      setAmountOut(data.amount2)
      
      console.log("Deposit and Mint:", data)
    }
  }

  async function handleSubmitForBurnAndRedeem(data: { token: Token | null; amount1: string; amount2: string }) {
    if (data.token) {
      setTokenAddress(data.token.address) 
      setAmountIn(data.amount1)
      setAmountOut(data.amount2)
      
      console.log("Burn and Redeem:", data)
    }
  }

    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="flex flex-col gap-4">
          <MintForm 
          tokens={wrapTokens}
          onSubmit={handleSubmitForMint}
          />
            <Form
      topic="Deposit Tokens"
      description="Deposit your tokens and get RUP minted."
      buttonName="Deposit and Mint"
      submitButton="Confirm"
      amount1Label="Collateral amount"
      amount2Label="Amount to mint"
      tokens={tokens}
      onSubmit={handleSubmitForDepositAndMint}
    />
            <Form
      topic="Redeem Tokens"
      description="Burn RUP tokens and redeem Collateral."
      buttonName="Burn and Redeem"
      submitButton="Confirm"
      amount1Label="Amount to burn"
      amount2Label="Collateral amount"
      tokens={tokens}
      onSubmit={handleSubmitForBurnAndRedeem}
    />
        </div>
      </div>
    )
}