# Rupay — Frontend

Next.js frontend for the Rupay dApp. Provides UI for deposit/mint, burn/redeem, liquidation flows and wallet integration.

## Requirements
- Node.js 18+ (recommended)
- pnpm / npm / yarn
- Access to the backend (local anvil / Sepolia RPC) and contract addresses

## Setup

1. Install dependencies
```bash
# pnpm
pnpm install

# npm
npm install

# yarn
yarn
```

2. Copy environment template and set values
```bash
cp .env.local.example .env.local  # if an example exists
# or create .env.local with your values
```
Set at minimum:
- NEXT_PUBLIC_RPC_URL (RPC endpoint or local anvil)
- NEXT_PUBLIC_RUP_ISSUER_ADDRESS (deployed RupayIssuer)
- NEXT_PUBLIC_RUP_ADDRESS (RUP token)
- any wallet or analytics keys

Example .env.local
```env
NEXT_PUBLIC_RPC_URL=https://rpc.sepolia.org/<KEY>
NEXT_PUBLIC_RUP_ISSUER_ADDRESS=0xYourRupayIssuerAddress
NEXT_PUBLIC_RUP_ADDRESS=0xYourRupAddress
```

## Local development

Start the dev server:
```bash
pnpm dev
# or
npm run dev
# or
yarn dev
```
Open http://localhost:3000

## Build & production

Build:
```bash
pnpm build
# or
npm run build
# or
yarn build
```

Start production:
```bash
pnpm start
# or
npm start
# or
yarn start
```

Deploy: Vercel is recommended for Next.js — connect the repo and set the same environment variables in the project settings.

## Useful scripts (package.json)
- dev — start Next.js dev server
- build — compile for production
- start — start compiled app
- lint — run ESLint (if configured)
- format — run Prettier (if configured)
- test — run tests (if present)

Run via:
```bash
pnpm run <script>
```

## App structure (important files)
- app/ — Next.js app routes and UI
  - app/page.tsx — main pages
  - app/dapp/page.tsx — dApp entry
- app/components/
  - DappContent.tsx — wallet + RPC-aware UI
  - RupayContent.tsx — forms for mint/deposit/burn/liquidate
  - Header.tsx — top navigation
- providers.tsx / rainbowKitConfig.tsx — wallet + Wagmi / RainbowKit setup
- public/ — static assets
- globals.css — global styles

## Working with the backend
- For local testing, run the backend anvil/foundry scripts then point NEXT_PUBLIC_RPC_URL to the local node and set contract addresses from your deployment output.
- For Sepolia, use your RPC provider and the deployed contract addresses.

## Troubleshooting
- If wallet/connect fails: confirm RPC URL, chain id and contract addresses in .env.local.
- Common dev issues on WSL: restart the WSL distro, reload VS Code window, ensure file watchers are not exhausted (increase inotify limits).
- If static assets or environment variables are not picked up, restart the dev server after editing .env.local.

## Contributing
- Add UI tests and update components under app/components.
- Keep contract ABI interactions aligned with backend contract changes.
- Run linter and format before PR.

## License
MIT
```// filepath: /home/yourguydev/on-chain-portfolio/rupay/frontend/README.md
# Rupay — Frontend

Next.js frontend for the Rupay dApp. Provides UI for deposit/mint, burn/redeem, liquidation flows and wallet integration.

## Requirements
- Node.js 18+ (recommended)
- pnpm / npm / yarn
- Access to the backend (local anvil / Sepolia RPC) and contract addresses

## Setup

1. Install dependencies
```bash
# pnpm
pnpm install

# npm
npm install

# yarn
yarn
```

2. Copy environment template and set values
```bash
cp .env.local.example .env.local  # if an example exists
# or create .env.local with your values
```

Example .env.local
```env
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID
```

## Local development

Start the dev server:
```bash
pnpm dev
# or
npm run dev
# or
yarn dev
```
Open http://localhost:3000

## Build & production

Build:
```bash
pnpm build
# or
npm run build
# or
yarn build
```

Start production:
```bash
pnpm start
# or
npm start
# or
yarn start
```

Deploy: Vercel is recommended for Next.js — connect the repo and set the same environment variables in the project settings.

## Useful scripts (package.json)
- dev — start Next.js dev server
- build — compile for production
- start — start compiled app
- lint — run ESLint (if configured)
- format — run Prettier (if configured)
- test — run tests (if present)

Run via:
```bash
pnpm run <script>
```

## App structure (important files)
- app/ — Next.js app routes and UI
  - app/page.tsx — main pages
  - app/dapp/page.tsx — dApp entry
- app/components/
  - DappContent.tsx — wallet + RPC-aware UI
  - RupayContent.tsx — forms for mint/deposit/burn/liquidate
  - Header.tsx — top navigation
- providers.tsx / rainbowKitConfig.tsx — wallet + Wagmi / RainbowKit setup
- public/ — static assets
- globals.css — global styles

## License
MIT