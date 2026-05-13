export function formatCurrency(value: number, currency = "PLN"): string {
  return new Intl.NumberFormat("pl-PL", {
    style: "currency",
    currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(value);
}

export function formatDate(value: string | Date): string {
  const d = typeof value === "string" ? new Date(value) : value;
  return new Intl.DateTimeFormat("pl-PL", { dateStyle: "medium" }).format(d);
}

export function todayISO(): string {
  return new Date().toISOString().slice(0, 10);
}

export function isSameMonth(dateStr: string, ref = new Date()): boolean {
  const d = new Date(dateStr);
  return d.getFullYear() === ref.getFullYear() && d.getMonth() === ref.getMonth();
}
