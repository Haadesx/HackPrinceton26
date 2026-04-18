import { create } from "zustand";
import type { AppState, MasteryUpdate } from "../types";

export const useAppStore = create<AppState>((set) => ({
  courses: [],
  assignments: [],
  notes: [],
  announcements: [],
  concepts: [],
  connections: [],

  chatMessages: [],
  chatLoading: false,

  flashcards: [],
  quizQuestions: [],
  studyGuide: "",
  studyLoading: false,

  syllabi: [],
  highlightWeek: null,

  voiceInput: {
    isListening: false,
    transcript: "",
    isSpeaking: false,
    shouldSpeak: false,
  },

  activeCourseId: null,
  selectedConceptId: null,

  // Mastery tracking
  masteryHistory: [],
  conceptArtifacts: {},

  updateConceptMastery: (conceptId, delta, source) =>
    set((s) => {
      const update: MasteryUpdate = {
        conceptId,
        delta,
        source,
        timestamp: new Date().toISOString(),
      };
      return {
        masteryHistory: [...s.masteryHistory, update],
        concepts: s.concepts.map((c) =>
          c.id === conceptId
            ? {
                ...c,
                mastery: Math.min(100, Math.max(0, c.mastery + delta)),
                updated_at: update.timestamp,
              }
            : c
        ),
      };
    }),

  setConceptArtifact: (conceptId, artifact) =>
    set((s) => ({
      conceptArtifacts: {
        ...s.conceptArtifacts,
        [conceptId]: {
          ...(s.conceptArtifacts[conceptId] ?? {}),
          ...artifact,
        },
      },
    })),

  // Inspector / modal wiring
  pendingChatPrompt: null,
  pendingStudyTopic: null,
  setPendingChatPrompt: (pendingChatPrompt) => set({ pendingChatPrompt }),
  setPendingStudyTopic: (pendingStudyTopic) => set({ pendingStudyTopic }),

  // Specialized agent mode
  specializedAgentUrl: null,
  specializedAgentLabel: null,
  setSpecializedAgent: (url, label = null) => set({ specializedAgentUrl: url, specializedAgentLabel: label }),

  // Global modal open state
  chatModalOpen: false,
  studyLabModalOpen: false,
  setChatModalOpen: (chatModalOpen) => set({ chatModalOpen }),
  setStudyLabModalOpen: (studyLabModalOpen) => set({ studyLabModalOpen }),

  // Graph filters
  graphFilters: {
    courseIds: [],
    masteryRange: [0, 100],
    viewMode: "semester",
  },
  setGraphFilters: (filters) =>
    set((s) => ({ graphFilters: { ...s.graphFilters, ...filters } })),

  setCourses: (courses) => set({ courses }),
  setAssignments: (assignments) => set({ assignments }),
  setNotes: (notes) => set({ notes }),
  setAnnouncements: (announcements) => set({ announcements }),
  setConcepts: (concepts) => set({ concepts }),
  setConnections: (connections) => set({ connections }),

  addConcepts: (newConcepts) =>
    set((s) => {
      const existingIds = new Set(s.concepts.map((c) => c.id));
      const unique = newConcepts.filter((c) => !existingIds.has(c.id));
      return { concepts: [...s.concepts, ...unique] };
    }),

  addConnections: (newConns) =>
    set((s) => {
      const existingIds = new Set(s.connections.map((c) => c.id));
      const unique = newConns.filter((c) => !existingIds.has(c.id));
      return { connections: [...s.connections, ...unique] };
    }),

  addChatMessage: (message) =>
    set((s) => ({ chatMessages: [...s.chatMessages, message] })),

  updateLastAssistantMessage: (content) =>
    set((s) => {
      const msgs = [...s.chatMessages];
      for (let i = msgs.length - 1; i >= 0; i--) {
        if (msgs[i].role === "assistant") {
          msgs[i] = { ...msgs[i], content };
          break;
        }
      }
      return { chatMessages: msgs };
    }),

  setChatLoading: (chatLoading) => set({ chatLoading }),

  clearChat: () => set({ chatMessages: [], chatLoading: false }),

  setFlashcards: (flashcards) => set({ flashcards }),
  setQuizQuestions: (quizQuestions) => set({ quizQuestions }),
  setStudyGuide: (studyGuide) => set({ studyGuide }),
  setStudyLoading: (studyLoading) => set({ studyLoading }),

  setSyllabi: (syllabi) => set({ syllabi }),
  setHighlightWeek: (highlightWeek) => set({ highlightWeek }),

  startListening: () =>
    set({ voiceInput: { isListening: true, transcript: "", isSpeaking: false, shouldSpeak: false } }),
  stopListening: () =>
    set((s) => ({ voiceInput: { ...s.voiceInput, isListening: false } })),
  setTranscript: (transcript) =>
    set((s) => ({ voiceInput: { ...s.voiceInput, transcript } })),
  clearTranscript: () =>
    set((s) => ({ voiceInput: { ...s.voiceInput, transcript: "" } })),
  setSpeaking: (isSpeaking) =>
    set((s) => ({ voiceInput: { ...s.voiceInput, isSpeaking } })),
  setShouldSpeak: (shouldSpeak) =>
    set((s) => ({ voiceInput: { ...s.voiceInput, shouldSpeak } })),

  setActiveCourseId: (activeCourseId) => set({ activeCourseId }),
  setSelectedConceptId: (selectedConceptId) => set({ selectedConceptId }),

  currentView: "home",
  setCurrentView: (currentView) => set({ currentView }),
}));
