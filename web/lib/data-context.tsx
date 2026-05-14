"use client";

import { createContext, useCallback, useContext, useEffect, useRef, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import type { SupabaseClient } from "@supabase/supabase-js";
import type {
  Account, Bill, Budget, Category, Goal, Subscription, Transaction,
  AccountType, BillingCycle, BudgetPeriod,
} from "@/lib/types";
import { BILLING_CYCLE_MONTHLY_FACTOR } from "@/lib/types";
import { isSameMonth } from "@/lib/format";

type Ctx = {
  loading: boolean;
  userId: string | null;

  categories: Category[];
  accounts: Account[];
  transactions: Transaction[];
  subscriptions: Subscription[];
  bills: Bill[];
  budgets: Budget[];
  goals: Goal[];

  // helpers
  categoryById: (id: string | null) => Category | undefined;
  accountById: (id: string | null) => Account | undefined;
  monthlyIncome: number;
  monthlyExpenses: number;
  netWorth: number;
  monthlySubscriptionsTotal: number;
  currentMonthExpenseForCategory: (categoryId: string) => number;

  // mutations
  addTransaction: (p: { amount: number; description: string; date: string; categoryId: string | null; accountId: string | null }) => Promise<void>;
  deleteTransaction: (id: string) => Promise<void>;

  addSubscription: (p: { name: string; amount: number; cycle: BillingCycle; nextDate: string; categoryId: string | null; accountId: string | null; notes: string | null; firstPaymentDate: string | null }) => Promise<void>;
  toggleSubscriptionActive: (s: Subscription) => Promise<void>;
  deleteSubscription: (id: string) => Promise<void>;

  addBill: (p: { name: string; amount: number; dueDate: string; categoryId: string | null; reminderDays: number }) => Promise<void>;
  togglePaid: (b: Bill) => Promise<void>;
  deleteBill: (id: string) => Promise<void>;

  setBudget: (p: { categoryId: string; amount: number; period: BudgetPeriod }) => Promise<void>;
  deleteBudget: (id: string) => Promise<void>;

  addGoal: (p: { name: string; target: number; current: number; targetDate: string | null; icon: string; color: string }) => Promise<void>;
  updateGoalCurrent: (id: string, current: number) => Promise<void>;
  deleteGoal: (id: string) => Promise<void>;

  addAccount: (p: { name: string; type: AccountType; balance: number }) => Promise<void>;
  deleteAccount: (id: string) => Promise<void>;
};

const DataContext = createContext<Ctx | null>(null);

export function useData() {
  const ctx = useContext(DataContext);
  if (!ctx) throw new Error("useData must be inside <DataProvider>");
  return ctx;
}

export function DataProvider({ userId, children }: { userId: string; children: React.ReactNode }) {
  const supabaseRef = useRef<SupabaseClient | null>(null);
  if (!supabaseRef.current) supabaseRef.current = createClient();
  const supabase = supabaseRef.current!;

  const [loading, setLoading] = useState(true);
  const [categories, setCategories] = useState<Category[]>([]);
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [subscriptions, setSubscriptions] = useState<Subscription[]>([]);
  const [bills, setBills] = useState<Bill[]>([]);
  const [budgets, setBudgets] = useState<Budget[]>([]);
  const [goals, setGoals] = useState<Goal[]>([]);

  const refreshTable = useCallback(async (table: string) => {
    switch (table) {
      case "categories":    { const { data } = await supabase.from(table).select("*"); setCategories(data ?? []); break; }
      case "accounts":      { const { data } = await supabase.from(table).select("*"); setAccounts(data ?? []); break; }
      case "transactions":  { const { data } = await supabase.from(table).select("*").order("date", { ascending: false }); setTransactions(data ?? []); break; }
      case "subscriptions": { const { data } = await supabase.from(table).select("*").order("next_billing_date", { ascending: true }); setSubscriptions(data ?? []); break; }
      case "bills":         { const { data } = await supabase.from(table).select("*").order("due_date", { ascending: true }); setBills(data ?? []); break; }
      case "budgets":       { const { data } = await supabase.from(table).select("*"); setBudgets(data ?? []); break; }
      case "goals":         { const { data } = await supabase.from(table).select("*"); setGoals(data ?? []); break; }
    }
  }, [supabase]);

  useEffect(() => {
    let mounted = true;
    (async () => {
      setLoading(true);
      // Najpierw obciaz zalegle subskrypcje (idempotentne, atomowe w bazie).
      await supabase.rpc("charge_due_subscriptions");
      await Promise.all([
        refreshTable("categories"),
        refreshTable("accounts"),
        refreshTable("transactions"),
        refreshTable("subscriptions"),
        refreshTable("bills"),
        refreshTable("budgets"),
        refreshTable("goals"),
      ]);
      if (mounted) setLoading(false);
    })();
    return () => { mounted = false; };
  }, [supabase, refreshTable]);

  useEffect(() => {
    const tables = ["categories", "accounts", "transactions", "subscriptions", "bills", "budgets", "goals"];
    const channel = supabase.channel("public-all");
    tables.forEach((table) => {
      channel.on(
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        "postgres_changes" as any,
        { event: "*", schema: "public", table },
        () => { refreshTable(table); }
      );
    });
    channel.subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [supabase, refreshTable]);

  // mutations
  const addTransaction = async (p: { amount: number; description: string; date: string; categoryId: string | null; accountId: string | null }) => {
    await supabase.from("transactions").insert({
      user_id: userId,
      account_id: p.accountId,
      category_id: p.categoryId,
      amount: p.amount,
      description: p.description,
      date: p.date,
    });
  };
  const deleteTransaction = async (id: string) => { await supabase.from("transactions").delete().eq("id", id); };

  const addSubscription = async (p: { name: string; amount: number; cycle: BillingCycle; nextDate: string; categoryId: string | null; accountId: string | null; notes: string | null; firstPaymentDate: string | null }) => {
    await supabase.from("subscriptions").insert({
      user_id: userId, name: p.name, amount: p.amount,
      billing_cycle: p.cycle, next_billing_date: p.nextDate,
      category_id: p.categoryId, account_id: p.accountId, notes: p.notes,
    });
    if (p.firstPaymentDate) {
      await supabase.from("transactions").insert({
        user_id: userId,
        account_id: p.accountId,
        category_id: p.categoryId,
        amount: -p.amount,
        description: `Subskrypcja: ${p.name}`,
        date: p.firstPaymentDate,
        is_recurring: true,
      });
    }
  };
  const toggleSubscriptionActive = async (s: Subscription) => { await supabase.from("subscriptions").update({ active: !s.active }).eq("id", s.id); };
  const deleteSubscription = async (id: string) => { await supabase.from("subscriptions").delete().eq("id", id); };

  const addBill = async (p: { name: string; amount: number; dueDate: string; categoryId: string | null; reminderDays: number }) => {
    await supabase.from("bills").insert({
      user_id: userId, name: p.name, amount: p.amount, due_date: p.dueDate,
      category_id: p.categoryId, reminder_days_before: p.reminderDays,
    });
  };
  const togglePaid = async (b: Bill) => { await supabase.from("bills").update({ paid: !b.paid }).eq("id", b.id); };
  const deleteBill = async (id: string) => { await supabase.from("bills").delete().eq("id", id); };

  const setBudget = async (p: { categoryId: string; amount: number; period: BudgetPeriod }) => {
    await supabase.from("budgets").upsert({
      user_id: userId, category_id: p.categoryId, amount: p.amount, period: p.period,
      start_date: new Date().toISOString().slice(0, 10),
    }, { onConflict: "user_id,category_id,period" });
  };
  const deleteBudget = async (id: string) => { await supabase.from("budgets").delete().eq("id", id); };

  const addGoal = async (p: { name: string; target: number; current: number; targetDate: string | null; icon: string; color: string }) => {
    await supabase.from("goals").insert({
      user_id: userId, name: p.name, target_amount: p.target, current_amount: p.current,
      target_date: p.targetDate, icon: p.icon, color: p.color,
    });
  };
  const updateGoalCurrent = async (id: string, current: number) => { await supabase.from("goals").update({ current_amount: current }).eq("id", id); };
  const deleteGoal = async (id: string) => { await supabase.from("goals").delete().eq("id", id); };

  const addAccount = async (p: { name: string; type: AccountType; balance: number }) => {
    await supabase.from("accounts").insert({
      user_id: userId, name: p.name, type: p.type, balance: p.balance,
    });
  };
  const deleteAccount = async (id: string) => { await supabase.from("accounts").delete().eq("id", id); };

  const categoryById = (id: string | null) => categories.find((c) => c.id === id);
  const accountById = (id: string | null) => accounts.find((a) => a.id === id);

  const monthlyExpenses = transactions.filter((t) => t.amount < 0 && isSameMonth(t.date)).reduce((s, t) => s + Math.abs(t.amount), 0);
  const monthlyIncome = transactions.filter((t) => t.amount > 0 && isSameMonth(t.date)).reduce((s, t) => s + t.amount, 0);
  const netWorth = accounts.reduce((s, a) => s + a.balance, 0);
  const monthlySubscriptionsTotal = subscriptions.filter((s) => s.active).reduce((sum, s) => sum + s.amount * BILLING_CYCLE_MONTHLY_FACTOR[s.billing_cycle], 0);
  const currentMonthExpenseForCategory = (cid: string) =>
    transactions.filter((t) => t.category_id === cid && t.amount < 0 && isSameMonth(t.date))
      .reduce((s, t) => s + Math.abs(t.amount), 0);

  const value: Ctx = {
    loading, userId,
    categories, accounts, transactions, subscriptions, bills, budgets, goals,
    categoryById, accountById,
    monthlyIncome, monthlyExpenses, netWorth, monthlySubscriptionsTotal, currentMonthExpenseForCategory,
    addTransaction, deleteTransaction,
    addSubscription, toggleSubscriptionActive, deleteSubscription,
    addBill, togglePaid, deleteBill,
    setBudget, deleteBudget,
    addGoal, updateGoalCurrent, deleteGoal,
    addAccount, deleteAccount,
  };

  return <DataContext.Provider value={value}>{children}</DataContext.Provider>;
}
