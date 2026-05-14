"use client";

import { useState } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

export default function ForgotPasswordPage() {
  const supabase = createClient();
  const [email, setEmail] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [sent, setSent] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true); setError(null);

    const redirectTo = typeof window !== "undefined"
      ? `${window.location.origin}/auth/callback?next=/reset-password`
      : undefined;

    const { error } = await supabase.auth.resetPasswordForEmail(email, { redirectTo });
    setLoading(false);

    if (error) { setError(error.message); return; }
    setSent(true);
  }

  if (sent) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-zinc-50 dark:bg-zinc-950 p-4">
        <div className="w-full max-w-sm bg-white dark:bg-zinc-900 rounded-2xl shadow-sm border border-zinc-200 dark:border-zinc-800 p-8 text-center">
          <div className="w-16 h-16 mx-auto rounded-full bg-blue-100 dark:bg-blue-950/40 flex items-center justify-center mb-4 text-3xl">📩</div>
          <h1 className="text-xl font-bold mb-2">Sprawdź skrzynkę</h1>
          <p className="text-sm text-zinc-500 mb-6">
            Jeśli istnieje konto powiązane z <strong>{email}</strong>, wysłaliśmy link do zresetowania hasła.
          </p>
          <Link href="/login" className="text-blue-500 hover:underline text-sm">Wróć do logowania</Link>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-zinc-50 dark:bg-zinc-950 p-4">
      <div className="w-full max-w-sm bg-white dark:bg-zinc-900 rounded-2xl shadow-sm border border-zinc-200 dark:border-zinc-800 p-8">
        <div className="text-center mb-8">
          <h1 className="text-2xl font-bold">Zapomniałeś hasła?</h1>
          <p className="text-sm text-zinc-500 mt-1">Wyślemy link do zresetowania na Twój adres e-mail.</p>
        </div>

        <form onSubmit={onSubmit} className="space-y-3">
          <input
            type="email" required autoFocus
            value={email} onChange={(e) => setEmail(e.target.value)}
            placeholder="Email"
            className="w-full px-4 py-2.5 rounded-xl border border-zinc-200 dark:border-zinc-700 bg-white dark:bg-zinc-800 focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          {error && <p className="text-sm text-red-500 text-center">{error}</p>}
          <button
            type="submit" disabled={loading}
            className="w-full py-3 rounded-xl bg-blue-500 hover:bg-blue-600 text-white font-medium disabled:opacity-50 transition"
          >
            {loading ? "Wysyłanie..." : "Wyślij link"}
          </button>
        </form>

        <p className="text-center text-sm text-zinc-500 mt-6">
          <Link href="/login" className="text-blue-500 hover:underline">Wróć do logowania</Link>
        </p>
      </div>
    </div>
  );
}
