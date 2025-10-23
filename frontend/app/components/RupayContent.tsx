import {Form, MintForm, LiquidateForm} from "./utils/ui/Form";
import { erc20Abi, rupayIssuerAbi, chainsTorupayIssuer, wrapTokens, rup, rupayERC20Abi } from "./utils/constant/constants";
import { useState, useEffect } from "react";
import { readContract, waitForTransactionReceipt  } from '@wagmi/core'
import { useAccount, useConfig, useChainId, useWriteContract } from "wagmi";

interface Token {
  name: string;
  symbol: string;
  address: string;
}

interface TransactionAlert {
  type: 'mint' | 'deposit' | 'burn' | 'liquidate';
  token: Token;
  amount?: string;
  amountIn?: string;
  amountOut?: string;
  userAddress?: string;
  status: 'processing' | 'success' | 'failed';
  hash?: string;
  error?: string;
}

export function RupayContent() {
  // Shared state for all forms
  const [selectedToken, setSelectedToken] = useState<Token | null>(null)
  const [amount, setAmount] = useState("")
  const [amountIn, setAmountIn] = useState("")
  const [amountOut, setAmountOut] = useState("")
  const [transactionAlert, setTransactionAlert] = useState<TransactionAlert | null>(null)
  const { data: hash, isPending, error, writeContractAsync } = useWriteContract()
  
  const account = useAccount()
  const config = useConfig()
  const chainId = useChainId()

  // Auto-dismiss alert after 3 seconds for success/failed status
  useEffect(() => {
    if (transactionAlert && (transactionAlert.status === 'success' || transactionAlert.status === 'failed')) {
      const timer = setTimeout(() => {
        setTransactionAlert(null)
      }, 3000)

      return () => clearTimeout(timer)
    }
  }, [transactionAlert])

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
    setTransactionAlert({
      type: 'mint',
      token: data.token,
      amount: data.amount.toString(),
      status: 'processing'
    })

    try {
      const rupayIssuer = chainsTorupayIssuer[chainId]
      
      const approvalHash = await writeContractAsync({
        abi: erc20Abi,
        address: data.token.address as `0x${string}`,
        functionName: 'deposit',
        value: BigInt(data.amount),
      })

      const receipt = await waitForTransactionReceipt(config, { hash: approvalHash })
      
      console.log("Mint transaction hash:", approvalHash)
      
      setTransactionAlert({
        type: 'mint',
        token: data.token,
        amount: data.amount.toString(),
        status: 'success',
        hash: approvalHash
      })
    } catch (err) {
      console.error("Mint failed:", err)
      setTransactionAlert({
        type: 'mint',
        token: data.token,
        amount: data.amount.toString(),
        status: 'failed',
        error: err instanceof Error ? err.message : 'Transaction failed'
      })
    }
  }

  async function handleSubmitForDepositAndMint(data: { token: Token | null; amount1: number; amount2: number }) {
    if (!data.token) return

    setSelectedToken(data.token)
    setAmountIn(data.amount1.toString())
    setAmountOut(data.amount2.toString())
    setTransactionAlert({
      type: 'deposit',
      token: data.token,
      amountIn: data.amount1.toString(),
      amountOut: data.amount2.toString(),
      status: 'processing'
    })

    try {
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

      const receipt = await waitForTransactionReceipt(config, { hash: depositHash })
      
      console.log("Deposit and Mint transaction hash:", depositHash)
      
      setTransactionAlert({
        type: 'deposit',
        token: data.token,
        amountIn: data.amount1.toString(),
        amountOut: data.amount2.toString(),
        status: 'success',
        hash: depositHash
      })
    } catch (err) {
      console.error("Deposit and Mint failed:", err)
      setTransactionAlert({
        type: 'deposit',
        token: data.token,
        amountIn: data.amount1.toString(),
        amountOut: data.amount2.toString(),
        status: 'failed',
        error: err instanceof Error ? err.message : 'Transaction failed'
      })
    }
  }

  async function handleSubmitForBurnAndRedeem(data: { token: Token | null; amount1: number; amount2: number }) {
    if (!data.token) return
    
    setSelectedToken(data.token)
    setAmountIn(data.amount1.toString())
    setAmountOut(data.amount2.toString())
    setTransactionAlert({
      type: 'burn',
      token: data.token,
      amountIn: data.amount1.toString(),
      amountOut: data.amount2.toString(),
      status: 'processing'
    })

    try {
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

      const receipt = await waitForTransactionReceipt(config, { hash: depositHash })
      
      console.log("Burn and Redeem transaction hash:", depositHash)
      
      setTransactionAlert({
        type: 'burn',
        token: data.token,
        amountIn: data.amount1.toString(),
        amountOut: data.amount2.toString(),
        status: 'success',
        hash: depositHash
      })
    } catch (err) {
      console.error("Burn and Redeem failed:", err)
      setTransactionAlert({
        type: 'burn',
        token: data.token,
        amountIn: data.amount1.toString(),
        amountOut: data.amount2.toString(),
        status: 'failed',
        error: err instanceof Error ? err.message : 'Transaction failed'
      })
    }
  }

  async function handleSubmitForLiquidate(data: { token: Token | null; userAddress: string; amount: number }) {
    if (!data.token) return
    
    setSelectedToken(data.token)
    setAmountOut(data.amount.toString())
    setTransactionAlert({
      type: 'liquidate',
      token: data.token,
      userAddress: data.userAddress,
      amountOut: data.amount.toString(),
      status: 'processing'
    })

    try {
      const rupayIssuer = chainsTorupayIssuer[chainId]
      const approveTokens = await getApprovedToken(rupayIssuer.rupayIssuer, rup)
      
      if (approveTokens < BigInt(data.amount)) {
        const approvalHash = await writeContractAsync({
          abi: erc20Abi,
          address: rup as `0x${string}`,
          functionName: 'approve',
          args: [rupayIssuer.rupayIssuer as `0x${string}`, BigInt(data.amount)],
        })
        const approvalReceipt = await waitForTransactionReceipt(config, { hash: approvalHash })
        console.log("Approval transaction receipt:", approvalReceipt)
      }

      const liquidateHash = await writeContractAsync({
        abi: rupayIssuerAbi,
        address: rupayIssuer.rupayIssuer as `0x${string}`,
        functionName: 'liquidate',
        args: [data.userAddress as `0x${string}`, BigInt(data.amount), data.token.address as `0x${string}`],
      })

      const receipt = await waitForTransactionReceipt(config, { hash: liquidateHash })
      
      console.log("Liquidate transaction hash:", liquidateHash)
      
      // Simulate success for now
      setTimeout(() => {
        setTransactionAlert({
          type: 'liquidate',
          token: data.token,
          userAddress: data.userAddress,
          amountOut: data.amount.toString(),
          status: 'success'
        })
      }, 2000)
    } catch (err) {
      console.error("Liquidate failed:", err)
      setTransactionAlert({
        type: 'liquidate',
        token: data.token,
        userAddress: data.userAddress,
        amountOut: data.amount.toString(),
        status: 'failed',
        error: err instanceof Error ? err.message : 'Transaction failed'
      })
    }
  }

  const getAlertContent = () => {
    if (!transactionAlert) return null

    const titles = {
      mint: 'Mint Transaction',
      deposit: 'Deposit & Mint',
      burn: 'Burn & Redeem',
      liquidate: 'Liquidation'
    }

    const statusConfig = {
      processing: {
        color: 'from-blue-600 to-indigo-600',
        icon: (
          <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
        ),
        text: 'Processing...',
        textColor: 'text-blue-600'
      },
      success: {
        color: 'from-green-600 to-emerald-600',
        icon: (
          <svg className="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
          </svg>
        ),
        text: 'Success!',
        textColor: 'text-green-600'
      },
      failed: {
        color: 'from-red-600 to-rose-600',
        icon: (
          <svg className="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
          </svg>
        ),
        text: 'Failed',
        textColor: 'text-red-600'
      }
    }

    const currentStatus = statusConfig[transactionAlert.status]

    return (
      <div className="fixed bottom-6 right-6 w-96 bg-white rounded-xl shadow-2xl border border-gray-200 overflow-hidden animate-slide-in z-50">
        <div className={`bg-gradient-to-r ${currentStatus.color} px-6 py-4 flex items-center justify-between`}>
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-white rounded-full flex items-center justify-center">
              <img src="/logo.svg" alt="Rupay" className="w-8 h-8" />
            </div>
            <div>
              <h3 className="text-white font-semibold text-lg">{titles[transactionAlert.type]}</h3>
              <p className="text-white/90 text-xs flex items-center gap-2">
                {currentStatus.icon}
                <span>{currentStatus.text}</span>
              </p>
            </div>
          </div>
          <button 
            onClick={() => setTransactionAlert(null)}
            className="text-white hover:text-white/80 transition-colors"
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        {/* Content */}
        <div className="p-6 space-y-3">
          <div className="flex items-center justify-between py-2 border-b border-gray-100">
            <span className="text-gray-600 text-sm font-medium">Token</span>
            <span className="text-gray-900 font-semibold">{transactionAlert.token.symbol}</span>
          </div>

          {transactionAlert.amount && (
            <div className="flex items-center justify-between py-2 border-b border-gray-100">
              <span className="text-gray-600 text-sm font-medium">Amount</span>
              <span className="text-gray-900 font-semibold">{transactionAlert.amount}</span>
            </div>
          )}

          {transactionAlert.amountIn && (
            <div className="flex items-center justify-between py-2 border-b border-gray-100">
              <span className="text-gray-600 text-sm font-medium">
                {transactionAlert.type === 'deposit' ? 'Collateral' : 'Burn Amount'}
              </span>
              <span className="text-gray-900 font-semibold">{transactionAlert.amountIn}</span>
            </div>
          )}

          {transactionAlert.amountOut && (
            <div className="flex items-center justify-between py-2 border-b border-gray-100">
              <span className="text-gray-600 text-sm font-medium">
                {transactionAlert.type === 'deposit' ? 'Mint Amount' : transactionAlert.type === 'burn' ? 'Redeem Amount' : 'Debt to Cover'}
              </span>
              <span className="text-gray-900 font-semibold">{transactionAlert.amountOut}</span>
            </div>
          )}

          {transactionAlert.userAddress && (
            <div className="flex items-center justify-between py-2 border-b border-gray-100">
              <span className="text-gray-600 text-sm font-medium">User Address</span>
              <span className="text-gray-900 font-mono text-xs">
                {transactionAlert.userAddress.slice(0, 6)}...{transactionAlert.userAddress.slice(-4)}
              </span>
            </div>
          )}

          {transactionAlert.hash && transactionAlert.status === 'success' && (
            <div className="flex items-center justify-between py-2 border-b border-gray-100">
              <span className="text-gray-600 text-sm font-medium">Tx Hash</span>
              <span className="text-gray-900 font-mono text-xs">
                {transactionAlert.hash.slice(0, 6)}...{transactionAlert.hash.slice(-4)}
              </span>
            </div>
          )}

          {transactionAlert.error && transactionAlert.status === 'failed' && (
            <div className="py-2">
              <span className="text-red-600 text-xs">{transactionAlert.error}</span>
            </div>
          )}

          {/* Status indicator with progress bar for auto-dismiss */}
          {(transactionAlert.status === 'success' || transactionAlert.status === 'failed') && (
            <div className="pt-2">
              <div className="w-full h-1 bg-gray-200 rounded-full overflow-hidden">
                <div className={`h-full ${currentStatus.textColor.replace('text', 'bg')} animate-shrink`}></div>
              </div>
            </div>
          )}
        </div>
      </div>
    )
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

        <LiquidateForm
          topic="Liquidate Position"
          description="Liquidate undercollateralized positions."
          buttonName="Liquidate"
          submitButton="Confirm"
          userAddressLabel="User Address"
          amountLabel="Debt to cover"
          tokens={wrapTokens}
          onSubmit={handleSubmitForLiquidate}
        />
      </div>

      {/* Dynamic Alert */}
      {getAlertContent()}

      <style jsx>{`
        @keyframes slide-in {
          from {
            transform: translateX(100%);
            opacity: 0;
          }
          to {
            transform: translateX(0);
            opacity: 1;
          }
        }
        @keyframes shrink {
          from {
            width: 100%;
          }
          to {
            width: 0%;
          }
        }
        .animate-slide-in {
          animation: slide-in 0.3s ease-out;
        }
        .animate-shrink {
          animation: shrink 3s linear;
        }
      `}</style>
    </div>
  )
}