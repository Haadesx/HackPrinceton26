import { X, BookOpen, MessageSquare, Cpu, Loader2 } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { useAppStore } from "@/store/useAppStore";
import { useCallback, useState } from "react";
import { apiPost } from "@/lib/api";


interface InspectorPanelProps {
  onClose: () => void;
}

export function InspectorPanel({ onClose }: InspectorPanelProps) {
  const selectedConceptId = useAppStore((s) => s.selectedConceptId);
  const concepts = useAppStore((s) => s.concepts);
  const connections = useAppStore((s) => s.connections);
  const courses = useAppStore((s) => s.courses);
  const setPendingChatPrompt = useAppStore((s) => s.setPendingChatPrompt);
  const setPendingStudyTopic = useAppStore((s) => s.setPendingStudyTopic);
  const setChatModalOpen = useAppStore((s) => s.setChatModalOpen);
  const setStudyLabModalOpen = useAppStore((s) => s.setStudyLabModalOpen);

  const [buildingAgent, setBuildingAgent] = useState(false);
  const conceptArtifacts = useAppStore((s) => s.conceptArtifacts);
  const setConceptArtifact = useAppStore((s) => s.setConceptArtifact);

  const concept = concepts.find((c) => c.id === selectedConceptId);
  if (!concept) return null;

  const agentUrl = conceptArtifacts[concept.id]?.agentUrl ?? null;

  const handleStudy = useCallback(() => {
    setPendingStudyTopic(concept.label);
    setStudyLabModalOpen(true);
  }, [concept.label, setPendingStudyTopic, setStudyLabModalOpen]);

  const handleAskAI = useCallback(() => {
    setPendingChatPrompt(`Explain ${concept.label}`);
    setChatModalOpen(true);
  }, [concept.label, setPendingChatPrompt, setChatModalOpen]);

  const handleBuildAgent = useCallback(async () => {
    setBuildingAgent(true);
    try {
      const res = await apiPost<{ status: string; agent_url?: string | null }>(
        "/knowledge/build-context",
        { concept_id: concept.id }
      );
      if (res.agent_url) {
        setConceptArtifact(concept.id, { agentUrl: res.agent_url });
      }
    } catch (e) {
      console.error("Agent build failed:", e);
    } finally {
      setBuildingAgent(false);
    }
  }, [concept.id, setConceptArtifact]);

  const course = courses.find((c) => c.id === concept.course_id);
  const color = course?.color ?? "#6b7280";

  // Find connected concepts
  const connectedIds = new Set<string>();
  connections.forEach((conn) => {
    if (conn.source_id === concept.id) connectedIds.add(conn.target_id);
    if (conn.target_id === concept.id) connectedIds.add(conn.source_id);
  });
  const connectedConcepts = concepts.filter((c) => connectedIds.has(c.id));

  return (
    <div className="fixed top-6 right-6 w-[280px] z-50 animate-fade-in-up">
      <div className="glass-card p-5">
        {/* Header */}
        <div className="flex items-start justify-between mb-4">
          <div>
            <Badge
              variant="outline"
              className="text-[10px] font-mono mb-2"
              style={{
                background: `${color}15`,
                color,
                borderColor: `${color}30`,
              }}
            >
              {course?.course_code ?? concept.course_id.toUpperCase()}
            </Badge>
            <h3 className="text-sm font-medium text-white/90">
              {concept.label}
            </h3>
          </div>
          <button
            onClick={onClose}
            className="p-1 rounded-md text-white/30 hover:text-white/60 hover:bg-white/[0.06] transition-colors"
          >
            <X size={14} />
          </button>
        </div>

        {/* Description */}
        <p className="text-[12px] text-white/50 leading-relaxed mb-4">
          {concept.description}
        </p>

        {/* Mastery */}
        <div className="mb-4">
          <div className="flex items-center justify-between mb-1.5">
            <span className="text-[10px] text-white/30 font-mono uppercase">Mastery</span>
            <span className="text-[11px] font-mono" style={{ color }}>
              {concept.mastery}%
            </span>
          </div>
          <div className="w-full h-1.5 rounded-full bg-white/[0.06]">
            <div
              className="h-full rounded-full transition-all duration-500"
              style={{ width: `${concept.mastery}%`, background: color }}
            />
          </div>
        </div>

        {/* Connected Concepts */}
        {connectedConcepts.length > 0 && (
          <div className="mb-4">
            <span className="text-[10px] text-white/30 font-mono uppercase block mb-2">
              Linked Concepts
            </span>
            <div className="flex flex-wrap gap-1">
              {connectedConcepts.map((c) => (
                <span
                  key={c.id}
                  className="text-[10px] px-2 py-0.5 rounded-full border border-white/[0.06] text-white/40"
                >
                  {c.label}
                </span>
              ))}
            </div>
          </div>
        )}

        {/* Actions */}
        <div className="flex gap-2">
          <Button
            size="sm"
            variant="outline"
            onClick={handleStudy}
            className="flex-1 text-[11px] border-white/[0.08] text-white/50 hover:text-white hover:bg-white/[0.06]"
          >
            <BookOpen size={12} className="mr-1.5" />
            Study
          </Button>
          <Button
            size="sm"
            variant="outline"
            onClick={handleAskAI}
            className="flex-1 text-[11px] border-white/[0.08] text-white/50 hover:text-white hover:bg-white/[0.06]"
          >
            <MessageSquare size={12} className="mr-1.5" />
            Ask AI
          </Button>
        </div>
        {agentUrl ? (
          <a
            href={agentUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="mt-2 w-full flex items-center justify-center gap-1.5 px-3 py-1.5 rounded-lg text-[11px] font-mono tracking-wider uppercase bg-orange-500/20 text-orange-300 hover:bg-orange-500/30 transition-all border border-orange-500/20"
          >
            <Cpu size={12} />
            Chat with Specialized Agent
          </a>
        ) : (
          <>
            <Button
              size="sm"
              variant="outline"
              onClick={handleBuildAgent}
              disabled={buildingAgent}
              className="w-full mt-2 text-[11px] border-orange-500/20 text-orange-400/70 hover:text-orange-300 hover:bg-orange-500/10"
            >
              {buildingAgent ? (
                <><Loader2 size={12} className="mr-1.5 animate-spin" />Building Agent...</>
              ) : (
                <><Cpu size={12} className="mr-1.5" />Deploy Knowledge Agent v2</>
              )}
            </Button>
            {buildingAgent && (
              <p className="text-[10px] text-center mt-1 text-white/40">Generating knowledge doc...</p>
            )}
          </>
        )}
      </div>
    </div>
  );
}
