"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useData } from "@/lib/data-context";
import { createClient } from "@/lib/supabase/client";
import { formatCurrency } from "@/lib/format";
import { ACCOUNT_TYPE_LABEL, AccountType } from "@/lib/types";
import Modal, { inputCls, labelCls, btnPrimary, btnSecondary, btnDanger } from "@/components/Modal";
import { Plus, Trash2, Lock, UserX } from "lucide-react";

export default function SettingsPage() {
  const d = useData();
  const [openAccount, setOpenAccount] = useState(false);
  const [openPwd, setOpenPwd] = useState(false);
  const [openDelete, setOpenDelete] = useState(false);

  return (
    <div className="p-8 max-w-4xl space-y-6">
      <h1 className="text-3xl font-bold">Ustawienia</h1>

      <section className="bg-white dark:bg-zinc-900 rounded-2xl border border-zinc-200 dark:border-zinc-800 overflow-hidden">
        <div className="px-5 py-3 border-b border-zinc-200 dark:border-zinc-800 flex items-center justify-between">
          <h3 className="font-semibold">Konta finansowe</h3>
          <button onClick={() => setOpenAccount(true)} className="text-sm text-blue-500 hover:underline inline-flex items-center gap-1"><Plus className="w-4 h-4" />Dodaj konto</button>
        </div>
        {d.accounts.length === 0 ? (
          <div className="p-5 text-sm text-zinc-500">Brak kont — dodaj pierwsze.</div>
        ) : (
          <ul className="divide-y divide-zinc-100 dark:divide-zinc-800">
            {d.accounts.map((a) => (
              <li key={a.id} className="px-5 py-3 flex items-center gap-3 group">
                <div className="flex-1">
                  <div className="font-medium">{a.name}</div>
                  <div className="text-xs text-zinc-500">{ACCOUNT_TYPE_LABEL[a.type]}</div>
                </div>
                <div className="font-semibold">{formatCurrency(a.balance, a.currency)}</div>
                <button onClick={() => d.deleteAccount(a.id)} className="text-zinc-400 hover:text-red-500 opacity-0 group-hover:opacity-100"><Trash2 className="w-4 h-4" /></button>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className="bg-white dark:bg-zinc-900 rounded-2xl border border-zinc-200 dark:border-zinc-800 overflow-hidden">
        <div className="px-5 py-3 border-b border-zinc-200 dark:border-zinc-800"><h3 className="font-semibold">Kategorie</h3></div>
        <div className="grid grid-cols-2 md:grid-cols-3 gap-2 p-5">
          {d.categories.map((c) => (
            <div key={c.id} className="flex items-center gap-2 text-sm">
              <span className="w-3 h-3 rounded-full" style={{ backgroundColor: c.color }} />
              <span>{c.name}</span>
              <span className="text-xs text-zinc-400">({c.type === "expense" ? "wyd." : "przych."})</span>
            </div>
          ))}
        </div>
      </section>

      <section className="bg-white dark:bg-zinc-900 rounded-2xl border border-zinc-200 dark:border-zinc-800 overflow-hidden">
        <div className="px-5 py-3 border-b border-zinc-200 dark:border-zinc-800"><h3 className="font-semibold">Bezpieczeństwo</h3></div>
        <div className="p-2 space-y-1">
          <button onClick={() => setOpenPwd(true)} className="w-full flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-zinc-50 dark:hover:bg-zinc-800 transition text-left text-sm">
            <Lock className="w-4 h-4 text-zinc-500" />
            <span className="flex-1">Zmień hasło</span>
            <span className="text-zinc-400">›</span>
          </button>
          <button onClick={() => setOpenDelete(true)} className="w-full flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-red-50 dark:hover:bg-red-950/30 transition text-left text-sm text-red-500">
            <UserX className="w-4 h-4" />
            <span className="flex-1">Usuń konto</span>
            <span>›</span>
          </button>
        </div>
      </section>

      {openAccount && <AddAccountModal onClose={() => setOpenAccount(false)} />}
      {openPwd && <ChangePasswordModal onClose={() => setOpenPwd(false)} />}
      {openDelete && <DeleteAccountModal onClose={() => setOpenDelete(false)} />}
    </div>
  );
}

function AddAccountModal({ onClose }: { onClose: () => void }) {
  const d = useData();
  const [name, setName] = useState("");
  const [type, setType] = useState<AccountType>("checking");
  const [balance, setBalance] = useState("");

  const valid = name.trim();

  async function save() {
    if (!valid) return;
    const num = parseFloat(balance.replace(",", ".")) || 0;
    await d.addAccount({ name, type, balance: num });
    onClose();
  }

  return (
    <Modal open onClose={onClose} title="Nowe konto" footer={<>
      <button onClick={onClose} className={btnSecondary}>Anuluj</button>
      <button onClick={save} disabled={!valid} className={btnPrimary}>Zapisz</button>
    </>}>
      <div className="space-y-3">
        <div><label className={labelCls}>Nazwa</label><input className={inputCls} value={name} onChange={(e) => setName(e.target.value)} /></div>
        <div><label className={labelCls}>Typ</label>
          <select className={inputCls} value={type} onChange={(e) => setType(e.target.value as AccountType)}>
            {Object.entries(ACCOUNT_TYPE_LABEL).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
          </select>
        </div>
        <div><label className={labelCls}>Saldo początkowe</label><input className={inputCls} inputMode="decimal" placeholder="0,00" value={balance} onChange={(e) => setBalance(e.target.value)} /></div>
      </div>
    </Modal>
  );
}

function ChangePasswordModal({ onClose }: { onClose: () => void }) {
  const supabase = createClient();
  const [pwd, setPwd] = useState("");
  const [pwd2, setPwd2] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  const match = pwd === pwd2 && pwd.length >= 6;

  async function save() {
    setLoading(true); setError(null);
    const { error } = await supabase.auth.updateUser({ password: pwd });
    setLoading(false);
    if (error) { setError(error.message); return; }
    setSuccess(true);
    setTimeout(onClose, 800);
  }

  return (
    <Modal open onClose={onClose} title="Zmiana hasła" footer={<>
      <button onClick={onClose} className={btnSecondary}>Anuluj</button>
      <button onClick={save} disabled={!match || loading} className={btnPrimary}>{loading ? "Zapisuję..." : "Zapisz"}</button>
    </>}>
      <div className="space-y-3">
        <div><label className={labelCls}>Nowe hasło (min. 6 znaków)</label><input type="password" className={inputCls} value={pwd} onChange={(e) => setPwd(e.target.value)} autoFocus /></div>
        <div><label className={labelCls}>Powtórz hasło</label><input type="password" className={inputCls} value={pwd2} onChange={(e) => setPwd2(e.target.value)} /></div>
        {pwd2 && !match && <p className="text-sm text-red-500">Hasła nie pasują lub są za krótkie.</p>}
        {error && <p className="text-sm text-red-500">{error}</p>}
        {success && <p className="text-sm text-green-500">✓ Hasło zmienione</p>}
      </div>
    </Modal>
  );
}

function DeleteAccountModal({ onClose }: { onClose: () => void }) {
  const router = useRouter();
  const supabase = createClient();
  const [confirm, setConfirm] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function remove() {
    setLoading(true); setError(null);
    const { error: rpcErr } = await supabase.rpc("delete_my_account");
    if (rpcErr) { setError(rpcErr.message); setLoading(false); return; }
    await supabase.auth.signOut();
    router.push("/login");
    router.refresh();
  }

  return (
    <Modal open onClose={onClose} title="Usuń konto" footer={<>
      <button onClick={onClose} className={btnSecondary}>Anuluj</button>
      <button onClick={remove} disabled={confirm !== "USUŃ" || loading} className={btnDanger}>{loading ? "Usuwam..." : "Usuń trwale"}</button>
    </>}>
      <div className="space-y-3 text-sm">
        <p>Wszystkie Twoje dane (transakcje, subskrypcje, budżety, cele, rachunki, konta) zostaną trwale usunięte. Tej operacji nie można cofnąć.</p>
        <p>Wpisz <strong>USUŃ</strong> aby potwierdzić:</p>
        <input className={inputCls} value={confirm} onChange={(e) => setConfirm(e.target.value)} placeholder="USUŃ" />
        {error && <p className="text-red-500">{error}</p>}
      </div>
    </Modal>
  );
}
