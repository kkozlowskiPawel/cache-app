"use client";

import { useState } from "react";
import { useData } from "@/lib/data-context";
import { formatCurrency } from "@/lib/format";
import Modal, { inputCls, labelCls, btnPrimary, btnSecondary } from "@/components/Modal";
import { Plus, Trash2 } from "lucide-react";
import type { Goal } from "@/lib/types";

const ICONS = ["🎯", "🏠", "🚗", "✈️", "🎓", "🎁", "❤️", "⭐"];
const COLORS = ["#007AFF", "#34C759", "#FF9500", "#FF2D55", "#AF52DE", "#5856D6", "#FF3B30"];

export default function GoalsPage() {
  const d = useData();
  const [open, setOpen] = useState(false);

  return (
    <div className="p-8 max-w-4xl">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-3xl font-bold">Cele</h1>
        <button onClick={() => setOpen(true)} className={btnPrimary}>
          <span className="inline-flex items-center gap-2"><Plus className="w-4 h-4" />Nowy cel</span>
        </button>
      </div>

      {d.goals.length === 0 ? (
        <div className="text-center py-20 text-zinc-500">Brak celów. Dodaj pierwszy.</div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {d.goals.map((g) => <GoalCard key={g.id} goal={g} />)}
        </div>
      )}

      {open && <AddGoalModal onClose={() => setOpen(false)} />}
    </div>
  );
}

function GoalCard({ goal }: { goal: Goal }) {
  const d = useData();
  const [edit, setEdit] = useState(false);
  const [val, setVal] = useState("");

  const progress = goal.target_amount > 0 ? Math.min((goal.current_amount / goal.target_amount) * 100, 100) : 0;

  async function update() {
    const num = parseFloat(val.replace(",", "."));
    if (!isNaN(num)) await d.updateGoalCurrent(goal.id, num);
    setEdit(false);
  }

  return (
    <div className="bg-white dark:bg-zinc-900 rounded-2xl border border-zinc-200 dark:border-zinc-800 p-5 group relative">
      <button onClick={() => d.deleteGoal(goal.id)} className="absolute top-3 right-3 text-zinc-400 hover:text-red-500 opacity-0 group-hover:opacity-100 transition"><Trash2 className="w-4 h-4" /></button>
      <div className="flex items-center gap-2 mb-3">
        <span className="text-2xl">{goal.icon.startsWith("#") || goal.icon.length > 2 ? "🎯" : goal.icon}</span>
        <h3 className="font-semibold">{goal.name}</h3>
        <span className="ml-auto text-sm text-zinc-500">{Math.round(progress)}%</span>
      </div>
      <div className="h-2 rounded-full bg-zinc-100 dark:bg-zinc-800 overflow-hidden mb-2">
        <div className="h-full transition-all" style={{ width: `${progress}%`, backgroundColor: goal.color }} />
      </div>
      <div className="flex items-center justify-between text-sm">
        <span className="text-zinc-500">{formatCurrency(goal.current_amount)} / {formatCurrency(goal.target_amount)}</span>
        <button onClick={() => { setVal(String(goal.current_amount > 0 ? goal.current_amount : "")); setEdit(true); }} className="text-blue-500 hover:underline">Aktualizuj</button>
      </div>

      {edit && (
        <Modal open onClose={() => setEdit(false)} title="Aktualizuj kwotę" footer={<>
          <button onClick={() => setEdit(false)} className={btnSecondary}>Anuluj</button>
          <button onClick={update} className={btnPrimary}>Zapisz</button>
        </>}>
          <input className={inputCls} inputMode="decimal" placeholder="Kwota" value={val} onChange={(e) => setVal(e.target.value)} />
        </Modal>
      )}
    </div>
  );
}

function AddGoalModal({ onClose }: { onClose: () => void }) {
  const d = useData();
  const [name, setName] = useState("");
  const [target, setTarget] = useState("");
  const [current, setCurrent] = useState("");
  const [hasDate, setHasDate] = useState(false);
  const [date, setDate] = useState("");
  const [icon, setIcon] = useState(ICONS[0]);
  const [color, setColor] = useState(COLORS[0]);

  const t = parseFloat(target.replace(",", "."));
  const c = parseFloat(current.replace(",", ".")) || 0;
  const valid = name.trim() && !isNaN(t) && t > 0;

  async function save() {
    if (!valid) return;
    await d.addGoal({ name, target: t, current: c, targetDate: hasDate ? date : null, icon, color });
    onClose();
  }

  return (
    <Modal open onClose={onClose} title="Nowy cel" footer={<>
      <button onClick={onClose} className={btnSecondary}>Anuluj</button>
      <button onClick={save} disabled={!valid} className={btnPrimary}>Zapisz</button>
    </>}>
      <div className="space-y-3">
        <div><label className={labelCls}>Nazwa</label><input className={inputCls} value={name} onChange={(e) => setName(e.target.value)} placeholder="np. Wakacje" /></div>
        <div className="grid grid-cols-2 gap-3">
          <div><label className={labelCls}>Kwota docelowa</label><input className={inputCls} inputMode="decimal" placeholder="0,00" value={target} onChange={(e) => setTarget(e.target.value)} /></div>
          <div><label className={labelCls}>Już odłożone</label><input className={inputCls} inputMode="decimal" placeholder="opcjonalnie" value={current} onChange={(e) => setCurrent(e.target.value)} /></div>
        </div>
        <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={hasDate} onChange={(e) => setHasDate(e.target.checked)} />Termin</label>
        {hasDate && <input type="date" className={inputCls} value={date} onChange={(e) => setDate(e.target.value)} />}
        <div><label className={labelCls}>Ikona</label>
          <div className="flex gap-2 flex-wrap">{ICONS.map((i) => <button key={i} type="button" onClick={() => setIcon(i)} className={`w-10 h-10 rounded-full text-xl flex items-center justify-center ${icon === i ? "ring-2 ring-blue-500" : "bg-zinc-100 dark:bg-zinc-800"}`}>{i}</button>)}</div>
        </div>
        <div><label className={labelCls}>Kolor</label>
          <div className="flex gap-2">{COLORS.map((c) => <button key={c} type="button" onClick={() => setColor(c)} className={`w-8 h-8 rounded-full ${color === c ? "ring-2 ring-offset-2 ring-zinc-700 dark:ring-zinc-200" : ""}`} style={{ backgroundColor: c }} />)}</div>
        </div>
      </div>
    </Modal>
  );
}
