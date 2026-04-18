import { useCallback } from "react";
import { useAppStore } from "../store/useAppStore";
import { useCommandStore } from "../store/useCommandStore";
import { apiPostRaw } from "../lib/api";
import { evaluateAndSetShouldSpeak } from "../lib/voice-controller";
import type { ChatMessage } from "../types";

let messageCounter = 0;
function nextId() {
  return `msg-${Date.now()}-${++messageCounter}`;
}

export function useChat() {
  const messages = useAppStore((s) => s.chatMessages);
  const loading = useAppStore((s) => s.chatLoading);
  const addMessage = useAppStore((s) => s.addChatMessage);
  const updateLast = useAppStore((s) => s.updateLastAssistantMessage);
  const setLoading = useAppStore((s) => s.setChatLoading);
  const clearChat = useAppStore((s) => s.clearChat);
  const activeCourseId = useAppStore((s) => s.activeCourseId);
  const concepts = useAppStore((s) => s.concepts);
  const assignments = useAppStore((s) => s.assignments);
  const courses = useAppStore((s) => s.courses);

  const send = useCallback(
    async (text: string) => {
      if (!text.trim() || loading) return;

      const userMsg: ChatMessage = {
        id: nextId(),
        role: "user",
        content: text,
        timestamp: new Date().toISOString(),
      };
      addMessage(userMsg);

      const assistantMsg: ChatMessage = {
        id: nextId(),
        role: "assistant",
        content: "",
        timestamp: new Date().toISOString(),
      };
      addMessage(assistantMsg);
      setLoading(true);

      try {
        const allMessages = useAppStore
          .getState()
          .chatMessages.slice(0, -1) // exclude the empty assistant placeholder
          .map((m) => ({ role: m.role, content: m.content }));

        const { triageStatuses, systemStatus, activeRemediation } =
          useCommandStore.getState();

        const now = Date.now();
        const courseMap = Object.fromEntries(
          useAppStore.getState().courses.map((c) => [c.id, c.course_code])
        );
        const { triageStatuses: ts } = useCommandStore.getState();
        const upcomingDeadlines = useAppStore
          .getState()
          .assignments.filter((a) => {
            if (!a.due_at) return false;
            const daysLeft = (new Date(a.due_at).getTime() - now) / 86400000;
            return daysLeft >= -1 && daysLeft <= 14 && a.workflow_state === "published";
          })
          .sort((a, b) => new Date(a.due_at).getTime() - new Date(b.due_at).getTime())
          .map((a) => ({
            title: a.name,
            course_code: courseMap[a.course_id] ?? a.course_id,
            category: a.assignment_category,
            due_at: a.due_at,
            days_left: Math.ceil((new Date(a.due_at).getTime() - now) / 86400000),
            priority: a.priority ?? "medium",
            status: a.status ?? "upcoming",
            triage: ts[a.id] ?? null,
          }));

        const storeState = useAppStore.getState();
        const conceptById = Object.fromEntries(
          storeState.concepts.map((c) => [c.id, c])
        );
        const graphContext = storeState.concepts.map((c) => ({
          id: c.id,
          label: c.label,
          course_id: c.course_id,
          mastery: c.mastery,
        }));
        const graphConnections = storeState.connections
          .map((conn) => {
            const src = conceptById[conn.source_id];
            const tgt = conceptById[conn.target_id];
            if (!src || !tgt) return null;
            return {
              source_label: src.label,
              source_course: src.course_id,
              relationship: conn.label,
              target_label: tgt.label,
              target_course: tgt.course_id,
              cross_course: conn.cross_course,
            };
          })
          .filter(Boolean);

        const specializedAgentUrl = useAppStore.getState().specializedAgentUrl;

        const res = await apiPostRaw("/chat", {
          messages: allMessages,
          course_context: activeCourseId ?? undefined,
          triage_statuses: triageStatuses,
          system_status: systemStatus,
          active_remediation: activeRemediation ?? undefined,
          upcoming_deadlines: upcomingDeadlines.length > 0 ? upcomingDeadlines : undefined,
          graph_context: graphContext.length > 0 ? graphContext : undefined,
          graph_connections: graphConnections.length > 0 ? graphConnections : undefined,
          agent_url: specializedAgentUrl ?? undefined,
        });

        if (!res.ok) {
          updateLast("Sorry, something went wrong. Please try again.");
          return;
        }

        const reader = res.body?.getReader();
        if (!reader) {
          updateLast("Sorry, streaming is not supported.");
          return;
        }

        const decoder = new TextDecoder();
        let accumulated = "";
        let buffer = "";

        const processLines = (text: string) => {
          for (const line of text.split("\n")) {
            const trimmed = line.trim();
            if (!trimmed.startsWith("data: ")) continue;
            const payload = trimmed.slice(6);
            if (payload === "[DONE]") continue;
            try {
              const parsed = JSON.parse(payload);
              if (parsed.content) {
                accumulated += parsed.content;
              }
            } catch {
              accumulated += payload;
            }
          }
          if (accumulated) updateLast(accumulated);
        };

        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          buffer += decoder.decode(value, { stream: true });

          const lastNewline = buffer.lastIndexOf("\n");
          if (lastNewline !== -1) {
            processLines(buffer.slice(0, lastNewline));
            buffer = buffer.slice(lastNewline + 1);
          }
        }

        // Flush remaining buffer
        if (buffer.trim()) {
          processLines(buffer);
        }
      } catch {
        updateLast("Sorry, failed to reach the server.");
      } finally {
        setLoading(false);
        const last = useAppStore.getState().chatMessages;
        const lastMsg = last[last.length - 1];
        if (lastMsg?.role === "assistant" && lastMsg.content) {
          evaluateAndSetShouldSpeak(lastMsg.content);
        }
      }
    },
    [loading, activeCourseId, addMessage, updateLast, setLoading, concepts, assignments, courses],
  );

  return { messages, loading, send, clearChat };
}
