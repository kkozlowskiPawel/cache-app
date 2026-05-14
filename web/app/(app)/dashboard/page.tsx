"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useData } from "@/lib/data-context";
import { formatCurrency, formatDate, isSameMonth } from "@/lib/format";
import ExpenseCalendar from "@/components/ExpenseCalendar";
import {
  BarChart, Bar, XAxis, YAxis, ResponsiveContainer, Tooltip, Cell, PieChart, Pie,
} from "recharts";
import {
  ArrowDownCircle, ArrowUpCircle, Banknote, Wallet, Repeat, Calendar as CalIcon,
  ChevronDown, Check, CreditCard, PiggyBank, Landmark,
} from "lucide-react";
import { startOfDay, startOfWeek, subDays, subWeeks, format } from "date-fns";
import { pl } from "date-fns/locale";
import type { Transaction, Account, AccountType } from "@/lib/types";
import { ACCOUNT_TYPE_LABEL } from "@/lib/types";

type ChartMode = "daily" | "weekly" | "categories";
type AccountFilter = string | "all";

const ACCOUNT_ICONS: Record<AccountType, React.ComponentType<{ className?: string }>> = {
  checking: Landmark,
  savings: PiggyBank,
  credit_card: CreditCard,
  cash: Wallet,
  investment: Banknote,
  loan: CreditCard,
};

export default function DashboardPage() {
  const d = useData();
  const [selectedDate, setSelectedDate] = useState<Date | null>(null);
  const [chartMode, setChartMode] = useState<ChartMode>("daily");
  const [accountFilter, setAccountFilter] = useState<AccountFilter>("all");
  const [menuOpen, setMenuOpen] = useState(false);

  const filteredTx: Transaction[] = useMemo(
    () => accountFilter === "all"
      ? d.transactions
      : d.transactions.filter((t) => t.account_id === accountFilter),
    [d.transactions, accountFilter]
  );

  const monthlyIncome  = useMemo(() => filteredTx.filter((t) => t.amount > 0 && isSameMonth(t.date)).reduce((s, t) => s + t.amount, 0), [filteredTx]);
  const monthlyExpenses = useMemo(() => filteredTx.filter((t) => t.amount < 0 && isSameMonth(t.date)).reduce((s, t) => s + Math.abs(t.amount), 0), [filteredTx]);
  const savings = monthlyIncome - monthlyExpenses;

  const dailyTotals = useMemo(() => {
    const t: Record<string, number> = {};
    for (const tx of filteredTx) {
      if (tx.amount < 0) t[tx.date] = (t[tx.date] ?? 0) + Math.abs(tx.amount);
    }
    return t;
  }, [filteredTx]);

  const selectedKey = selectedDate ? format(selectedDate, "yyyy-MM-dd") : null;
  const selectedDayTransactions = selectedKey ? filteredTx.filter((t) => t.date === selectedKey) : [];
  const selectedDayTotal = selectedKey ? dailyTotals[selectedKey] ?? 0 : 0;

  const dailyBuckets = useMemo(() => {
    const today = startOfDay(new Date());
    const arr: { key: string; amount: number; label: string }[] = [];
    for (let i = 29; i >= 0; i--) {
      const day = subDays(today, i);
      const key = format(day, "yyyy-MM-dd");
      arr.push({ key, amount: dailyTotals[key] ?? 0, label: format(day, "d.MM") });
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
    for (const tx of filteredTx) {
      if (tx.amount >= 0) continue;
      const ws = startOfWeek(new Date(tx.date), { weekStartsOn: 1 });
      const key = format(ws, "yyyy-MM-dd");
      if (map[key]) map[key].amount += Math.abs(tx.amount);
    }
    return Object.entries(map).sort(([a], [b]) => a.localeCompare(b)).map(([key, v]) => ({ key, ...v }));
  }, [filteredTx]);

  const categoryBuckets = useMemo(() => {
    const grouped = filteredTx.filter((t) => t.amount < 0).reduce<Record<string, number>>((acc, t) => {
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
  }, [filteredTx, d]);

  const totalSpending = categoryBuckets.reduce((s, c) => s + c.value, 0);

  const upcomingBills = d.bills
    .filter((b) => !b.paid && new Date(b.due_date) >= startOfDay(new Date()))
    .filter((b) => accountFilter === "all" || b.account_id === accountFilter)
    .slice(0, 5);

  const perAccountMonthly = useMemo(() => {
    const map: Record<string, { income: number; expense: number }> = {};
    for (const a of d.accounts) map[a.id] = { income: 0, expense: 0 };
    for (const t of d.transactions) {
      if (!t.account_id || !isSameMonth(t.date) || !map[t.account_id]) continue;
      if (t.amount > 0) map[t.account_id].income += t.amount;
      else map[t.account_id].expense += Math.abs(t.amount);
    }
    return map;
  }, [d.transactions, d.accounts]);

  const totalMonthly = useMemo(() => {
    let income = 0, expense = 0;
    for (const t of d.transactions) {
      if (!isSameMonth(t.date)) continue;
      if (t.amount > 0) income += t.amount;
      else expense += Math.abs(t.amount);
    }
    return { income, expense };
  }, [d.transactions]);

  const selectedAccount = accountFilter === "all" ? null : d.accounts.find((a) => a.id === accountFilter);

  return (
    <div className="p-8 max-w-5xl space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-3xl font-bold">Dashboard</h1>
        <div className="relative">
          <button
            onClick={() => setMenuOpen((v) => !v)}
            onBlur={() => setTimeout(() => setMenuOpen(false), 150)}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-zinc-100 dark:bg-zinc-800 hover:bg-zinc-200 dark:hover:bg-zinc-700 text-sm transition"
          >
            <span className="font-medium">{selectedAccount ? selectedAccount.name : "Wszystkie konta"}</span>
            <ChevronDown className="w-4 h-4 text-zinc-500" />
          </button>
          {menuOpen && (
            <div className="absolute right-0 mt-1 min-w-[200px] bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 rounded-xl shadow-lg z-10 overflow-hidden">
              <MenuItem label="Wszystkie konta" active={accountFilter === "all"} onClick={() => { setAccountFilter("all"); setMenuOpen(false); }} />
              {d.accounts.map((a) => (
                <MenuItem key={a.id} label={a.name} active={accountFilter === a.id} onClick={() => { setAccountFilter(a.id); setMenuOpen(false); }} />
              ))}
            </div>
          )}
        </div>
      </div>

      <AccountCarousel
        accounts={d.accounts}
        netWorth={d.netWorth}
        totalMonthly={totalMonthly}
        perAccountMonthly={perAccountMonthly}
        selected={accountFilter}
        onSelect={setAccountFilter}
        subscriptionsTotal={d.monthlySubscriptionsTotal}
      />

      <Card>
        <div className="flex items-baseline justify-between mb-4">
          <h3 className="font-semibold">Ten miesiąc{selectedAccount ? ` · ${selectedAccount.name}` : ""}</h3>
          <span className="text-xs text-zinc-500 capitalize">{format(new Date(), "LLLL yyyy", { locale: pl })}</span>
        </div>
        <div className="grid grid-cols-3 gap-3">
          <Stat icon={<ArrowDownCircle className="w-4 h-4" />} label="Przychód"   value={monthlyIncome}   color="text-green-500" />
          <Stat icon={<ArrowUpCircle className="w-4 h-4" />}   label="Wydatki"    value={monthlyExpenses} color="text-red-500" />
          <Stat icon={<Banknote className="w-4 h-4" />}        label="Oszczędności" value={savings}        color={savings >= 0 ? "text-blue-500" : "text-orange-500"} />
        </div>
      </Card>

      <Card>
        <div className="flex items-center justify-between mb-3">
          <h3 className="font-semibold">Kalendarz wydatków</h3>
          {selectedDayTotal > 0 && (
            <span className="text-sm font-semibold text-red-500 tabular-nums">-{formatCurrency(selectedDayTotal)}</span>
          )}
        </div>
        <ExpenseCalendar dailyTotals={dailyTotals} selectedDate={selectedDate} onSelectDate={setSelectedDate} />
        {selectedDate && (
          <div className="mt-4 pt-4 border-t border-zinc-100 dark:border-zinc-800">
            <div className="font-semibold text-sm mb-2 capitalize">{format(selectedDate, "EEEE, d LLLL", { locale: pl })}</div>
            {selectedDayTransactions.length === 0 ? (
              <div className="text-sm text-zinc-500">Brak transakcji tego dnia</div>
            ) : (
              <ul className="space-y-2">
                {selectedDayTransactions.map((tx) => {
                  const cat = d.categoryById(tx.category_id);
                  const color = cat?.color ?? "#8E8E93";
                  return (
                    <li key={tx.id} className="flex items-center gap-2 text-sm">
                      <span className="w-7 h-7 rounded-full flex-shrink-0 flex items-center justify-center text-xs font-bold" style={{ backgroundColor: color + "33", color }}>
                        {cat?.name?.[0] ?? "—"}
                      </span>
                      <span className="flex-1 truncate">{tx.description || cat?.name || "—"}</span>
                      <span className={`tabular-nums ${tx.amount < 0 ? "text-red-500" : "text-green-500"}`}>{formatCurrency(tx.amount)}</span>
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
            <button key={mode} onClick={() => setChartMode(mode)}
              className={`py-1.5 rounded-md text-sm font-medium transition ${chartMode === mode ? "bg-white dark:bg-zinc-700 shadow-sm" : "text-zinc-600 dark:text-zinc-400"}`}>
              {mode === "daily" ? "Dni" : mode === "weekly" ? "Tygodnie" : "Kategorie"}
            </button>
          ))}
        </div>

        {chartMode === "daily" && (
          dailyBuckets.every((b) => b.amount === 0) ? <EmptyChart text="Brak wydatków w ostatnich 30 dniach." /> : (
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
          weeklyBuckets.every((b) => b.amount === 0) ? <EmptyChart text="Brak wydatków w ostatnich 12 tygodniach." /> : (
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
          categoryBuckets.length === 0 ? <EmptyChart text="Brak wydatków przypisanych do kategorii." /> : (
            <div className="space-y-4">
              <ResponsiveContainer width="100%" height={240}>
                <PieChart>
                  <Pie data={categoryBuckets} cx="50%" cy="50%" innerRadius={55} outerRadius={100} paddingAngle={1.5} dataKey="value" nameKey="name">
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
                      <span className="text-xs text-zinc-500 w-10 text-right">{Math.round((c.value / totalSpending) * 100)}%</span>
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

function AccountCarousel({
  accounts, netWorth, totalMonthly, perAccountMonthly, selected, onSelect, subscriptionsTotal,
}: {
  accounts: Account[];
  netWorth: number;
  totalMonthly: { income: number; expense: number };
  perAccountMonthly: Record<string, { income: number; expense: number }>;
  selected: AccountFilter;
  onSelect: (id: AccountFilter) => void;
  subscriptionsTotal: number;
}) {
  return (
    <div className="-mx-2 overflow-x-auto pb-2">
      <div className="flex gap-3 px-2 snap-x snap-mandatory">
        <AccountCard
          active={selected === "all"}
          onClick={() => onSelect("all")}
          title="Wartość netto"
          subtitle={`${accounts.length} kont · subskrypcje ${formatCurrency(subscriptionsTotal)}/mc`}
          balance={netWorth}
          income={totalMonthly.income}
          expense={totalMonthly.expense}
          icon={<Wallet className="w-4 h-4" />}
          accent="bg-blue-500/10 text-blue-500"
        />
        {accounts.map((a) => {
          const m = perAccountMonthly[a.id] ?? { income: 0, expense: 0 };
          const Icon = ACCOUNT_ICONS[a.type] ?? Wallet;
          return (
            <AccountCard
              key={a.id}
              active={selected === a.id}
              onClick={() => onSelect(a.id)}
              title={a.name}
              subtitle={ACCOUNT_TYPE_LABEL[a.type]}
              balance={a.balance}
              income={m.income}
              expense={m.expense}
              icon={<Icon className="w-4 h-4" />}
              accent="bg-zinc-200/60 dark:bg-zinc-700/60 text-zinc-700 dark:text-zinc-200"
            />
          );
        })}
      </div>
    </div>
  );
}

function AccountCard({
  active, onClick, title, subtitle, balance, income, expense, icon, accent,
}: {
  active: boolean; onClick: () => void;
  title: string; subtitle: string; balance: number;
  income: number; expense: number;
  icon: React.ReactNode; accent: string;
}) {
  return (
    <button
      onClick={onClick}
      className={`snap-start text-left flex-shrink-0 w-[220px] rounded-2xl p-4 border transition ${
        active
          ? "bg-blue-500 text-white border-blue-500 shadow-md"
          : "bg-white dark:bg-zinc-900 border-zinc-200 dark:border-zinc-800 hover:border-zinc-300 dark:hover:border-zinc-700"
      }`}
    >
      <div className="flex items-center gap-2 mb-2">
        <span className={`w-7 h-7 rounded-full flex items-center justify-center ${active ? "bg-white/20 text-white" : accent}`}>{icon}</span>
        <div className="min-w-0">
          <div className="font-semibold text-sm truncate">{title}</div>
          <div className={`text-[11px] truncate ${active ? "text-white/70" : "text-zinc-500"}`}>{subtitle}</div>
        </div>
      </div>
      <div className="text-xl font-bold tabular-nums mb-2">{formatCurrency(balance)}</div>
      <div className="flex items-center justify-between text-[11px]">
        <span className={`tabular-nums ${active ? "text-white/90" : "text-green-500"}`}>+{formatCurrency(income)}</span>
        <span className={`tabular-nums ${active ? "text-white/90" : "text-red-500"}`}>-{formatCurrency(expense)}</span>
      </div>
    </button>
  );
}

function MenuItem({ label, active, onClick }: { label: string; active: boolean; onClick: () => void }) {
  return (
    <button onMouseDown={(e) => e.preventDefault()} onClick={onClick}
      className={`w-full text-left px-3 py-2 text-sm flex items-center gap-2 hover:bg-zinc-100 dark:hover:bg-zinc-800 ${active ? "font-medium" : ""}`}>
      <Check className={`w-3.5 h-3.5 ${active ? "opacity-100" : "opacity-0"}`} />
      {label}
    </button>
  );
}

function Card({ children }: { children: React.ReactNode }) {
  return <div className="bg-white dark:bg-zinc-900 rounded-2xl border border-zinc-200 dark:border-zinc-800 shadow-sm p-5">{children}</div>;
}

function Stat({ icon, label, value, color }: { icon: React.ReactNode; label: string; value: number; color: string }) {
  return (
    <div className="text-center">
      <div className={`inline-flex items-center gap-1.5 ${color}`}>{icon}<span className="text-xs font-medium">{label}</span></div>
      <div className="text-lg font-bold tabular-nums mt-1">{formatCurrency(value)}</div>
    </div>
  );
}

function EmptyChart({ text }: { text: string }) {
  return <div className="flex items-center justify-center min-h-[180px] text-sm text-zinc-500">{text}</div>;
}
