import Link from "next/link";

export default function Home() {
  return (
    <div className="flex items-center justify-center min-h-screen bg-cover bg-center bg-no-repeat" style={{ backgroundImage: 'url(/homePageBG.svg)' }}>
        <div className="flex min-h-screen items-center justify-center">
      <Link 
        href="/dapp" 
        className="launch-button"
      >
        Launch Dapp
      </Link>
    </div>
    </div>
  );
}