import Link from "next/link";

export default function Home() {
  return (
    <div 
      className="
        flex items-center justify-center 
        min-h-screen 
        bg-cover bg-center bg-no-repeat
        px-4 sm:px-6 lg:px-8
      " 
      style={{ backgroundImage: 'url(/homePageBG.svg)' }}
    >
      <div className="flex flex-col items-center justify-center w-full max-w-7xl mx-auto text-center space-y-6 sm:space-y-8">
        <Link 
          href="/dapp" 
          className="
            launch-button
            px-6 py-3
            sm:px-8 sm:py-4
            md:px-10 md:py-5
            lg:px-12 lg:py-6
            text-base
            sm:text-lg
            md:text-xl
            lg:text-2xl
            font-semibold
            text-white
            bg-gradient-to-r from-indigo-600 to-purple-600
            hover:from-indigo-700 hover:to-purple-700
            rounded-lg
            sm:rounded-xl
            shadow-lg
            hover:shadow-2xl
            transition-all duration-300
            transform hover:scale-105
            active:scale-95
            focus:outline-none focus:ring-4 focus:ring-indigo-300
            whitespace-nowrap
          "
        >
          Launch Dapp
        </Link>
      </div>
    </div>
  );
}