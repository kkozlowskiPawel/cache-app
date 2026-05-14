"use client";

import { useMemo, useState } from "react";
import {
  addMonths, eachDayOfInterval, endOfMonth, endOfWeek, format,
  isSameDay, isSameMonth, isToday, startOfMonth, startOfWeek, subMonths,
} from "date-fns";
import { pl } from "date-fns/locale";
import { ChevronLeft, ChevronRight } from "lucide-react";

interface Props {
  dailyTotals: Record<string, number>;
  selectedDate: Date | null;
  onSelectDate: (date: Date | null) => void;
}

const WEEKDAYS = ["pon", "wt", "śr", "czw", "pt", "sob", "ndz"];

function compact(value: number): string {
  if (value >= 1000) return (value / 1000).toFixed(1) + "k";
  return Math.round(value).toString();
}

export default function ExpenseCalendar({ dailyTotals, selectedDate, onSelectDate }: Props) {
  const [visibleMonth, setVisibleMonth] = useState<Date>(new Date());

  const days = useMemo(() => {
    const monthStart = startOfMonth(visibleMonth);
    const monthEnd = endOfMonth(visibleMonth);
    const gridStart = startOfWeek(monthStart, { weekStartsOn: 1 });
    const gridEnd = endOfWeek(monthEnd, { weekStartsOn: 1 });
    return eachDayOfInterval({ start: gridStart, end: gridEnd });
  }, [visibleMonth]);

  return (
    <div>
      <div className="flex items-center justify-between mb-3">
        <button
          onClick={() => setVisibleMonth(subMonths(visibleMonth, 1))}
          className="p-1.5 rounded-lg hover:bg-zinc-100 dark:hover:bg-zinc-800 transition"
          aria-label="Poprzedni miesiąc"
        >
          <ChevronLeft className="w-4 h-4" />
        </button>
        <h4 className="font-semibold capitalize">
          {format(visibleMonth, "LLLL yyyy", { locale: pl })}
        </h4>
        <button
          onClick={() => setVisibleMonth(addMonths(visibleMonth, 1))}
          className="p-1.5 rounded-lg hover:bg-zinc-100 dark:hover:bg-zinc-800 transition"
          aria-label="Następny miesiąc"
        >
          <ChevronRight className="w-4 h-4" />
        </button>
      </div>

      <div className="grid grid-cols-7 gap-1 mb-1">
        {WEEKDAYS.map((w) => (
          <div key={w} className="text-center text-xs text-zinc-500 font-medium py-1">{w}</div>
        ))}
      </div>

      <div className="grid grid-cols-7 gap-1">
        {days.map((day) => {
          const key = format(day, "yyyy-MM-dd");
          const total = dailyTotals[key] ?? 0;
          const inMonth = isSameMonth(day, visibleMonth);
          const isSel = !!(selectedDate && isSameDay(day, selectedDate));
          const isCur = isToday(day);

          const cls = [
            "aspect-square rounded-lg flex flex-col items-center justify-center relative text-sm transition",
            inMonth ? "text-zinc-900 dark:text-zinc-100" : "text-zinc-300 dark:text-zinc-600",
            isSel
              ? "bg-blue-500 text-white"
              : "hover:bg-zinc-100 dark:hover:bg-zinc-800",
            isCur && !isSel ? "ring-2 ring-blue-500 ring-inset" : "",
          ].join(" ");

          return (
            <button
              key={key}
              onClick={() => onSelectDate(isSel ? null : day)}
              className={cls}
            >
              <span className={isSel ? "text-white font-semibold" : ""}>{format(day, "d")}</span>
              {total > 0 && inMonth && (
                <span className={["text-[9px] font-semibold leading-none mt-0.5", isSel ? "text-white/90" : "text-red-500"].join(" ")}>
                  -{compact(total)}
                </span>
              )}
            </button>
          );
        })}
      </div>
    </div>
  );
}
