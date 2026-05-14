"use client";

import { useEffect, useState } from "react";
import { useData } from "@/lib/data-context";
import { formatCurrency, formatDate, todayISO } from "@/lib/format";
import { BILLING_CYCLE_LABEL, BillingCycle } from "@/lib/types";
import { getLastAccountId, setLastAccountId } from "@/lib/last-account";
import Modal, { inputCls, labelCls, btnPrimary, btnSecondary } from "@/components/Modal";
import { Plus, Pause, Play, Trash2 } from "lucide-react";

export default function SubscriptionsPage() {
  const d = useData();
  const [open, setOpen] = useState(false);

  return (
    <div className="p-8 max-w-4xl">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-3xl font-bold">Subskrypcje</h1>
        <button onClick={() => setOpen(true)} className={btnPrimary}>
          <span className="inline-flex items-center gap-2"><Plus className="w-4 h-4" />Nowa subskrypcja</span>
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
        <div className="bg-white dark:bg-zinc-900 rounded-2xl border border-zinc-200 dark:border-zinc-800 p-5">
          <div className="text-sm text-zinc-500">Łącznie miesięcznie</div>
          <div className="text-3xl font-bold">{formatCurrency(d.monthlySubscriptionsTotal)}</div>
        </div>
        <div className="bg-white dark:bg-zinc-900 rounded-2xl border border-zinc-200 dark:border-zinc-800 p-5">
          <div className="text-sm text-zinc-500">Rocznie</div>
          <div className="text-3xl font-bold">{formatCurrency(d.monthlySubscriptionsTotal * 12)}</div>
        </div>
      </div>

      {d.subscriptions.length === 0 ? (
        <div className="text-center py-20 text-zinc-500">Brak subskrypcji.</div>
      ) : (
        <ul className="bg-white dark:bg-zinc-900 rounded-2xl border border-zinc-200 dark:border-zinc-800 overflow-hidden divide-y divide-zinc-100 dark:divide-zinc-800">
          {d.subscriptions.map((s) => {
            const acc = d.accountById(s.account_id);
            return (
              <li key={s.id} className="flex items-center gap-3 px-4 py-3 group">
                <div className="w-10 h-10 rounded-full flex items-center justify-center" style={{ backgroundColor: s.color + "33", color: s.color }}>
                  <span className="font-bold">{s.name[0]}</span>
                </div>
                <div className="flex-1 min-w-0">
                  <div className={`font-medium ${!s.active ? "line-through text-zinc-400" : ""}`}>{s.name}</div>
                  <div className="text-xs text-zinc-500">
                    Następna: {formatDate(s.next_billing_date)}
                    {acc && <> · {acc.name}</>}
                  </div>
                </div>
                <div className="text-right">
                  <div className="font-semibold">{formatCurrency(s.amount)}</div>
                  <div className="text-xs text-zinc-500">{BILLING_CYCLE_LABEL[s.billing_cycle]}</div>
                </div>
                <button onClick={() => d.toggleSubscriptionActive(s)} className="text-zinc-400 hover:text-zinc-700 dark:hover:text-zinc-200" title={s.active ? "Pauza" : "Wznów"}>
                  {s.active ? <Pause className="w-4 h-4" /> : <Play className="w-4 h-4" />}
                </button>
                <button onClick={() => d.deleteSubscription(s.id)} className="text-zinc-400 hover:text-red-500"><Trash2 className="w-4 h-4" /></button>
              </li>
            );
          })}
        </ul>
      )}

      {open && <AddSubscriptionModal onClose={() => setOpen(false)} />}
    </div>
  );
}

function AddSubscriptionModal({ onClose }: { onClose: () => void }) {
  const d = useData();
  const [name, setName] = useState("");
  const [amount, setAmount] = useState("");
  const [cycle, setCycle] = useState<BillingCycle>("monthly");
  const [nextDate, setNextDate] = useState(todayISO());
  const [categoryId, setCategoryId] = useState("");
  const [accountId, setAccountId] = useState("");
  const [notes, setNotes] = useState("");
  const [hasFirstPayment, setHasFirstPayment] = useState(false);
  const [firstPaymentDate, setFirstPaymentDate] = useState(todayISO());

  useEffect(() => {
    const last = getLastAccountId();
    if (last && d.accounts.some((a) => a.id === last)) setAccountId(last);
  }, [d.accounts]);

  const num = parseFloat(amount.replace(",", "."));
  const valid = name.trim() && !isNaN(num) && num > 0;

  async function save() {
    if (!valid) return;
    await d.addSubscription({
      name,
      amount: num,
      cycle,
      nextDate,
      categoryId: categoryId || null,
      accountId: accountId || null,
      notes: notes || null,
      firstPaymentDate: hasFirstPayment ? firstPaymentDate : null,
    });
    if (accountId) setLastAccountId(accountId);
    onClose();
  }

  return (
    <Modal open onClose={onClose} title="Nowa subskrypcja" footer={<>
      <button onClick={onClose} className={btnSecondary}>Anuluj</button>
      <button onClick={save} disabled={!valid} className={btnPrimary}>Zapisz</button>
    </>}>
      <div className="space-y-3">
        <div><label className={labelCls}>Nazwa</label><input className={inputCls} value={name} onChange={(e) => setName(e.target.value)} placeholder="np. Netflix" autoFocus /></div>
        <div><label className={labelCls}>Kwota</label><input className={inputCls} inputMode="decimal" placeholder="0,00" value={amount} onChange={(e) => setAmount(e.target.value)} /></div>
        <div><label className={labelCls}>Cykl</label>
          <select className={inputCls} value={cycle} onChange={(e) => setCycle(e.target.value as BillingCycle)}>
            {Object.entries(BILLING_CYCLE_LABEL).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
          </select>
        </div>
        <div><label className={labelCls}>Następna płatność</label><input type="date" className={inputCls} value={nextDate} onChange={(e) => setNextDate(e.target.value)} /></div>

        <div className="rounded-lg border border-zinc-200 dark:border-zinc-700 p-3 space-y-2">
          <label className="flex items-center gap-2 text-sm cursor-pointer">
            <input type="checkbox" checked={hasFirstPayment} onChange={(e) => setHasFirstPayment(e.target.checked)} />
            <span>Już zapłaciłem pierwszą ratę (utworzy transakcję historyczną)</span>
          </label>
          {hasFirstPayment && (
            <div>
              <label className={labelCls}>Data pierwszej płatności</label>
              <input type="date" className={inputCls} value={firstPaymentDate} onChange={(e) => setFirstPaymentDate(e.target.value)} />
            </div>
          )}
        </div>

        <div><label className={labelCls}>Konto (z którego pobierać)</label>
          <select className={inputCls} value={accountId} onChange={(e) => setAccountId(e.target.value)}>
            <option value="">Brak — bez pobierania z konta</option>
            {d.accounts.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}
          </select>
        </div>
        <div><label className={labelCls}>Kategoria</label>
          <select className={inputCls} value={categoryId} onChange={(e) => setCategoryId(e.target.value)}>
            <option value="">Brak</option>
            {d.categories.filter((c) => c.type === "expense").map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>
        </div>
        <div><label className={labelCls}>Notatka</label><textarea rows={2} className={inputCls} value={notes} onChange={(e) => setNotes(e.target.value)} /></div>
      </div>
    </Modal>
  );
}
