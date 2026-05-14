"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

export default function ResetPasswordPage() {
  const router = useRouter();
  const supabase = createClient();
  const [hasSession, setHasSession] = useState<boolean | null>(null);
  const [password, setPassword] = useState("");
  const [password2, setPassword2] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const completedRef = useRef(false);

  // Po kliknieciu w link e-mail callback wymienia code na sesje recovery.
  // Sprawdzamy ze taka sesja istnieje.
  useEffect(() => {
    supabase.auth.getUser().then(({ data }) => setHasSession(!!data.user));
  }, [supabase]);

  // Zabezpieczenie: jezeli user opuszcza /reset-password bez zmiany hasla,
  // wylogowujemy go zeby nie mogl uzyc linku recovery jako wytrychu.
  useEffect(() => {
    const onBeforeUnload = () => {
      if (!completedRef.current) {
        // best-effort sign-out przed zamknieciem karty
        supabase.auth.signOut();
      }
    };
    window.addEventListener("beforeunload", onBeforeUnload);
    return () => {
      window.removeEventListener("beforeunload", onBeforeUnload);
      if (!completedRef.current) {
        // SPA-navigation away: wyloguj
        supabase.auth.signOut();
      }
    };
  }, [supabase]);

  const match = password === password2 && password.length >= 6;

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!match) return;
    setLoading(true); setError(null);
    const { error } = await supabase.auth.updateUser({ password });
    setLoading(false);
    if (error) { setError(error.message); return; }
    completedRef.current = true; // nie wylogowuj na unmount
    router.push("/dashboard");
    router.refresh();
  }

  if (hasSession === null) {
    return <div className="min-h-screen flex items-center justify-center text-sm text-zinc-500">Ladowanie...</div>;
  }

  if (!hasSession) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-zinc-50 dark:bg-zinc-950 p-4">
        <div className="w-full max-w-sm bg-white dark:bg-zinc-900 rounded-2xl shadow-sm border border-zinc-200 dark:border-zinc-800 p-8 text-center">
          <div className="text-3xl mb-3">⚠️</div>
          <h1 className="text-xl font-bold mb-2">Link wygasl</h1>
          <p className="text-sm text-zinc-500 mb-6">
            Link do resetu hasla jest nieprawidlowy lub stracil waznosc. Sprobuj jeszcze raz.
          </p>
          <Link href="/forgot-password" className="text-blue-500 hover:underline text-sm">Wyslij nowy link</Link>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-zinc-50 dark:bg-zinc-950 p-4">
      <div className="w-full max-w-sm bg-white dark:bg-zinc-900 rounded-2xl shadow-sm border border-zinc-200 dark:border-zinc-800 p-8">
        <div className="text-center mb-8">
          <h1 className="text-2xl font-bold">Ustaw nowe hasło</h1>
          <p className="text-sm text-zinc-500 mt-1">Po zapisaniu zostaniesz zalogowany.</p>
        </div>

        <form onSubmit={onSubmit} className="space-y-3">
          <input
            type="password" required minLength={6} autoFocus
            value={password} onChange={(e) => setPassword(e.target.value)}
            placeholder="Nowe hasło (min. 6 znaków)"
            className="w-full px-4 py-2.5 rounded-xl border border-zinc-200 dark:border-zinc-700 bg-white dark:bg-zinc-800 focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <input
            type="password" required minLength={6}
            value={password2} onChange={(e) => setPassword2(e.target.value)}
            placeholder="Powtórz hasło"
            className="w-full px-4 py-2.5 rounded-xl border border-zinc-200 dark:border-zinc-700 bg-white dark:bg-zinc-800 focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          {password2 && !match && <p className="text-sm text-red-500 text-center">Hasla nie sa identyczne lub za krotkie.</p>}
          {error && <p className="text-sm text-red-500 text-center">{error}</p>}
          <button
            type="submit" disabled={!match || loading}
            className="w-full py-3 rounded-xl bg-blue-500 hover:bg-blue-600 text-white font-medium disabled:opacity-50 transition"
          >
            {loading ? "Zapisywanie..." : "Zapisz nowe haslo"}
          </button>
        </form>
      </div>
    </div>
  );
}
