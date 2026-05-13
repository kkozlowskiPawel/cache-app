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
      <div className="p-3 border-t border-zinc-200 dark:border-zinc-800">
        <button onClick={signOut} className="w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm text-red-500 hover:bg-red-50 dark:hover:bg-red-950/30 transition">
          <LogOut className="w-4 h-4" />
          Wyloguj się
        </button>
      </div>
    </aside>
  );
}
