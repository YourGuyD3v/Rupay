import { Dialog, DialogPanel, DialogTitle, Description, Label, Combobox, ComboboxOption, Field, ComboboxInput, ComboboxOptions } from '@headlessui/react'
import { useState } from 'react'

interface Token {
  name: string
  symbol: string
  address: string
}

interface FormProps {
  topic: string
  description: string
  buttonName: string
  submitButton: string
  amount1Label: string
  amount2Label: string
  tokens: Token[]
  onSubmit?: (data: { token: Token | null; amount1: string; amount2: string }) => void
}

interface FormMintProps {
  tokens: Token[]
  onSubmit?: (data: { token: Token | null; amount: string }) => void
}

function Form({ 
  topic, 
  description, 
  buttonName, 
  submitButton, 
  amount1Label, 
  amount2Label,
  tokens,
  onSubmit
}: FormProps) {
  const [isOpen, setIsOpen] = useState(false)
  const [selectedToken, setSelectedToken] = useState<Token | null>(null)
  const [amount1, setAmount1] = useState('')
  const [amount2, setAmount2] = useState('')
  const [query, setQuery] = useState('')

  const filteredTokens = query === ''
    ? tokens
    : tokens.filter((token) => 
        token.name.toLowerCase().includes(query.toLowerCase()) ||
        token.symbol.toLowerCase().includes(query.toLowerCase())
      )

  const handleSubmit = () => {
    if (onSubmit) {
      onSubmit({ token: selectedToken, amount1, amount2 })
    }
    setIsOpen(false)
  }

  return (
    <>
      <button
        type="button"
        onClick={() => setIsOpen(true)}
        className="rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white hover:bg-indigo-500"
      >
        {buttonName}
      </button>
      
      <Dialog open={isOpen} onClose={() => setIsOpen(false)} className="relative z-50">
        <div className="fixed inset-0 bg-black/30" aria-hidden="true" />
        
        <div className="fixed inset-0 flex items-center justify-center p-4">
          <DialogPanel className="mx-auto max-w-sm rounded-lg bg-white p-6 shadow-xl">
            <DialogTitle className="text-lg font-semibold text-gray-900">
              {topic}
            </DialogTitle>
            <Description className="mt-2 text-sm text-gray-600">
              {description}
            </Description>
            
            <Field className="mt-4">
              <Label className="block text-sm font-medium text-gray-700 mb-1">Select Token</Label>
              <Combobox value={selectedToken} onChange={setSelectedToken}>
                <div className="relative">
                  <ComboboxInput
                    className="w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    displayValue={(token: Token | null) => token?.name || ''}
                    onChange={(event) => setQuery(event.target.value)}
                    placeholder="Search tokens 0x..."
                  />
                  <ComboboxOptions className="absolute z-10 mt-1 max-h-60 w-full overflow-auto rounded-md bg-white py-1 shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none">
                    {filteredTokens.length === 0 && query !== '' ? (
                      <div className="px-4 py-2 text-sm text-gray-700">No tokens found.</div>
                    ) : (
                      filteredTokens.map((token) => (
                        <ComboboxOption
                          key={token.symbol}
                          value={token}
                          className="cursor-pointer select-none px-4 py-2 hover:bg-indigo-600 hover:text-white data-[focus]:bg-indigo-600 data-[focus]:text-white"
                        >
                          <div className="flex items-center gap-2">
                            <div className="flex h-8 w-8 items-center justify-center rounded-full bg-indigo-100 text-indigo-600 text-xs font-semibold">
                              {token.symbol.slice(0, 2)}
                            </div>
                            <div>
                              <div className="font-medium">{token.name}</div>
                              <div className="text-xs opacity-75">{token.symbol}</div>
                            </div>
                          </div>
                        </ComboboxOption>
                      ))
                    )}
                  </ComboboxOptions>
                </div>
              </Combobox>
            </Field>

            <div className="mt-4">
              <label htmlFor="amount1" className="block text-sm font-medium text-gray-700">
                {amount1Label}
              </label>
              <input
                type="text"
                name="amount1"
                id="amount1"
                value={amount1}
                onChange={(e) => setAmount1(e.target.value)}
                placeholder="0.00"
                className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
              />
            </div>

            <div className="mt-4">
              <label htmlFor="amount2" className="block text-sm font-medium text-gray-700">
                {amount2Label}
              </label>
              <input
                type="text"
                name="amount2"
                id="amount2"
                value={amount2}
                onChange={(e) => setAmount2(e.target.value)}
                placeholder="0.00"
                className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
              />
            </div>
            
            <div className="mt-6 flex justify-end">
              <button
                onClick={handleSubmit}
                className="rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white hover:bg-indigo-500"
              >
                {submitButton}
              </button>
            </div>
          </DialogPanel>
        </div>
      </Dialog>
    </>
  )
}

function MintForm({ 
  tokens,
  onSubmit
}: FormMintProps) {
  const [isOpen, setIsOpen] = useState(false)
  const [selectedToken, setSelectedToken] = useState<Token | null>(null)
  const [amount, setAmount1] = useState('')
  const [query, setQuery] = useState('')

  const filteredTokens = query === ''
    ? tokens
    : tokens.filter((token) => 
        token.name.toLowerCase().includes(query.toLowerCase()) ||
        token.symbol.toLowerCase().includes(query.toLowerCase())
      )

  const handleSubmit = () => {
    if (onSubmit) {
      onSubmit({ token: selectedToken, amount})
    }
    setIsOpen(false)
  }

  return (
    <>
      <button
        type="button"
        onClick={() => setIsOpen(true)}
        className="rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white hover:bg-indigo-500"
      >
        MINT TOKENS
      </button>
      
      <Dialog open={isOpen} onClose={() => setIsOpen(false)} className="relative z-50">
        <div className="fixed inset-0 bg-black/30" aria-hidden="true" />
        
        <div className="fixed inset-0 flex items-center justify-center p-4">
          <DialogPanel className="mx-auto max-w-sm rounded-lg bg-white p-6 shadow-xl">
            <DialogTitle className="text-lg font-semibold text-gray-900">
              Mint Tokens
            </DialogTitle>
            <Description className="mt-2 text-sm text-gray-600">
              Mint Listed Tokens.
            </Description>
            
            <Field className="mt-4">
              <Label className="block text-sm font-medium text-gray-700 mb-1">Select Token</Label>
              <Combobox value={selectedToken} onChange={setSelectedToken}>
                <div className="relative">
                  <ComboboxInput
                    className="w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    displayValue={(token: Token | null) => token?.name || ''}
                    onChange={(event) => setQuery(event.target.value)}
                    placeholder="Search tokens 0x..."
                  />
                  <ComboboxOptions className="absolute z-10 mt-1 max-h-60 w-full overflow-auto rounded-md bg-white py-1 shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none">
                    {filteredTokens.length === 0 && query !== '' ? (
                      <div className="px-4 py-2 text-sm text-gray-700">No tokens found.</div>
                    ) : (
                      filteredTokens.map((token) => (
                        <ComboboxOption
                          key={token.symbol}
                          value={token}
                          className="cursor-pointer select-none px-4 py-2 hover:bg-indigo-600 hover:text-white data-[focus]:bg-indigo-600 data-[focus]:text-white"
                        >
                          <div className="flex items-center gap-2">
                            <div className="flex h-8 w-8 items-center justify-center rounded-full bg-indigo-100 text-indigo-600 text-xs font-semibold">
                              {token.symbol.slice(0, 2)}
                            </div>
                            <div>
                              <div className="font-medium">{token.name}</div>
                              <div className="text-xs opacity-75">{token.symbol}</div>
                            </div>
                          </div>
                        </ComboboxOption>
                      ))
                    )}
                  </ComboboxOptions>
                </div>
              </Combobox>
            </Field>

            <div className="mt-4">
              <label htmlFor="amount" className="block text-sm font-medium text-gray-700">
                Amount to mint
              </label>
              <input
                type="text"
                name="amount"
                id="amount"
                value={amount}
                onChange={(e) => setAmount1(e.target.value)}
                placeholder="0.00"
                className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
              />
            </div>
            
            <div className="mt-6 flex justify-end">
              <button
                onClick={handleSubmit}
                className="rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white hover:bg-indigo-500"
              >
                Confirm
              </button>
            </div>
          </DialogPanel>
        </div>
      </Dialog>
    </>
  )
}

export {Form, MintForm}