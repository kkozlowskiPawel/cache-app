"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

export default function LoginPage() {
  const router = useRouter();
  const supabase = createClient();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    setLoading(false);
    if (error) {
      setError(error.message);
      return;
    }
    router.push("/dashboard");
    router.refresh();
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-zinc-50 dark:bg-zinc-950 p-4">
      <div className="w-full max-w-sm bg-white dark:bg-zinc-900 rounded-2xl shadow-sm border border-zinc-200 dark:border-zinc-800 p-8">
        <div className="text-center mb-8">
          <div className="w-16 h-16 mx-auto rounded-2xl bg-blue-500 flex items-center justify-center mb-3">
            <svg className="w-8 h-8 text-white" fill="currentColor" viewBox="0 0 24 24"><path d="M20 4H4a2 2 0 00-2 2v12a2 2 0 002 2h16a2 2 0 002-2V6a2 2 0 00-2-2zm0 14H4v-6h16v6zm0-10H4V6h16v2z"/></svg>
          </div>
          <h1 className="text-2xl font-bold">Cache</h1>
          <p className="text-sm text-zinc-500 mt-1">Twoje finanse pod kontrolą</p>
        </div>

        <form onSubmit={onSubmit} className="space-y-3">
          <input
            type="email"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="Email"
            className="w-full px-4 py-2.5 rounded-xl border border-zinc-200 dark:border-zinc-700 bg-white dark:bg-zinc-800 focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <input
            type="password"
            required
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="Hasło"
            className="w-full px-4 py-2.5 rounded-xl border border-zinc-200 dark:border-zinc-700 bg-white dark:bg-zinc-800 focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          {error && <p className="text-sm text-red-500 text-center">{error}</p>}
          <button
            type="submit"
            disabled={loading}
            className="w-full py-3 rounded-xl bg-blue-500 hover:bg-blue-600 text-white font-medium disabled:opacity-50 transition"
          >
            {loading ? "Logowanie..." : "Zaloguj się"}
          </button>
          <div className="text-center">
            <Link
              href={email ? `/forgot-password?email=${encodeURIComponent(email)}` : "/forgot-password"}
              className="text-xs text-zinc-500 hover:text-blue-500 hover:underline"
            >
              Zapomniałeś hasła?
            </Link>
          </div>
        </form>

        <p className="text-center text-sm text-zinc-500 mt-6">
          Nie masz konta?{" "}
          <Link href="/signup" className="text-blue-500 hover:underline">Zarejestruj się</Link>
        </p>

        <div className="mt-6 pt-6 border-t border-zinc-100 dark:border-zinc-800">
          <a
            href="mailto:kkozlowski.pawel@gmail.com?subject=Cache%20iOS%20%E2%80%94%20pro%C5%9Bba%20o%20dost%C4%99p%20do%20TestFlight&body=Cze%C5%9B%C4%87%2C%20chcia%C5%82bym%20otrzyma%C4%87%20dost%C4%99p%20do%20wersji%20TestFlight%20aplikacji%20Cache%20na%20iOS.%20M%C3%B3j%20Apple%20ID%3A%20%5Bwpisz%20sw%C3%B3j%20email%5D"
            className="w-full inline-flex items-center justify-center gap-2 py-3 rounded-xl bg-zinc-900 hover:bg-zinc-800 text-white font-medium transition"
          >
            <AppleIcon />
            <span>Pobierz na iOS</span>
          </a>
          <p className="text-center text-[11px] text-zinc-400 mt-2">Wersja beta — napisz po dostęp do TestFlight</p>
        </div>
      </div>
    </div>
  );
}

function AppleIcon() {
  return (
    <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <path d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.59 9.05 7.31c1.35.07 2.29.74 3.08.8 1.18-.24 2.31-.93 3.57-.84 1.51.12 2.65.72 3.4 1.8-3.12 1.87-2.38 5.98.48 7.13-.57 1.5-1.31 2.99-2.54 4.09zM12 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z" />
    </svg>
  );
}
