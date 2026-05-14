export type CategoryType = "income" | "expense";
export type AccountType = "cash" | "checking" | "savings" | "credit_card" | "investment" | "loan";
export type BillingCycle = "weekly" | "monthly" | "quarterly" | "yearly";
export type BudgetPeriod = "weekly" | "monthly" | "yearly";

export interface Category {
  id: string;
  user_id: string;
  name: string;
  icon: string;
  color: string;
  type: CategoryType;
}

export interface Account {
  id: string;
  user_id: string;
  name: string;
  type: AccountType;
  balance: number;
  currency: string;
  icon: string;
}

export interface Transaction {
  id: string;
  user_id: string;
  account_id: string | null;
  category_id: string | null;
  amount: number;
  description: string;
  date: string;
  is_recurring: boolean;
}

export interface Subscription {
  id: string;
  user_id: string;
  name: string;
  amount: number;
  billing_cycle: BillingCycle;
  next_billing_date: string;
  category_id: string | null;
  account_id: string | null;
  icon: string;
  color: string;
  active: boolean;
  notes: string | null;
  type: CategoryType;
}

export interface Bill {
  id: string;
  user_id: string;
  name: string;
  amount: number;
  due_date: string;
  paid: boolean;
  category_id: string | null;
  reminder_days_before: number;
}

export interface Budget {
  id: string;
  user_id: string;
  category_id: string;
  amount: number;
  period: BudgetPeriod;
  start_date: string;
}

export interface Goal {
  id: string;
  user_id: string;
  name: string;
  target_amount: number;
  current_amount: number;
  target_date: string | null;
  icon: string;
  color: string;
}

export const ACCOUNT_TYPE_LABEL: Record<AccountType, string> = {
  cash: "Gotówka",
  checking: "Konto bieżące",
  savings: "Oszczędności",
  credit_card: "Karta kredytowa",
  investment: "Inwestycje",
  loan: "Pożyczka",
};

export const BILLING_CYCLE_LABEL: Record<BillingCycle, string> = {
  weekly: "Tygodniowo",
  monthly: "Miesięcznie",
  quarterly: "Kwartalnie",
  yearly: "Rocznie",
};

export const BILLING_CYCLE_MONTHLY_FACTOR: Record<BillingCycle, number> = {
  weekly: 52 / 12,
  monthly: 1,
  quarterly: 1 / 3,
  yearly: 1 / 12,
};

export const BUDGET_PERIOD_LABEL: Record<BudgetPeriod, string> = {
  weekly: "Tygodniowy",
  monthly: "Miesięczny",
  yearly: "Roczny",
};
