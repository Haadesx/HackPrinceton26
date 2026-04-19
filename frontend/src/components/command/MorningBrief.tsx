import { useState, useCallback } from "react";
import { Play, Pause, Square, Volume2 } from "lucide-react";
import { useVoice } from "@/hooks/useVoice";

function generateBriefText(): string {
  const today = new Date().toLocaleDateString("en-US", {
    weekday: "long",
    month: "long",
    day: "numeric",
  });

  return (
    `Good morning. Today is ${today}. ` +
    `Priority alert: 16:198:513 homework four is due next week. ` +
    `16:198:518 lab three still needs trace-backed evidence, and 16:198:536 homework three needs a clearer regularization story. ` +
    `Cross-domain insight: proof discipline from 16:198:513 supports evaluation design in 16:198:533, while model-selection discipline in 16:198:536 helps keep the final NLP paper honest. ` +
    `Leverage this connection for study efficiency.`
  );
}

const WAVEFORM_BARS = 16;

export function MorningBrief() {
  const { speak, pause, resume, stop, isPlaying, isPaused, isLoading } = useVoice();
  const [briefText] = useState(generateBriefText);

  const handleToggle = useCallback(() => {
    if (isPlaying) {
      pause();
    } else if (isPaused) {
      resume();
    } else {
      speak(briefText);
    }
  }, [briefText, isPaused, isPlaying, pause, resume, speak]);

  return (
    <div className="glass-card p-5 h-full flex flex-col">
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <Volume2 size={14} className="text-[#FFCDD6]" />
          <span className="text-[11px] font-medium tracking-[0.15em] text-white/40 uppercase">
            Mission Brief
          </span>
        </div>
        <span className="text-[10px] text-white/20 font-mono">
          {new Date().toLocaleDateString("en-US", { month: "short", day: "numeric" })}
        </span>
      </div>

      {/* Waveform */}
      <div className="flex items-center gap-3 mb-4">
        <button
          onClick={handleToggle}
          disabled={isLoading}
          className="w-10 h-10 rounded-full bg-[#CC0033]/20 border border-[#CC0033]/30 flex items-center justify-center text-[#FFCDD6] hover:bg-[#CC0033]/30 transition-all shrink-0 disabled:opacity-50"
        >
          {isPlaying ? <Pause size={14} /> : <Play size={14} className="ml-0.5" />}
        </button>
        {(isPlaying || isPaused) && (
          <button
            onClick={stop}
            className="w-10 h-10 rounded-full bg-white/[0.04] border border-white/[0.08] flex items-center justify-center text-white/50 hover:bg-white/[0.08] hover:text-white/80 transition-all shrink-0"
          >
            <Square size={14} />
          </button>
        )}

        <div className="flex items-end gap-[3px] h-8 flex-1">
          {Array.from({ length: WAVEFORM_BARS }).map((_, i) => (
            <div
              key={i}
              className="waveform-bar flex-1 min-w-0"
              style={{
                animationDelay: `${i * 0.08}s`,
                animationPlayState: isPlaying ? "running" : "paused",
                height: isPlaying ? undefined : `${20 + Math.random() * 30}%`,
                opacity: isPlaying ? 1 : isPaused ? 0.55 : 0.3,
              }}
            />
          ))}
        </div>
      </div>

      {/* Transcript */}
      <p className="text-[13px] text-white/50 leading-relaxed flex-1 overflow-auto">
        {briefText}
      </p>
    </div>
  );
}
