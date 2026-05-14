"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import {
  LayoutDashboard, ListChecks, Repeat, PieChart, Target, FileText, Settings, LogOut,
} from "lucide-react";

const nav = [
  { href: "/dashboard",     label: "Dashboard",   icon: LayoutDashboard },
  { href: "/transactions",  label: "Wydatki",     icon: ListChecks },
  { href: "/subscriptions", label: "Subskrypcje", icon: Repeat },
  { href: "/budget",        label: "Budżet",      icon: PieChart },
  { href: "/goals",         label: "Cele",        icon: Target },
  { href: "/bills",         label: "Rachunki",    icon: FileText },
  { href: "/settings",      label: "Ustawienia",  icon: Settings },
];

function AppleIcon() {
  return (
    <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <path d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.59 9.05 7.31c1.35.07 2.29.74 3.08.8 1.18-.24 2.31-.93 3.57-.84 1.51.12 2.65.72 3.4 1.8-3.12 1.87-2.38 5.98.48 7.13-.57 1.5-1.31 2.99-2.54 4.09zM12 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z" />
    </svg>
  );
}

export default function Sidebar({ email }: { email: string }) {
  const pathname = usePathname();
  const router = useRouter();

  async function signOut() {
    const supabase = createClient();
    await supabase.auth.signOut();
    router.push("/login");
    router.refresh();
  }

  return (
    <aside className="w-64 border-r border-zinc-200 dark:border-zinc-800 bg-white dark:bg-zinc-900 flex flex-col">
      <div className="p-6 border-b border-zinc-200 dark:border-zinc-800">
        <div className="flex items-center gap-2">
          <div className="w-9 h-9 rounded-lg bg-blue-500 flex items-center justify-center text-white font-bold">C</div>
          <div>
            <div className="font-bold">Cache</div>
            <div className="text-xs text-zinc-500 truncate max-w-[160px]">{email}</div>
          </div>
        </div>
      </div>
      <nav className="flex-1 p-3 space-y-1">
        {nav.map((item) => {
          const Icon = item.icon;
          const active = pathname === item.href;
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition ${
                active
                  ? "bg-blue-50 dark:bg-blue-950/40 text-blue-600 dark:text-blue-400 font-medium"
                  : "hover:bg-zinc-100 dark:hover:bg-zinc-800"
              }`}
            >
              <Icon className="w-4 h-4" />
              <span>{item.label}</span>
            </Link>
          );
        })}
      </nav>
      <div className="p-3 border-t border-zinc-200 dark:border-zinc-800 space-y-1">
        <a
          href="mailto:kkozlowski.pawel@gmail.com?subject=Cache%20iOS%20%E2%80%94%20pro%C5%9Bba%20o%20dost%C4%99p%20do%20TestFlight&body=Cze%C5%9B%C4%87%2C%20chcia%C5%82bym%20otrzyma%C4%87%20dost%C4%99p%20do%20wersji%20TestFlight%20aplikacji%20Cache%20na%20iOS.%20M%C3%B3j%20Apple%20ID%3A%20%5Bwpisz%20sw%C3%B3j%20email%5D"
          className="w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm bg-zinc-900 hover:bg-zinc-800 text-white transition"
        >
          <AppleIcon />
          Pobierz na iOS
        </a>
        <button onClick={signOut} className="w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm text-red-500 hover:bg-red-50 dark:hover:bg-red-950/30 transition">
          <LogOut className="w-4 h-4" />
          Wyloguj się
        </button>
      </div>
    </aside>
  );
}
