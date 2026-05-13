"use client";

import { useData } from "@/lib/data-context";
import { formatCurrency, formatDate } from "@/lib/format";
import { ArrowDownCircle, ArrowUpCircle, Banknote, Wallet, Calendar } from "lucide-react";
import { BarChart, Bar, XAxis, YAxis, ResponsiveContainer, Tooltip, Cell } from "recharts";
import Link from "next/link";

export default function DashboardPage() {
  const d = useData();
  const savings = d.monthlyIncome - d.monthlyExpenses;

  const byCategory = Object.entries(
    d.transactions
      .filter((t) => t.amount < 0)
      .reduce<Record<string, number>>((acc, t) => {
        if (!t.category_id) return acc;
        acc[t.category_id] = (acc[t.category_id] ?? 0) + Math.abs(t.amount);
        return acc;
      }, {})
  )
    .map(([cid, total]) => {
      const c = d.categoryById(cid);
      return { name: c?.name ?? "—", value: total, color: c?.color ?? "#8E8E93" };
    })
    .sort((a, b) => b.value - a.value)
    .slice(0, 6);

  const upcomingBills = d.bills.filter((b) => !b.paid && new Date(b.due_date) >= new Date(new Date().toDateString())).slice(0, 5);

  return (
    <div className="p-8 space-y-6 max-w-5xl">
      <h1 className="text-3xl font-bold">Dashboard</h1>

      <section className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Stat icon={<ArrowDownCircle className="w-5 h-5" />} label="Przychód" value={d.monthlyIncome} color="green" />
        <Stat icon={<ArrowUpCircle className="w-5 h-5" />} label="Wydatki" value={d.monthlyExpenses} color="red" />
        <Stat icon={<Banknote className="w-5 h-5" />} label="Oszczędności" value={savings} color={savings >= 0 ? "blue" : "orange"} />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="bg-white dark:bg-zinc-900 rounded-2xl border border-zinc-200 dark:border-zinc-800 p-5">
          <div className="flex items-center gap-2 mb-2"><Wallet className="w-4 h-4 text-zinc-400" /><h3 className="font-semibold">Wartość netto</h3></div>
          <div className="text-3xl font-bold">{formatCurrency(d.netWorth)}</div>
          <div className="text-xs text-zinc-500 mt-1">{d.accounts.length} kont</div>
        </div>
        <div className="bg-white dark:bg-zinc-900 rounded-2xl border border-zinc-200 dark:border-zinc-800 p-5">
          <div className="flex items-center gap-2 mb-2"><Repeat /><h3 className="font-semibold">Subskrypcje (mies.)</h3></div>
          <div className="text-3xl font-bold">{formatCurrency(d.monthlySubscriptionsTotal)}</div>
          <div className="text-xs text-zinc-500 mt-1">~{formatCurrency(d.monthlySubscriptionsTotal * 12)} rocznie</div>
        </div>
      </section>

      <section className="bg-white dark:bg-zinc-900 rounded-2xl border border-zinc-200 dark:border-zinc-800 p-5">
        <h3 className="font-semibold mb-4">Wydatki wg kategorii (ten miesiąc)</h3>
        {byCategory.length === 0 ? (
          <p className="text-sm text-zinc-500">Brak danych — dodaj transakcje.</p>
        ) : (
          <ResponsiveContainer width="100%" height={Math.max(220, byCategory.length * 40)}>
            <BarChart data={byCategory} layout="vertical" margin={{ left: 16, right: 16 }}>
              <XAxis type="number" tickFormatter={(v) => formatCurrency(v).replace(/\,00.*$/, "")} fontSize={11} />
              <YAxis type="category" dataKey="name" width={100} fontSize={12} />
              <Tooltip formatter={(v) => formatCurrency(Number(v))} />
              <Bar dataKey="value" radius={[0, 6, 6, 0]}>
                {byCategory.map((entry, i) => <Cell key={i} fill={entry.color} />)}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        )}
      </section>

      <section className="bg-white dark:bg-zinc-900 rounded-2xl border border-zinc-200 dark:border-zinc-800 p-5">
        <div className="flex items-center justify-between mb-4">
          <h3 className="font-semibold">Nadchodzące rachunki</h3>
          <Link href="/bills" className="text-sm text-blue-500 hover:underline">Wszystkie</Link>
        </div>
        {upcomingBills.length === 0 ? (
          <p className="text-sm text-zinc-500">Brak nadchodzących rachunków.</p>
        ) : (
          <ul className="space-y-2">
            {upcomingBills.map((b) => (
              <li key={b.id} className="flex items-center gap-3 p-2 rounded-lg">
                <Calendar className="w-4 h-4 text-orange-500" />
                <div className="flex-1">
                  <div className="font-medium text-sm">{b.name}</div>
                  <div className="text-xs text-zinc-500">{formatDate(b.due_date)}</div>
                </div>
                <div className="font-semibold">{formatCurrency(b.amount)}</div>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}

function Stat({ icon, label, value, color }: { icon: React.ReactNode; label: string; value: number; color: "green" | "red" | "blue" | "orange" }) {
  const colors = {
    green: "text-green-500",
    red: "text-red-500",
    blue: "text-blue-500",
    orange: "text-orange-500",
  } as const;
  return (
    <div className="bg-white dark:bg-zinc-900 rounded-2xl border border-zinc-200 dark:border-zinc-800 p-5">
      <div className={`flex items-center gap-2 ${colors[color]}`}>{icon}<span className="text-sm font-medium">{label}</span></div>
      <div className="text-2xl font-bold mt-2">{formatCurrency(value)}</div>
    </div>
  );
}

function Repeat() {
  return <svg className="w-4 h-4 text-zinc-400" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" d="M17 1l4 4-4 4M3 11V9a4 4 0 014-4h14M7 23l-4-4 4-4M21 13v2a4 4 0 01-4 4H3" /></svg>;
}
