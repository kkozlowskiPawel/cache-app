"use client";

import { useState } from "react";
import { useData } from "@/lib/data-context";
import { formatCurrency } from "@/lib/format";
import { BUDGET_PERIOD_LABEL, BudgetPeriod, Category } from "@/lib/types";
import Modal, { inputCls, labelCls, btnPrimary, btnSecondary, btnDanger } from "@/components/Modal";

export default function BudgetPage() {
  const d = useData();
  const [editing, setEditing] = useState<Category | null>(null);

  const expenseCats = d.categories.filter((c) => c.type === "expense");

  return (
    <div className="p-8 max-w-4xl">
      <h1 className="text-3xl font-bold mb-6">Budżet</h1>

      <ul className="bg-white dark:bg-zinc-900 rounded-2xl border border-zinc-200 dark:border-zinc-800 overflow-hidden divide-y divide-zinc-100 dark:divide-zinc-800">
        {expenseCats.map((c) => {
          const budget = d.budgets.find((b) => b.category_id === c.id);
          const spent = d.currentMonthExpenseForCategory(c.id);
          const progress = budget && budget.amount > 0 ? Math.min((spent / budget.amount) * 100, 100) : 0;
          const over = budget ? spent > budget.amount : false;
          return (
            <li key={c.id} className="px-4 py-3 hover:bg-zinc-50 dark:hover:bg-zinc-800/50 cursor-pointer" onClick={() => setEditing(c)}>
              <div className="flex items-center justify-between mb-1">
                <div className="flex items-center gap-2">
                  <span className="w-3 h-3 rounded-full" style={{ backgroundColor: c.color }} />
                  <span className="font-medium">{c.name}</span>
                </div>
                <div className="text-sm">
                  {budget ? (
                    <span className={over ? "text-red-500" : "text-zinc-500"}>
                      {formatCurrency(spent)} / {formatCurrency(budget.amount)}
                    </span>
                  ) : (
                    <span className="text-blue-500">Ustaw budżet</span>
                  )}
                </div>
              </div>
              {budget && (
                <div className="h-2 rounded-full bg-zinc-100 dark:bg-zinc-800 overflow-hidden">
                  <div className="h-full transition-all" style={{ width: `${progress}%`, backgroundColor: over ? "#ef4444" : c.color }} />
                </div>
              )}
            </li>
          );
        })}
      </ul>

      {editing && <EditBudgetModal category={editing} onClose={() => setEditing(null)} />}
    </div>
  );
}

function EditBudgetModal({ category, onClose }: { category: Category; onClose: () => void }) {
  const d = useData();
  const existing = d.budgets.find((b) => b.category_id === category.id);
  const [amount, setAmount] = useState(existing ? String(existing.amount) : "");
  const [period, setPeriod] = useState<BudgetPeriod>(existing?.period ?? "monthly");

  const num = parseFloat(amount.replace(",", "."));
  const valid = !isNaN(num) && num > 0;

  async function save() {
    if (!valid) return;
    await d.setBudget({ categoryId: category.id, amount: num, period });
    onClose();
  }

  async function remove() {
    if (existing) await d.deleteBudget(existing.id);
    onClose();
  }

  return (
    <Modal open onClose={onClose} title={`Budżet — ${category.name}`} footer={<>
      {existing && <button onClick={remove} className={btnDanger}>Usuń</button>}
      <button onClick={onClose} className={btnSecondary}>Anuluj</button>
      <button onClick={save} disabled={!valid} className={btnPrimary}>Zapisz</button>
    </>}>
      <div className="space-y-3">
        <div><label className={labelCls}>Kwota</label><input className={inputCls} inputMode="decimal" placeholder="0,00" value={amount} onChange={(e) => setAmount(e.target.value)} /></div>
        <div><label className={labelCls}>Okres</label>
          <select className={inputCls} value={period} onChange={(e) => setPeriod(e.target.value as BudgetPeriod)}>
            {Object.entries(BUDGET_PERIOD_LABEL).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
          </select>
        </div>
      </div>
    </Modal>
  );
}
