import { create } from "zustand";
import type {
  SystemStatus,
  RemediationPlan,
  TriageStatus,
  CommandCenterState,
} from "../types";

// Mock triage data — maps assignment IDs to their statuses
const INITIAL_TRIAGE: Record<string, TriageStatus> = {
  "cs513-hw4": "danger",
  "cs518-lab3": "danger",
  "cs533-paper": "danger",
  "cs536-hw3": "danger",
};

const INITIAL_STATUS: SystemStatus = {
  canvasApi: "active",
  terpAiBridge: "active",
  ghostPilot: "ready",
};

export const useCommandStore = create<CommandCenterState>((set) => ({
  systemStatus: INITIAL_STATUS,
  activeRemediation: null,
  triageStatuses: INITIAL_TRIAGE,

  setSystemStatus: (systemStatus) => set({ systemStatus }),

  triggerRemediation: (plan: RemediationPlan) =>
    set({ activeRemediation: plan }),

  dismissRemediation: () => set({ activeRemediation: null }),

  setTriageStatus: (assignmentId: string, status: TriageStatus) =>
    set((s) => ({
      triageStatuses: { ...s.triageStatuses, [assignmentId]: status },
    })),
}));
