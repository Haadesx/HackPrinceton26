import { useMemo } from "react";
import { Sun, Volume2, VolumeX, Loader2, Pause, Play } from "lucide-react";
import { useVoice } from "../../hooks/useVoice";
import { useAppStore } from "../../store/useAppStore";
import type { Assignment } from "../../types";

function buildBriefText(assignments: Assignment[], courses: { id: string; course_code: string }[]): string {
  const today = new Date();
  const dateStr = today.toLocaleDateString("en-US", {
    weekday: "long",
    month: "long",
    day: "numeric",
  });

  const nextWeek = new Date(today);
  nextWeek.setDate(nextWeek.getDate() + 7);

  const courseMap = new Map(courses.map((c) => [c.id, c.course_code]));
  const upcoming = assignments
    .filter((a) => !a.has_submitted_submissions && new Date(a.due_at) <= nextWeek)
    .sort((a, b) => new Date(a.due_at).getTime() - new Date(b.due_at).getTime());

  if (upcoming.length === 0) {
    return `Good morning! Today is ${dateStr}. You have no deadlines in the next 7 days — great time to get ahead on studying.`;
  }

  const items = upcoming
    .map((a) => {
      const due = new Date(a.due_at);
      const diffDays = Math.ceil((due.getTime() - today.getTime()) / 86400000);
      const when = diffDays <= 0 ? "today" : diffDays === 1 ? "tomorrow" : `in ${diffDays} days`;
      return `${courseMap.get(a.course_id) ?? a.course_id} ${a.name} is due ${when}`;
    })
    .join(". ");

  return `Good morning! Today is ${dateStr}. ${items}. Stay focused and good luck!`;
}

export function DailyBrief() {
  const { speak, pause, resume, stop, isPlaying, isPaused, isLoading } = useVoice();
  const assignments = useAppStore((s) => s.assignments);
  const courses = useAppStore((s) => s.courses);

  const briefText = useMemo(
    () => buildBriefText(assignments, courses),
    [assignments, courses],
  );

  const handlePlay = () => {
    if (isPlaying) {
      pause();
    } else if (isPaused) {
      resume();
    } else {
      speak(briefText);
    }
  };

  return (
    <div className="rounded-xl border border-white/10 bg-white/5 p-5">
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-2">
          <Sun size={20} className="text-amber-400" />
          <h3 className="text-lg font-semibold text-white">Daily Brief</h3>
        </div>
        <button
          onClick={handlePlay}
          disabled={isLoading}
          className="flex items-center gap-2 px-3 py-1.5 rounded-lg transition-colors bg-[#E77500] hover:bg-[#FF8F00] text-white text-sm font-medium disabled:opacity-50"
        >
          {isLoading ? (
            <Loader2 size={16} className="animate-spin" />
          ) : isPlaying ? (
            <Pause size={16} />
          ) : isPaused ? (
            <Play size={16} />
          ) : (
            <Volume2 size={16} />
          )}
          {isPlaying ? "Pause" : isPaused ? "Resume" : "Listen"}
        </button>
        {(isPlaying || isPaused) && (
          <button
            onClick={stop}
            className="flex items-center gap-2 px-3 py-1.5 rounded-lg transition-colors bg-white/5 hover:bg-white/10 text-white/70 text-sm font-medium"
          >
            <VolumeX size={16} />
            Stop
          </button>
        )}
      </div>
      <p className="text-sm text-gray-300 leading-relaxed">{briefText}</p>
    </div>
  );
}
