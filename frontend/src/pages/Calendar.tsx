import { useMemo, useState } from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { useAppStore } from "@/store/useAppStore";
import type { Assignment, Course } from "@/types";

const WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

const CATEGORY_COLORS: Record<string, string> = {
  exam: "bg-orange-500/70 text-orange-100",
  quiz: "bg-amber-500/70 text-amber-100",
  project: "bg-[#CC0033]/70 text-orange-100",
  homework: "bg-blue-500/70 text-blue-100",
  lab: "bg-emerald-500/70 text-emerald-100",
};

function getDaysInMonth(year: number, month: number) {
  return new Date(year, month + 1, 0).getDate();
}

function getFirstDayOfWeek(year: number, month: number) {
  return new Date(year, month, 1).getDay();
}

interface CalendarDayProps {
  day: number | null;
  assignments: Assignment[];
  courseMap: Map<string, Course>;
  isToday: boolean;
}

function CalendarDay({ day, assignments, courseMap, isToday }: CalendarDayProps) {
  const [showAll, setShowAll] = useState(false);
  const visible = showAll ? assignments : assignments.slice(0, 3);
  const overflow = assignments.length - 3;

  return (
    <div
      className={`min-h-[90px] p-1.5 border border-white/[0.04] rounded-lg transition-colors ${
        day ? "bg-white/[0.015] hover:bg-white/[0.03]" : "bg-transparent"
      }`}
    >
      {day && (
        <>
          <div
            className={`text-[11px] font-mono mb-1 w-5 h-5 flex items-center justify-center rounded-full ${
              isToday
                ? "bg-[#CC0033] text-white font-bold"
                : "text-white/30"
            }`}
          >
            {day}
          </div>
          <div className="space-y-0.5">
            {visible.map((a) => {
              const course = courseMap.get(a.course_id);
              const catCls =
                CATEGORY_COLORS[a.assignment_category] ??
                "bg-white/10 text-white/50";
              return (
                <div
                  key={a.id}
                  title={`${a.name} — ${course?.course_code ?? a.course_id}`}
                  className={`flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] font-medium truncate cursor-default ${catCls}`}
                  style={
                    course
                      ? { backgroundColor: course.color + "33", color: course.color }
                      : {}
                  }
                >
                  <span
                    className="w-1.5 h-1.5 rounded-full shrink-0"
                    style={{ backgroundColor: course?.color ?? "#6b7280" }}
                  />
                  <span className="truncate">{a.name}</span>
                </div>
              );
            })}
            {!showAll && overflow > 0 && (
              <button
                onClick={() => setShowAll(true)}
                className="text-[10px] text-white/25 hover:text-white/50 font-mono transition-colors pl-0.5"
              >
                +{overflow} more
              </button>
            )}
          </div>
        </>
      )}
    </div>
  );
}

export function Calendar() {
  const assignments = useAppStore((s) => s.assignments);
  const courses = useAppStore((s) => s.courses);

  const today = new Date();
  const [viewYear, setViewYear] = useState(today.getFullYear());
  const [viewMonth, setViewMonth] = useState(today.getMonth());

  // Filter courses strictly by current active semester to match the lattice map
  const activeCourseIds = useMemo(() => {
    const now = new Date();
    return new Set(
      courses
        .filter((course) => {
          if (!course.start_at) return false;
          const start = new Date(course.start_at);
          const end = course.end_at ? new Date(course.end_at) : null;
          return start <= now && (!end || end >= now);
        })
        .map((c) => c.id)
    );
  }, [courses]);

  const courseMap = useMemo(() => {
    const m = new Map<string, Course>();
    courses
      .filter((c) => activeCourseIds.has(c.id))
      .forEach((c) => m.set(c.id, c));
    return m;
  }, [courses, activeCourseIds]);

  // Group assignments by day-of-month for the current view month
  const assignmentsByDay = useMemo(() => {
    const map = new Map<number, Assignment[]>();
    assignments
      .filter((a) => activeCourseIds.has(a.course_id))
      .forEach((a) => {
        if (!a.due_at) return;
        const d = new Date(a.due_at);
      if (d.getFullYear() === viewYear && d.getMonth() === viewMonth) {
        const day = d.getDate();
        if (!map.has(day)) map.set(day, []);
        map.get(day)!.push(a);
      }
    });
    // Sort each day's assignments by category priority
    const priority = { exam: 0, quiz: 1, project: 2, homework: 3, lab: 4 };
    map.forEach((list) =>
      list.sort(
        (a, b) =>
          (priority[a.assignment_category] ?? 9) -
          (priority[b.assignment_category] ?? 9)
      )
    );
    return map;
  }, [assignments, viewYear, viewMonth]);

  const daysInMonth = getDaysInMonth(viewYear, viewMonth);
  const firstDow = getFirstDayOfWeek(viewYear, viewMonth);

  // Build a 6-row grid (42 cells)
  const cells: (number | null)[] = [
    ...Array(firstDow).fill(null),
    ...Array.from({ length: daysInMonth }, (_, i) => i + 1),
  ];
  while (cells.length % 7 !== 0) cells.push(null);

  const monthName = new Date(viewYear, viewMonth, 1).toLocaleDateString("en-US", {
    month: "long",
    year: "numeric",
  });

  const prevMonth = () => {
    if (viewMonth === 0) {
      setViewMonth(11);
      setViewYear((y) => y - 1);
    } else {
      setViewMonth((m) => m - 1);
    }
  };

  const nextMonth = () => {
    if (viewMonth === 11) {
      setViewMonth(0);
      setViewYear((y) => y + 1);
    } else {
      setViewMonth((m) => m + 1);
    }
  };

  const totalThisMonth = [...assignmentsByDay.values()].reduce(
    (acc, list) => acc + list.length,
    0
  );

  return (
    <div className="flex flex-col h-full p-6 pl-[240px] gap-4">
      {/* Header */}
      <div className="flex items-center justify-between shrink-0">
        <div>
          <h1 className="text-lg font-semibold text-white/90 tracking-tight">
            {monthName}
          </h1>
          <p className="text-[11px] text-white/30 font-mono mt-0.5">
            {totalThisMonth} deadline{totalThisMonth !== 1 ? "s" : ""} this month
          </p>
        </div>

        <div className="flex items-center gap-2">
          {/* Course legend */}
          <div className="flex items-center gap-2 mr-3">
            {courses
              .filter((c) => activeCourseIds.has(c.id))
              .map((c) => (
              <div key={c.id} className="flex items-center gap-1.5">
                <span
                  className="w-2 h-2 rounded-full"
                  style={{ backgroundColor: c.color }}
                />
                <span className="text-[10px] font-mono text-white/40">
                  {c.course_code}
                </span>
              </div>
            ))}
          </div>

          <button
            onClick={prevMonth}
            className="p-1.5 rounded-lg text-white/40 hover:text-white/70 hover:bg-white/[0.06] transition-all"
          >
            <ChevronLeft size={16} />
          </button>
          <button
            onClick={() => {
              setViewYear(today.getFullYear());
              setViewMonth(today.getMonth());
            }}
            className="px-3 py-1 rounded-lg text-[11px] font-mono text-white/40 hover:text-white/70 hover:bg-white/[0.06] transition-all"
          >
            Today
          </button>
          <button
            onClick={nextMonth}
            className="p-1.5 rounded-lg text-white/40 hover:text-white/70 hover:bg-white/[0.06] transition-all"
          >
            <ChevronRight size={16} />
          </button>
        </div>
      </div>

      {/* Calendar grid */}
      <div className="flex-1 flex flex-col gap-1 min-h-0">
        {/* Weekday headers */}
        <div className="grid grid-cols-7 gap-1">
          {WEEKDAYS.map((d) => (
            <div
              key={d}
              className="text-center text-[10px] font-mono text-white/25 uppercase tracking-wider py-1"
            >
              {d}
            </div>
          ))}
        </div>

        {/* Day cells */}
        <div className="grid grid-cols-7 gap-1 flex-1">
          {cells.map((day, i) => (
            <CalendarDay
              key={i}
              day={day}
              assignments={day ? (assignmentsByDay.get(day) ?? []) : []}
              courseMap={courseMap}
              isToday={
                day !== null &&
                viewYear === today.getFullYear() &&
                viewMonth === today.getMonth() &&
                day === today.getDate()
              }
            />
          ))}
        </div>
      </div>
    </div>
  );
}
