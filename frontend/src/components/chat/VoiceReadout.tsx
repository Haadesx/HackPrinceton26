import { Volume2, VolumeX, Loader2, Pause, Play } from "lucide-react";
import { useVoice } from "../../hooks/useVoice";

interface VoiceReadoutProps {
  text: string;
}

export function VoiceReadout({ text }: VoiceReadoutProps) {
  const { speak, pause, resume, stop, isPlaying, isPaused, isLoading } = useVoice();

  const handleClick = () => {
    if (isPlaying) {
      pause();
    } else if (isPaused) {
      resume();
    } else {
      speak(text);
    }
  };

  return (
    <div className="flex items-center gap-1">
      <button
        onClick={handleClick}
        disabled={isLoading}
        title={isPlaying ? "Pause" : isPaused ? "Resume" : "Read aloud"}
        className="p-1.5 rounded-md transition-colors text-gray-400 hover:text-white hover:bg-white/10 disabled:opacity-50"
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
      </button>
      {(isPlaying || isPaused) && (
        <button
          onClick={stop}
          title="Stop"
          className="p-1.5 rounded-md transition-colors text-gray-400 hover:text-white hover:bg-white/10"
        >
          <VolumeX size={16} />
        </button>
      )}
    </div>
  );
}
