"use client";

import { useEffect, useState } from "react";
import { useData } from "@/lib/data-context";
import { formatCurrency, formatDate, todayISO } from "@/lib/format";
import { getLastAccountId, setLastAccountId } from "@/lib/last-account";
import Modal, { inputCls, labelCls, btnPrimary, btnSecondary } from "@/components/Modal";
import { Plus, Trash2, Pencil } from "lucide-react";
import type { Transaction } from "@/lib/types";

export default function TransactionsPage() {
  const d = useData();
  const [openAdd, setOpenAdd] = useState(false);
  const [editing, setEditing] = useState<Transaction | null>(null);

  const grouped = d.transactions.reduce<Record<string, typeof d.transactions>>((acc, t) => {
    (acc[t.date] ??= []).push(t);
    return acc;
  }, {});
  const days = Object.keys(grouped).sort((a, b) => b.localeCompare(a));

  return (
    <div className="p-8 max-w-4xl">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-3xl font-bold">Wydatki</h1>
        <button onClick={() => setOpenAdd(true)} className={btnPrimary}>
          <span className="inline-flex items-center gap-2"><Plus className="w-4 h-4" />Nowa transakcja</span>
        </button>
      </div>

      {d.transactions.length === 0 ? (
        <div className="text-center py-20 text-zinc-500">
          Brak transakcji. Dodaj pierwszą przyciskiem &quot;Nowa transakcja&quot;.
        </div>
      ) : (
        <div className="space-y-6">
          {days.map((day) => (
            <div key={day}>
              <h3 className="text-sm font-medium text-zinc-500 mb-2">{formatDate(day)}</h3>
              <ul className="bg-white dark:bg-zinc-900 rounded-2xl border border-zinc-200 dark:border-zinc-800 overflow-hidden divide-y divide-zinc-100 dark:divide-zinc-800">
                {grouped[day].map((t) => {
                  const cat = d.categoryById(t.category_id);
                  const acc = d.accountById(t.account_id);
                  return (
                    <li key={t.id} className="flex items-center gap-3 px-4 py-3 group hover:bg-zinc-50 dark:hover:bg-zinc-800/50 cursor-pointer" onClick={() => setEditing(t)}>
                      <div className="w-9 h-9 rounded-full flex items-center justify-center text-xs font-bold" style={{ backgroundColor: (cat?.color ?? "#8E8E93") + "33", color: cat?.color ?? "#8E8E93" }}>
                        {cat?.name?.[0] ?? "—"}
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="font-medium truncate">{t.description || cat?.name || "—"}</div>
                        {acc && <div className="text-xs text-zinc-500">{acc.name}</div>}
                      </div>
                      <div className={`font-semibold tabular-nums ${t.amount < 0 ? "text-red-500" : "text-green-500"}`}>{formatCurrency(t.amount)}</div>
                      <button onClick={(e) => { e.stopPropagation(); setEditing(t); }} className="opacity-0 group-hover:opacity-100 text-zinc-400 hover:text-blue-500 transition" title="Edytuj"><Pencil className="w-4 h-4" /></button>
                      <button onClick={(e) => { e.stopPropagation(); d.deleteTransaction(t.id); }} className="opacity-0 group-hover:opacity-100 text-zinc-400 hover:text-red-500 transition" title="Usuń"><Trash2 className="w-4 h-4" /></button>
                    </li>
                  );
                })}
              </ul>
            </div>
          ))}
        </div>
      )}

      {openAdd && <TransactionEditorModal onClose={() => setOpenAdd(false)} />}
      {editing && <TransactionEditorModal editing={editing} onClose={() => setEditing(null)} />}
    </div>
  );
}

function TransactionEditorModal({ editing, onClose }: { editing?: Transaction; onClose: () => void }) {
  const d = useData();
  const isEdit = !!editing;

  const [isExpense, setIsExpense] = useState(editing ? editing.amount < 0 : true);
  const [amount, setAmount] = useState(editing ? String(Math.abs(editing.amount)) : "");
  const [description, setDescription] = useState(editing?.description ?? "");
  const [date, setDate] = useState(editing?.date ?? todayISO());
  const [categoryId, setCategoryId] = useState<string>(editing?.category_id ?? "");
  const [accountId, setAccountId] = useState<string>(editing?.account_id ?? "");
  const [justSaved, setJustSaved] = useState(false);

  useEffect(() => {
    if (isEdit) return;
    const last = getLastAccountId();
    if (last && d.accounts.some((a) => a.id === last)) setAccountId(last);
  }, [d.accounts, isEdit]);

  const cats = d.categories.filter((c) => c.type === (isExpense ? "expense" : "income"));
  const num = parseFloat(amount.replace(",", "."));
  const valid = !isNaN(num) && num > 0;

  async function performSave(): Promise<boolean> {
    if (!valid) return false;
    const signed = isExpense ? -Math.abs(num) : Math.abs(num);
    if (editing) {
      await d.updateTransaction(editing.id, {
        amount: signed, description, date,
        categoryId: categoryId || null, accountId: accountId || null,
      });
    } else {
      await d.addTransaction({
        amount: signed, description, date,
        categoryId: categoryId || null, accountId: accountId || null,
      });
    }
    if (accountId) setLastAccountId(accountId);
    return true;
  }

  async function saveAndClose() {
    if (await performSave()) onClose();
  }

  async function saveAndAddAnother() {
    if (await performSave()) {
      setAmount("");
      setDescription("");
      setJustSaved(true);
      setTimeout(() => setJustSaved(false), 1500);
    }
  }

  return (
    <Modal open onClose={onClose} title={isEdit ? "Edytuj transakcję" : "Nowa transakcja"} footer={<>
      <button onClick={onClose} className={btnSecondary}>Anuluj</button>
      {!isEdit && <button onClick={saveAndAddAnother} disabled={!valid} className={btnSecondary}>Zapisz i dodaj kolejny</button>}
      <button onClick={saveAndClose} disabled={!valid} className={btnPrimary}>Zapisz</button>
    </>}>
      <div className="space-y-3">
        {justSaved && <div className="text-sm text-green-600 dark:text-green-400">✓ Zapisano — wpisz kolejną</div>}
        <div className="grid grid-cols-2 gap-1 p-1 bg-zinc-100 dark:bg-zinc-800 rounded-lg">
          <button onClick={() => setIsExpense(true)}  className={`py-1.5 rounded-md text-sm font-medium ${isExpense ? "bg-white dark:bg-zinc-700 shadow-sm" : ""}`}>Wydatek</button>
          <button onClick={() => setIsExpense(false)} className={`py-1.5 rounded-md text-sm font-medium ${!isExpense ? "bg-white dark:bg-zinc-700 shadow-sm" : ""}`}>Przychód</button>
        </div>
        <div><label className={labelCls}>Kwota</label><input className={inputCls} inputMode="decimal" placeholder="0,00" value={amount} onChange={(e) => setAmount(e.target.value)} autoFocus /></div>
        <div><label className={labelCls}>Opis</label><input className={inputCls} value={description} onChange={(e) => setDescription(e.target.value)} placeholder="opcjonalnie" /></div>
        <div><label className={labelCls}>Data</label><input className={inputCls} type="date" value={date} onChange={(e) => setDate(e.target.value)} /></div>
        <div><label className={labelCls}>Kategoria</label>
          <select className={inputCls} value={categoryId} onChange={(e) => setCategoryId(e.target.value)}>
            <option value="">Brak</option>
            {cats.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>
        </div>
        <div><label className={labelCls}>Konto</label>
          <select className={inputCls} value={accountId} onChange={(e) => setAccountId(e.target.value)}>
            <option value="">Brak</option>
            {d.accounts.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}
          </select>
        </div>
      </div>
    </Modal>
  );
}
