import { useEffect, useRef, useState, useCallback } from "react";

const API_BASE = "http://localhost:8000";

export function useVoice() {
  const [isPlaying, setIsPlaying] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const objectUrlRef = useRef<string | null>(null);
  const utteranceRef = useRef<SpeechSynthesisUtterance | null>(null);
  const modeRef = useRef<"audio" | "speech" | null>(null);

  const releaseObjectUrl = useCallback(() => {
    if (objectUrlRef.current) {
      URL.revokeObjectURL(objectUrlRef.current);
      objectUrlRef.current = null;
    }
  }, []);

  const stop = useCallback(() => {
    if (audioRef.current) {
      audioRef.current.pause();
      audioRef.current.currentTime = 0;
      audioRef.current = null;
    }
    if ("speechSynthesis" in window) {
      window.speechSynthesis.cancel();
    }
    utteranceRef.current = null;
    modeRef.current = null;
    releaseObjectUrl();
    setIsPlaying(false);
    setIsPaused(false);
  }, [releaseObjectUrl]);

  const pause = useCallback(() => {
    if (modeRef.current === "audio" && audioRef.current && !audioRef.current.paused) {
      audioRef.current.pause();
      return;
    }

    if (modeRef.current === "speech" && "speechSynthesis" in window && window.speechSynthesis.speaking) {
      window.speechSynthesis.pause();
      setIsPlaying(false);
      setIsPaused(true);
    }
  }, []);

  const resume = useCallback(() => {
    if (modeRef.current === "audio" && audioRef.current && audioRef.current.paused) {
      void audioRef.current.play();
      return;
    }

    if (modeRef.current === "speech" && "speechSynthesis" in window && window.speechSynthesis.paused) {
      window.speechSynthesis.resume();
      setIsPlaying(true);
      setIsPaused(false);
    }
  }, []);

  const speak = useCallback(
    async (text: string) => {
      // Stop any currently playing audio
      stop();

      setIsLoading(true);

      try {
        const res = await fetch(`${API_BASE}/api/voice`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ text }),
        });

        if (!res.ok) {
          throw new Error(`Voice API error: ${res.status}`);
        }

        const blob = await res.blob();
        const url = URL.createObjectURL(blob);
        objectUrlRef.current = url;

        const audio = new Audio(url);
        audioRef.current = audio;
        modeRef.current = "audio";

        audio.onplay = () => {
          setIsPlaying(true);
          setIsPaused(false);
        };
        audio.onpause = () => {
          if (!audio.ended && audio.currentTime > 0) {
            setIsPlaying(false);
            setIsPaused(true);
          }
        };
        audio.onended = () => {
          setIsPlaying(false);
          setIsPaused(false);
          audioRef.current = null;
          modeRef.current = null;
          releaseObjectUrl();
        };
        audio.onerror = () => {
          setIsPlaying(false);
          setIsPaused(false);
          audioRef.current = null;
          modeRef.current = null;
          releaseObjectUrl();
        };

        await audio.play();
      } catch {
        // Fallback to browser speech synthesis
        fallbackSpeak(text, {
          onStart: () => {
            modeRef.current = "speech";
            setIsPlaying(true);
            setIsPaused(false);
          },
          onPause: () => {
            setIsPlaying(false);
            setIsPaused(true);
          },
          onResume: () => {
            setIsPlaying(true);
            setIsPaused(false);
          },
          onEnd: () => {
            utteranceRef.current = null;
            modeRef.current = null;
            setIsPlaying(false);
            setIsPaused(false);
          },
          onError: () => {
            utteranceRef.current = null;
            modeRef.current = null;
            setIsPlaying(false);
            setIsPaused(false);
          },
          setUtterance: (utterance) => {
            utteranceRef.current = utterance;
          },
        });
      } finally {
        setIsLoading(false);
      }
    },
    [releaseObjectUrl, stop]
  );

  useEffect(() => stop, [stop]);

  return { speak, stop, pause, resume, isPlaying, isPaused, isLoading };
}

function fallbackSpeak(
  text: string,
  handlers: {
    onStart: () => void;
    onPause: () => void;
    onResume: () => void;
    onEnd: () => void;
    onError: () => void;
    setUtterance: (utterance: SpeechSynthesisUtterance) => void;
  },
) {
  if (!("speechSynthesis" in window)) return;

  window.speechSynthesis.cancel();
  const utterance = new SpeechSynthesisUtterance(text);
  utterance.rate = 1;
  utterance.pitch = 1;
  utterance.onstart = handlers.onStart;
  utterance.onpause = handlers.onPause;
  utterance.onresume = handlers.onResume;
  utterance.onend = handlers.onEnd;
  utterance.onerror = handlers.onError;
  handlers.setUtterance(utterance);
  window.speechSynthesis.speak(utterance);
}
