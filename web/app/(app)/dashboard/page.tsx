"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useData } from "@/lib/data-context";
import { formatCurrency, formatDate } from "@/lib/format";
import ExpenseCalendar from "@/components/ExpenseCalendar";
import {
  BarChart, Bar, XAxis, YAxis, ResponsiveContainer, Tooltip, Cell, PieChart, Pie,
} from "recharts";
import {
  ArrowDownCircle, ArrowUpCircle, Banknote, Wallet, Repeat, Calendar as CalIcon,
} from "lucide-react";
import {
  startOfDay, startOfWeek, subDays, subWeeks, format,
} from "date-fns";
import { pl } from "date-fns/locale";

type ChartMode = "daily" | "weekly" | "categories";

export default function DashboardPage() {
  const d = useData();
  const [selectedDate, setSelectedDate] = useState<Date | null>(null);
  const [chartMode, setChartMode] = useState<ChartMode>("daily");

  const savings = d.monthlyIncome - d.monthlyExpenses;

  const dailyTotals = useMemo(() => {
    const t: Record<string, number> = {};
    for (const tx of d.transactions) {
      if (tx.amount < 0) {
        t[tx.date] = (t[tx.date] ?? 0) + Math.abs(tx.amount);
      }
    }
    return t;
  }, [d.transactions]);

  const selectedKey = selectedDate ? format(selectedDate, "yyyy-MM-dd") : null;
  const selectedDayTransactions = selectedKey
    ? d.transactions.filter((t) => t.date === selectedKey)
    : [];
  const selectedDayTotal = selectedKey ? dailyTotals[selectedKey] ?? 0 : 0;

  const dailyBuckets = useMemo(() => {
    const today = startOfDay(new Date());
    const arr: { key: string; amount: number; label: string }[] = [];
    for (let i = 29; i >= 0; i--) {
      const day = subDays(today, i);
      const key = format(day, "yyyy-MM-dd");
      arr.push({
        key,
        amount: dailyTotals[key] ?? 0,
        label: format(day, "d.MM"),
      });
    }
    return arr;
  }, [dailyTotals]);

  const weeklyBuckets = useMemo(() => {
    const thisWeek = startOfWeek(new Date(), { weekStartsOn: 1 });
    const map: Record<string, { amount: number; label: string }> = {};
    for (let i = 11; i >= 0; i--) {
      const ws = subWeeks(thisWeek, i);
      const key = format(ws, "yyyy-MM-dd");
      map[key] = { amount: 0, label: format(ws, "d.MM") };
    }
    for (const tx of d.transactions) {
      if (tx.amount >= 0) continue;
      const txDate = new Date(tx.date);
      const ws = startOfWeek(txDate, { weekStartsOn: 1 });
      const key = format(ws, "yyyy-MM-dd");
      if (map[key]) {
        map[key].amount += Math.abs(tx.amount);
      }
    }
    return Object.entries(map)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([key, v]) => ({ key, ...v }));
  }, [d.transactions]);

  const categoryBuckets = useMemo(() => {
    const grouped = d.transactions
      .filter((t) => t.amount < 0)
      .reduce<Record<string, number>>((acc, t) => {
        if (!t.category_id) return acc;
        acc[t.category_id] = (acc[t.category_id] ?? 0) + Math.abs(t.amount);
        return acc;
      }, {});
    return Object.entries(grouped)
      .map(([cid, total]) => {
        const c = d.categoryById(cid);
        return { name: c?.name ?? "—", value: total, color: c?.color ?? "#8E8E93" };
      })
      .sort((a, b) => b.value - a.value);
  }, [d.transactions, d.categoryById]);

  const totalSpending = categoryBuckets.reduce((s, c) => s + c.value, 0);

  const upcomingBills = d.bills
    .filter((b) => !b.paid && new Date(b.due_date) >= startOfDay(new Date()))
    .slice(0, 5);

  return (
    <div className="p-8 max-w-5xl space-y-6">
      <h1 className="text-3xl font-bold">Dashboard</h1>

      <Card>
        <div className="flex items-baseline justify-between mb-4">
          <h3 className="font-semibold">Ten miesiąc</h3>
          <span className="text-xs text-zinc-500 capitalize">
            {format(new Date(), "LLLL yyyy", { locale: pl })}
          </span>
        </div>
        <div className="grid grid-cols-3 gap-3">
          <Stat icon={<ArrowDownCircle className="w-4 h-4" />} label="Przychód"   value={d.monthlyIncome}   color="text-green-500" />
          <Stat icon={<ArrowUpCircle className="w-4 h-4" />}   label="Wydatki"    value={d.monthlyExpenses} color="text-red-500" />
          <Stat icon={<Banknote className="w-4 h-4" />}        label="Oszczędności" value={savings}         color={savings >= 0 ? "text-blue-500" : "text-orange-500"} />
        </div>
      </Card>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <Card>
          <div className="flex items-center gap-2 mb-1">
            <Wallet className="w-4 h-4 text-zinc-400" />
            <h3 className="font-semibold text-sm">Wartość netto</h3>
          </div>
          <div className="text-3xl font-bold tabular-nums">{formatCurrency(d.netWorth)}</div>
          <div className="text-xs text-zinc-500 mt-1">{d.accounts.length} kont</div>
        </Card>
        <Card>
          <div className="flex items-center gap-2 mb-1">
            <Repeat className="w-4 h-4 text-zinc-400" />
            <h3 className="font-semibold text-sm">Subskrypcje</h3>
          </div>
          <div className="text-3xl font-bold tabular-nums">{formatCurrency(d.monthlySubscriptionsTotal)}</div>
          <div className="text-xs text-zinc-500 mt-1">~{formatCurrency(d.monthlySubscriptionsTotal * 12)} rocznie</div>
        </Card>
      </div>

      <Card>
        <div className="flex items-center justify-between mb-3">
          <h3 className="font-semibold">Kalendarz wydatków</h3>
          {selectedDayTotal > 0 && (
            <span className="text-sm font-semibold text-red-500 tabular-nums">
              -{formatCurrency(selectedDayTotal)}
            </span>
          )}
        </div>
        <ExpenseCalendar
          dailyTotals={dailyTotals}
          selectedDate={selectedDate}
          onSelectDate={setSelectedDate}
        />
        {selectedDate && (
          <div className="mt-4 pt-4 border-t border-zinc-100 dark:border-zinc-800">
            <div className="font-semibold text-sm mb-2 capitalize">
              {format(selectedDate, "EEEE, d LLLL", { locale: pl })}
            </div>
            {selectedDayTransactions.length === 0 ? (
              <div className="text-sm text-zinc-500">Brak transakcji tego dnia</div>
            ) : (
              <ul className="space-y-2">
                {selectedDayTransactions.map((tx) => {
                  const cat = d.categoryById(tx.category_id);
                  const color = cat?.color ?? "#8E8E93";
                  return (
                    <li key={tx.id} className="flex items-center gap-2 text-sm">
                      <span className="w-7 h-7 rounded-full flex-shrink-0 flex items-center justify-center text-xs font-bold"
                            style={{ backgroundColor: color + "33", color }}>
                        {cat?.name?.[0] ?? "—"}
                      </span>
                      <span className="flex-1 truncate">{tx.description || cat?.name || "—"}</span>
                      <span className={`tabular-nums ${tx.amount < 0 ? "text-red-500" : "text-green-500"}`}>
                        {formatCurrency(tx.amount)}
                      </span>
                    </li>
                  );
                })}
              </ul>
            )}
          </div>
        )}
      </Card>

      <Card>
        <div className="flex items-center justify-between mb-3">
          <h3 className="font-semibold">Analiza wydatków</h3>
        </div>
        <div className="grid grid-cols-3 gap-1 p-1 bg-zinc-100 dark:bg-zinc-800 rounded-lg mb-4">
          {(["daily", "weekly", "categories"] as ChartMode[]).map((mode) => (
            <button
              key={mode}
              onClick={() => setChartMode(mode)}
              className={`py-1.5 rounded-md text-sm font-medium transition ${
                chartMode === mode ? "bg-white dark:bg-zinc-700 shadow-sm" : "text-zinc-600 dark:text-zinc-400"
              }`}
            >
              {mode === "daily" ? "Dni" : mode === "weekly" ? "Tygodnie" : "Kategorie"}
            </button>
          ))}
        </div>

        {chartMode === "daily" && (
          dailyBuckets.every((b) => b.amount === 0) ? (
            <EmptyChart text="Brak wydatków w ostatnich 30 dniach." />
          ) : (
            <>
              <p className="text-xs text-zinc-500 mb-2">Ostatnie 30 dni</p>
              <ResponsiveContainer width="100%" height={220}>
                <BarChart data={dailyBuckets} margin={{ top: 6, right: 6, left: 0, bottom: 0 }}>
                  <defs>
                    <linearGradient id="cacheRedGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor="#ef4444" stopOpacity={0.95} />
                      <stop offset="100%" stopColor="#ef4444" stopOpacity={0.4} />
                    </linearGradient>
                  </defs>
                  <XAxis dataKey="label" interval={4} fontSize={10} stroke="#9ca3af" tickLine={false} axisLine={false} />
                  <YAxis tickFormatter={(v) => v >= 1000 ? `${Math.round(v/1000)}k` : v.toString()} fontSize={10} stroke="#9ca3af" tickLine={false} axisLine={false} width={36} />
                  <Tooltip formatter={(v) => formatCurrency(Number(v))} contentStyle={{ borderRadius: 8, border: "1px solid #e4e4e7", fontSize: 12 }} />
                  <Bar dataKey="amount" fill="url(#cacheRedGrad)" radius={[3, 3, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </>
          )
        )}

        {chartMode === "weekly" && (
          weeklyBuckets.every((b) => b.amount === 0) ? (
            <EmptyChart text="Brak wydatków w ostatnich 12 tygodniach." />
          ) : (
            <>
              <p className="text-xs text-zinc-500 mb-2">Ostatnie 12 tygodni</p>
              <ResponsiveContainer width="100%" height={240}>
                <BarChart data={weeklyBuckets} margin={{ top: 6, right: 6, left: 0, bottom: 0 }}>
                  <defs>
                    <linearGradient id="cacheOrangeGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor="#f97316" stopOpacity={0.95} />
                      <stop offset="100%" stopColor="#f97316" stopOpacity={0.4} />
                    </linearGradient>
                  </defs>
                  <XAxis dataKey="label" fontSize={10} stroke="#9ca3af" tickLine={false} axisLine={false} />
                  <YAxis tickFormatter={(v) => v >= 1000 ? `${Math.round(v/1000)}k` : v.toString()} fontSize={10} stroke="#9ca3af" tickLine={false} axisLine={false} width={36} />
                  <Tooltip formatter={(v) => formatCurrency(Number(v))} contentStyle={{ borderRadius: 8, border: "1px solid #e4e4e7", fontSize: 12 }} />
                  <Bar dataKey="amount" fill="url(#cacheOrangeGrad)" radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </>
          )
        )}

        {chartMode === "categories" && (
          categoryBuckets.length === 0 ? (
            <EmptyChart text="Brak wydatków przypisanych do kategorii." />
          ) : (
            <div className="space-y-4">
              <ResponsiveContainer width="100%" height={240}>
                <PieChart>
                  <Pie
                    data={categoryBuckets}
                    cx="50%" cy="50%"
                    innerRadius={55} outerRadius={100}
                    paddingAngle={1.5}
                    dataKey="value" nameKey="name"
                  >
                    {categoryBuckets.map((c, i) => <Cell key={i} fill={c.color} />)}
                  </Pie>
                  <Tooltip formatter={(v) => formatCurrency(Number(v))} contentStyle={{ borderRadius: 8, border: "1px solid #e4e4e7", fontSize: 12 }} />
                </PieChart>
              </ResponsiveContainer>
              <ul className="space-y-1.5">
                {categoryBuckets.slice(0, 6).map((c) => (
                  <li key={c.name} className="flex items-center gap-2 text-sm">
                    <span className="w-2.5 h-2.5 rounded-full" style={{ backgroundColor: c.color }} />
                    <span className="flex-1">{c.name}</span>
                    <span className="tabular-nums">{formatCurrency(c.value)}</span>
                    {totalSpending > 0 && (
                      <span className="text-xs text-zinc-500 w-10 text-right">
                        {Math.round((c.value / totalSpending) * 100)}%
                      </span>
                    )}
                  </li>
                ))}
              </ul>
            </div>
          )
        )}
      </Card>

      <Card>
        <div className="flex items-center justify-between mb-3">
          <h3 className="font-semibold">Nadchodzące rachunki</h3>
          <Link href="/bills" className="text-sm text-blue-500 hover:underline">Wszystkie</Link>
        </div>
        {upcomingBills.length === 0 ? (
          <p className="text-sm text-zinc-500">Brak nadchodzących rachunków.</p>
        ) : (
          <ul className="space-y-2">
            {upcomingBills.map((b) => (
              <li key={b.id} className="flex items-center gap-3">
                <CalIcon className="w-4 h-4 text-orange-500" />
                <div className="flex-1">
                  <div className="font-medium text-sm">{b.name}</div>
                  <div className="text-xs text-zinc-500">{formatDate(b.due_date)}</div>
                </div>
                <div className="font-semibold tabular-nums">{formatCurrency(b.amount)}</div>
              </li>
            ))}
          </ul>
        )}
      </Card>
    </div>
  );
}

function Card({ children }: { children: React.ReactNode }) {
  return (
    <div className="bg-white dark:bg-zinc-900 rounded-2xl border border-zinc-200 dark:border-zinc-800 shadow-sm p-5">
      {children}
    </div>
  );
}

function Stat({ icon, label, value, color }: { icon: React.ReactNode; label: string; value: number; color: string }) {
  return (
    <div className="text-center">
      <div className={`inline-flex items-center gap-1.5 ${color}`}>
        {icon}<span className="text-xs font-medium">{label}</span>
      </div>
      <div className="text-lg font-bold tabular-nums mt-1">{formatCurrency(value)}</div>
    </div>
  );
}

function EmptyChart({ text }: { text: string }) {
  return (
    <div className="flex items-center justify-center min-h-[180px] text-sm text-zinc-500">
      {text}
    </div>
  );
}
