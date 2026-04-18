import { AlertTriangle, Shield } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { useAppStore } from "@/store/useAppStore";
import { useCommandStore } from "@/store/useCommandStore";
import type { TriageStatus, RemediationPlan } from "@/types";

const COURSE_COLORS: Record<string, string> = {
  cs512: "#CC0033",
  cs513: "#B3002D",
  cs518: "#990024",
  cs527: "#D91A46",
  cs533: "#E64D73",
  cs536: "#F28AA5",
};

// Mock remediation plans for danger items
const MOCK_REMEDIATIONS: Record<string, RemediationPlan> = {
  "cs512-ps3": {
    assignmentId: "cs512-ps3",
    assignment_name: "Problem Set 3: Graph Algorithms and Heaps",
    course_id: "cs512",
    score: 41,
    maxScore: 100,
    scoreMode: "readiness",
    conceptsMissed: ["Priority queues", "Shortest paths", "Amortized analysis", "Sparse graph reasoning"],
    steps: [
      { title: "Rebuild Dijkstra End-to-End", description: "Rewrite the heap operations and graph invariant before touching the proof or implementation detail.", estimatedTime: "35 min", status: "active" },
      { title: "Check the Asymptotic Story", description: "State what each term counts and why the recurrence or heap bound matches the algorithm design.", estimatedTime: "45 min", status: "pending" },
      { title: "Test Sparse vs Dense Cases", description: "Use one sparse and one dense graph example so the data-structure choice is actually justified.", estimatedTime: "35 min", status: "pending" },
    ],
  },
  "cs513-hw4": {
    assignmentId: "cs513-hw4",
    assignment_name: "Homework 4: Network Flow and Reductions",
    course_id: "cs513",
    score: 52,
    maxScore: 100,
    scoreMode: "readiness",
    conceptsMissed: ["Flow modeling", "Cut certificates", "Reduction correctness", "Complexity justification"],
    steps: [
      { title: "Write the Reduction First", description: "State the source problem, target structure, and yes/no mapping before doing algebra.", estimatedTime: "25 min", status: "active" },
      { title: "Verify the Flow Construction", description: "Annotate every capacity with the constraint it is intended to encode.", estimatedTime: "50 min", status: "pending" },
      { title: "Separate Correctness from Runtime", description: "Do not blend the proof of equivalence with the polynomial-time argument.", estimatedTime: "30 min", status: "pending" },
    ],
  },
  "cs518-lab3": {
    assignmentId: "cs518-lab3",
    assignment_name: "Lab 3: Virtual Memory and File Cache",
    course_id: "cs518",
    score: 28,
    maxScore: 90,
    scoreMode: "readiness",
    conceptsMissed: ["Page replacement", "Cache behavior", "Trace interpretation", "Throughput evidence"],
    steps: [
      { title: "Capture One Clean Trace", description: "Get one annotated trace with page faults or cache events before changing any settings.", estimatedTime: "20 min", status: "active" },
      { title: "Explain the Policy Choice", description: "Tie FIFO, LRU, or clock behavior to the access pattern instead of only reporting totals.", estimatedTime: "40 min", status: "pending" },
      { title: "Write the Systems Conclusion", description: "Connect the trace evidence to the final throughput or latency claim.", estimatedTime: "30 min", status: "pending" },
    ],
  },
  "cs536-hw3": {
    assignmentId: "cs536-hw3",
    assignment_name: "Homework 3: Generalization and Regularization",
    course_id: "cs536",
    score: 24,
    maxScore: 90,
    scoreMode: "readiness",
    conceptsMissed: ["Bias-variance tradeoffs", "Regularization choice", "Baseline comparison", "Generalization curves"],
    steps: [
      { title: "Lock the Baseline", description: "Choose one simple model as the reference point before comparing regularization settings.", estimatedTime: "15 min", status: "active" },
      { title: "Compare One Mechanism at a Time", description: "Do not mix dropout, weight decay, and architecture changes in the same comparison.", estimatedTime: "30 min", status: "pending" },
      { title: "Read the Curves, Not Just the Final Metric", description: "Explain where the train/validation gap starts to widen and why.", estimatedTime: "25 min", status: "pending" },
    ],
  },
  "cs533-paper": {
    assignmentId: "cs533-paper",
    assignment_name: "Final NLP Project Paper",
    course_id: "cs533",
    score: 31,
    maxScore: 150,
    scoreMode: "readiness",
    conceptsMissed: ["Evaluation criteria", "Baseline discipline", "Error taxonomy", "Ablation logic"],
    steps: [
      { title: "Tighten the Task Framing", description: "State one primary task and one metric before expanding the model section.", estimatedTime: "20 min", status: "active" },
      { title: "Reduce the Baseline List", description: "Keep only the baselines that sharpen the claim instead of bloating the comparison table.", estimatedTime: "30 min", status: "pending" },
      { title: "Write an Error Section Early", description: "Collect representative failure slices before the final draft so the analysis is concrete.", estimatedTime: "40 min", status: "pending" },
    ],
  },
};

function statusBadge(status: TriageStatus) {
  switch (status) {
    case "healthy":
      return (
        <Badge variant="outline" className="bg-blue-500/10 text-blue-400 border-blue-500/20 text-[10px] font-mono">
          Healthy
        </Badge>
      );
    case "danger":
      return (
        <Badge variant="outline" className="bg-orange-500/10 text-orange-400 border-orange-500/20 text-[10px] font-mono">
          Danger
        </Badge>
      );
    case "submitted":
      return (
        <Badge variant="outline" className="bg-white/5 text-white/30 border-white/10 text-[10px] font-mono">
          Submitted
        </Badge>
      );
  }
}

function daysUntil(dateStr: string): string {
  const diff = Math.ceil(
    (new Date(dateStr).getTime() - Date.now()) / (1000 * 60 * 60 * 24)
  );
  if (diff < 0) return `${Math.abs(diff)}d ago`;
  if (diff === 0) return "Today";
  if (diff === 1) return "Tomorrow";
  return `${diff}d`;
}

interface TriageAlertFeedProps {
  variant?: "bento" | "sidebar";
}

export function TriageAlertFeed({ variant = "bento" }: TriageAlertFeedProps) {
  const assignments = useAppStore((s) => s.assignments);
  const courses = useAppStore((s) => s.courses);
  const triageStatuses = useCommandStore((s) => s.triageStatuses);
  const triggerRemediation = useCommandStore((s) => s.triggerRemediation);

  const courseMap = new Map(courses.map((c) => [c.id, c]));

  // Sort: closest to today first (overdue + imminent at top, distant past/future at bottom)
  const now = Date.now();
  const sorted = [...assignments].sort((a, b) => {
    const distA = Math.abs(new Date(a.due_at).getTime() - now);
    const distB = Math.abs(new Date(b.due_at).getTime() - now);
    return distA - distB;
  });

  const setSelectedConceptId = useAppStore((s) => s.setSelectedConceptId);

  const handleClick = (assignmentId: string) => {
    // If there's a pre-built remediation plan, use it
    const plan = MOCK_REMEDIATIONS[assignmentId];
    if (plan) {
      setSelectedConceptId(null);
      triggerRemediation(plan);
      return;
    }

    // Otherwise, build a detail plan from the assignment data
    const assignment = assignments.find((a) => a.id === assignmentId);
    if (!assignment) return;

    const course = courseMap.get(assignment.course_id);

    let steps: RemediationPlan["steps"] = [];
    let conceptsMissed: string[] = [];
    let score = 0;
    const maxScore = assignment.points_possible;

    if (assignment.status === "graded" || assignment.has_submitted_submissions) {
      // Submitted / graded — show review steps with healthy scores
      // Use a seeded score based on assignment ID for consistency across re-renders
      const seed = assignmentId.split('').reduce((a, c) => a + c.charCodeAt(0), 0);
      const scorePercent = 0.78 + (seed % 17) / 100; // 78-95%
      score = Math.round(maxScore * scorePercent);
      conceptsMissed = []; // no gaps
      steps = [
        { title: "Review Feedback", description: `Check Gradescope for ${assignment.name} feedback and any comments from ${course?.instructor ?? 'your instructor'}.`, estimatedTime: "10 min", status: "active" as const },
        { title: "Revisit Weak Areas", description: `Review any questions you missed. Focus on understanding the solution approach rather than memorizing answers.`, estimatedTime: "20 min", status: "pending" as const },
        { title: "Connect to Upcoming Material", description: `This assignment's concepts build into future ${course?.course_code ?? ''} topics. Review how they connect.`, estimatedTime: "15 min", status: "pending" as const },
      ];
    } else if (assignment.status === "in_progress") {
      // In progress — show completion steps with partial progress score
      const seed = assignmentId.split('').reduce((a, c) => a + c.charCodeAt(0), 0);
      const progressPercent = 0.35 + (seed % 25) / 100; // 35-60%
      score = Math.round(maxScore * progressPercent);
      conceptsMissed = assignment.description?.split(/[,.;]/).slice(0, 3).map(s => s.trim()).filter(Boolean) ?? [];
      steps = [
        { title: "Continue Working", description: `Keep working on ${assignment.name}. Focus on completing one section at a time.`, estimatedTime: "60 min", status: "active" as const },
        { title: "Test Your Solution", description: `Run all available test cases. Check for edge cases and boundary conditions.`, estimatedTime: "20 min", status: "pending" as const },
        { title: "Submit Before Deadline", description: `Due ${new Date(assignment.due_at).toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })}. Submit early — even partial work gets partial credit.`, estimatedTime: "5 min", status: "pending" as const },
      ];
    } else {
      // Upcoming — show preparation steps
      score = 0;
      conceptsMissed = assignment.description?.split(/[,.;]/).slice(0, 3).map(s => s.trim()).filter(Boolean) ?? [];
      steps = [
        { title: "Preview Material", description: `Read through the ${assignment.name} requirements. Identify which lecture topics are relevant.`, estimatedTime: "15 min", status: "active" as const },
        { title: "Review Prerequisites", description: `Make sure you're comfortable with the prerequisite concepts before starting.`, estimatedTime: "30 min", status: "pending" as const },
        { title: "Plan Your Timeline", description: `Due ${new Date(assignment.due_at).toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })}. Block time on your calendar to work on this.`, estimatedTime: "5 min", status: "pending" as const },
      ];
    }

    setSelectedConceptId(null);
    triggerRemediation({
      assignmentId,
      assignment_name: assignment.name,
      course_id: assignment.course_id,
      score,
      maxScore,
      scoreMode: assignment.status === "graded" || assignment.has_submitted_submissions ? "historical" : assignment.status === "in_progress" ? "readiness" : "not_started",
      conceptsMissed,
      steps,
    });
  };

  return (
    <div className={`h-full flex flex-col ${variant === "bento" ? "glass-card p-5" : "p-4"}`}>
      {/* Header */}
      <div className="flex items-center justify-between mb-4 shrink-0">
        <div className="flex items-center gap-2">
          <Shield size={14} className="text-blue-400" />
          <span className="text-[11px] font-medium tracking-[0.15em] text-white/40 uppercase">
            Autonomous Triage
          </span>
        </div>
        <span className="text-[10px] text-white/20 font-mono">
          {sorted.length} items
        </span>
      </div>

      {/* Feed */}
      <div className={`flex-1 min-h-0 overflow-y-auto overflow-x-hidden ${variant === "bento" ? "-mx-1 px-1" : ""}`}>
        <div className="flex flex-col gap-1.5 pb-4">
          {sorted.map((assignment, idx) => {
            const status = triageStatuses[assignment.id] ?? "healthy";
            const course = courseMap.get(assignment.course_id);
            const isDanger = status === "danger";

            return (
              <button
                key={assignment.id}
                onClick={() => handleClick(assignment.id)}
                className={`
                  w-full text-left flex items-center gap-3 px-3 py-2 rounded-lg
                  transition-all duration-200 animate-fade-in-up cursor-pointer
                  ${isDanger
                    ? "bg-orange-500/[0.05] border border-orange-500/10 hover:bg-orange-500/[0.08]"
                    : "bg-white/[0.02] border border-white/[0.03] hover:bg-white/[0.05] hover:border-white/[0.08]"
                  }
                `}
                style={{ animationDelay: `${idx * 0.05}s` }}
              >
                {/* Course color pip */}
                <div
                  className="w-1.5 h-8 rounded-full shrink-0"
                  style={{ background: COURSE_COLORS[assignment.course_id] ?? "#666" }}
                />

                {/* Content */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-0.5">
                    <span className="text-[12px] text-white/70 truncate">
                      {assignment.name}
                    </span>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="text-[10px] text-white/30 font-mono">
                      {course?.course_code ?? assignment.course_id.toUpperCase()}
                    </span>
                    <span className="text-[10px] text-white/20">•</span>
                    <span
                      className={`text-[10px] font-mono ${isDanger ? "text-orange-400" : "text-white/30"
                        }`}
                    >
                      {daysUntil(assignment.due_at)}
                    </span>
                  </div>
                </div>

                {/* Status badge */}
                <div className="shrink-0 flex items-center gap-2">
                  {isDanger && (
                    <AlertTriangle size={12} className="text-orange-400 animate-pulse" />
                  )}
                  {statusBadge(status)}
                </div>
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}
