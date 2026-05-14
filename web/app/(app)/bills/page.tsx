"use client";

import { useEffect, useState } from "react";
import { useData } from "@/lib/data-context";
import { formatCurrency, formatDate, todayISO } from "@/lib/format";
import { getLastAccountId, setLastAccountId } from "@/lib/last-account";
import Modal, { inputCls, labelCls, btnPrimary, btnSecondary } from "@/components/Modal";
import { Plus, Trash2, CheckCircle2 } from "lucide-react";

export default function BillsPage() {
  const d = useData();
  const [open, setOpen] = useState(false);

  const unpaid = d.bills.filter((b) => !b.paid);
  const paid = d.bills.filter((b) => b.paid);

  return (
    <div className="p-8 max-w-4xl">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-3xl font-bold">Rachunki</h1>
        <button onClick={() => setOpen(true)} className={btnPrimary}>
          <span className="inline-flex items-center gap-2"><Plus className="w-4 h-4" />Nowy rachunek</span>
        </button>
      </div>

      {d.bills.length === 0 ? (
        <div className="text-center py-20 text-zinc-500">Brak rachunków.</div>
      ) : (
        <div className="space-y-6">
          {unpaid.length > 0 && (
            <section>
              <h3 className="text-sm font-medium text-zinc-500 mb-2">Do zapłaty</h3>
              <ul className="bg-white dark:bg-zinc-900 rounded-2xl border border-zinc-200 dark:border-zinc-800 overflow-hidden divide-y divide-zinc-100 dark:divide-zinc-800">
                {unpaid.map((b) => {
                  const acc = d.accountById(b.account_id);
                  return (
                    <li key={b.id} className="px-4 py-3 flex items-center gap-3 group">
                      <div className="flex-1 min-w-0">
                        <div className="font-medium">{b.name}</div>
                        <div className="text-xs text-zinc-500">
                          {formatDate(b.due_date)}
                          {acc && <> · {acc.name}</>}
                        </div>
                      </div>
                      <div className="font-semibold text-red-500 tabular-nums">{formatCurrency(b.amount)}</div>
                      <button
                        onClick={() => d.payBill(b.id)}
                        className="px-3 py-1.5 rounded-lg bg-green-500 hover:bg-green-600 text-white text-sm font-medium transition"
                        title="Utwórz transakcję i oznacz jako zapłacony"
                      >
                        Zapłać
                      </button>
                      <button onClick={() => d.deleteBill(b.id)} className="opacity-0 group-hover:opacity-100 text-zinc-400 hover:text-red-500" title="Usuń"><Trash2 className="w-4 h-4" /></button>
                    </li>
                  );
                })}
              </ul>
              <p className="text-xs text-zinc-500 mt-2">Kliknięcie „Zapłać" utworzy transakcję na dzisiejszą datę i zmniejszy saldo wskazanego konta.</p>
            </section>
          )}

          {paid.length > 0 && (
            <section>
              <h3 className="text-sm font-medium text-zinc-500 mb-2">Zapłacone</h3>
              <ul className="bg-white dark:bg-zinc-900 rounded-2xl border border-zinc-200 dark:border-zinc-800 overflow-hidden divide-y divide-zinc-100 dark:divide-zinc-800">
                {paid.map((b) => {
                  const acc = d.accountById(b.account_id);
                  return (
                    <li key={b.id} className="px-4 py-3 flex items-center gap-3 group">
                      <CheckCircle2 className="w-5 h-5 text-green-500" />
                      <div className="flex-1 min-w-0">
                        <div className="font-medium line-through text-zinc-400">{b.name}</div>
                        <div className="text-xs text-zinc-500">
                          {formatDate(b.due_date)}
                          {acc && <> · {acc.name}</>}
                        </div>
                      </div>
                      <div className="font-semibold text-zinc-400 line-through tabular-nums">{formatCurrency(b.amount)}</div>
                      <button onClick={() => d.togglePaid(b)} className="text-xs text-zinc-500 hover:underline">Cofnij oznaczenie</button>
                      <button onClick={() => d.deleteBill(b.id)} className="opacity-0 group-hover:opacity-100 text-zinc-400 hover:text-red-500"><Trash2 className="w-4 h-4" /></button>
                    </li>
                  );
                })}
              </ul>
              <p className="text-xs text-zinc-500 mt-2">„Cofnij oznaczenie" tylko zmienia status — nie usuwa transakcji. Aby ją cofnąć, usuń ją z listy wydatków.</p>
            </section>
          )}
        </div>
      )}

      {open && <AddBillModal onClose={() => setOpen(false)} />}
    </div>
  );
}

function AddBillModal({ onClose }: { onClose: () => void }) {
  const d = useData();
  const [name, setName] = useState("");
  const [amount, setAmount] = useState("");
  const [dueDate, setDueDate] = useState(todayISO());
  const [categoryId, setCategoryId] = useState("");
  const [accountId, setAccountId] = useState("");
  const [reminder, setReminder] = useState(3);

  useEffect(() => {
    const last = getLastAccountId();
    if (last && d.accounts.some((a) => a.id === last)) setAccountId(last);
  }, [d.accounts]);

  const num = parseFloat(amount.replace(",", "."));
  const valid = name.trim() && !isNaN(num) && num > 0;

  async function save() {
    if (!valid) return;
    await d.addBill({
      name, amount: num, dueDate,
      categoryId: categoryId || null,
      accountId: accountId || null,
      reminderDays: reminder,
    });
    if (accountId) setLastAccountId(accountId);
    onClose();
  }

  return (
    <Modal open onClose={onClose} title="Nowy rachunek" footer={<>
      <button onClick={onClose} className={btnSecondary}>Anuluj</button>
      <button onClick={save} disabled={!valid} className={btnPrimary}>Zapisz</button>
    </>}>
      <div className="space-y-3">
        <div><label className={labelCls}>Nazwa</label><input className={inputCls} value={name} onChange={(e) => setName(e.target.value)} placeholder="np. Prąd, Szkoła" autoFocus /></div>
        <div><label className={labelCls}>Kwota</label><input className={inputCls} inputMode="decimal" placeholder="0,00" value={amount} onChange={(e) => setAmount(e.target.value)} /></div>
        <div><label className={labelCls}>Termin</label><input type="date" className={inputCls} value={dueDate} onChange={(e) => setDueDate(e.target.value)} /></div>
        <div><label className={labelCls}>Konto (z którego zapłacisz)</label>
          <select className={inputCls} value={accountId} onChange={(e) => setAccountId(e.target.value)}>
            <option value="">Brak — bez wpływu na saldo</option>
            {d.accounts.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}
          </select>
        </div>
        <div><label className={labelCls}>Kategoria</label>
          <select className={inputCls} value={categoryId} onChange={(e) => setCategoryId(e.target.value)}>
            <option value="">Brak</option>
            {d.categories.filter((c) => c.type === "expense").map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>
        </div>
        <div><label className={labelCls}>Przypomnienie (dni wcześniej)</label><input type="number" min={0} max={30} className={inputCls} value={reminder} onChange={(e) => setReminder(parseInt(e.target.value) || 0)} /></div>
      </div>
    </Modal>
  );
}
