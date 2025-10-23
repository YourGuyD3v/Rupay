import {Form, MintForm} from "./utils/ui/Form";
import { erc20Abi, rupayIssuerAbi, chainsTorupayIssuer, wrapTokens, rup, rupayERC20Abi } from "./utils/constant/constants";
import { useState } from "react";
import { readContract, waitForTransactionReceipt  } from '@wagmi/core'
import { useAccount, useConfig, useChainId, useWriteContract } from "wagmi";

interface Token {
  name: string;
  symbol: string;
  address: string;
}

export function RupayContent() {
  // Shared state for all forms
  const [selectedToken, setSelectedToken] = useState<Token | null>(null)
  const [amount, setAmount] = useState("")
  const [amountIn, setAmountIn] = useState("")
  const [amountOut, setAmountOut] = useState("")
      const { data: hash, isPending, error, writeContractAsync } = useWriteContract()
  
  const account = useAccount()
  const config = useConfig()
  const chainId = useChainId()

  async function getApprovedToken(
    rupIssuerAddress: string | null, 
    tokenAddress: string
  ): Promise<number> {
    if (!rupIssuerAddress) {
      alert("This chain only has the safe version!")
      return 0
    }
    const res = await readContract(config, {
      abi: erc20Abi,
      address: tokenAddress as `0x${string}`,
      functionName: 'allowance',
      args: [account.address, rupIssuerAddress as `0x${string}`]
    })
    return res as number
  }

  async function handleSubmitForMint(data: { token: Token | null; amount: number }) {
    if (!data.token) return
    
    setSelectedToken(data.token)
    setAmount(data.amount.toString())

    const rupayIssuer = chainsTorupayIssuer[chainId]
    
    const approvalHash = await writeContractAsync({
      abi: erc20Abi,
      address: data.token.address as `0x${string}`,
      functionName: 'deposit',
       value: BigInt(data.amount),
    })

    console.log("Mint transaction hash:", approvalHash)
  }

  async function handleSubmitForDepositAndMint(data: { token: Token | null; amount1: number; amount2: number }) {
    if (!data.token) return

    setSelectedToken(data.token)
    setAmountIn(data.amount1.toString())
    setAmountOut(data.amount2.toString())

    const rupayIssuer = chainsTorupayIssuer[chainId]
    const approveTokens = await getApprovedToken(rupayIssuer.rupayIssuer, data.token.address)
    
    if (approveTokens < BigInt(data.amount1)) {
      const approvalHash = await writeContractAsync({
      abi: erc20Abi,
      address: data.token.address as `0x${string}`,
      functionName: 'approve',
      args: [rupayIssuer.rupayIssuer as `0x${string}`, BigInt(data.amount1)],
    })
    const approvalReceipt = await waitForTransactionReceipt(config, { hash: approvalHash })
    console.log("Approval transaction receipt:", approvalReceipt)
    }

    const depositHash = await writeContractAsync({
      abi: rupayIssuerAbi,
      address: rupayIssuer.rupayIssuer as `0x${string}`,
      functionName: 'depositAndMint',
      args: [data.token.address as `0x${string}`, BigInt(data.amount1), BigInt(data.amount2)],
    })

    console.log("Deposit and Mint transaction hash:", depositHash)
  }

  async function handleSubmitForBurnAndRedeem(data: { token: Token | null; amount1: number; amount2: number }) {
    if (!data.token) return
    
    setSelectedToken(data.token)
    setAmountIn(data.amount1.toString())
    setAmountOut(data.amount2.toString())

    const rupayIssuer = chainsTorupayIssuer[chainId]
    const approveTokens = await getApprovedToken(rupayIssuer.rupayIssuer, rup)
    
    if (approveTokens < BigInt(data.amount1)) {
      const approvalHash = await writeContractAsync({
      abi: erc20Abi,
      address: rup as `0x${string}`,
      functionName: 'approve',
      args: [rupayIssuer.rupayIssuer as `0x${string}`, BigInt(data.amount1)],
    })
    const approvalReceipt = await waitForTransactionReceipt(config, { hash: approvalHash })
    console.log("Approval transaction receipt:", approvalReceipt)
    }

    const depositHash = await writeContractAsync({
      abi: rupayIssuerAbi,
      address: rupayIssuer.rupayIssuer as `0x${string}`,
      functionName: 'redeem',
      args: [data.token.address as `0x${string}`, BigInt(data.amount1), BigInt(data.amount2)],
    })

    console.log("Burn and Redeem transaction hash:", depositHash)
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
          tokens={wrapTokens}
          onSubmit={handleSubmitForDepositAndMint}
        />
        <Form
          topic="Redeem Tokens"
          description="Burn RUP tokens and redeem Collateral."
          buttonName="Burn and Redeem"
          submitButton="Confirm"
          amount1Label="Amount to burn"
          amount2Label="Collateral amount"
          tokens={wrapTokens}
          onSubmit={handleSubmitForBurnAndRedeem}
        />
        
        {/* Display selected values */}
        {selectedToken && (
          <div className="mt-4 p-4 bg-gray-100 rounded">
            <p>Selected Token: {selectedToken.name}</p>
            <p>Amount: {amount || amountIn}</p>
            {amountOut && <p>Amount Out: {amountOut}</p>}
          </div>
        )}
      </div>
    </div>
  )
}