import SwiftUI

struct AssignmentDetailView: View {
    let assignment: Assignment
    let course: Course?
    @Environment(\.dismiss) private var dismiss

    private let knowledgeGaps: [String] = {
        // Static per-assignment gap mapping derived from demo data
        return [
            "Prerequisite concepts may need review",
            "Check lecture notes from the past 2 weeks",
            "Review related problem sets"
        ]
    }()

    private let roadmapSteps: [(String, String)] = [
        ("1", "Review lecture slides and notes"),
        ("2", "Complete practice problems from textbook"),
        ("3", "Attempt first draft of submission"),
        ("4", "Use Study Lab to generate targeted quiz"),
        ("5", "Submit before deadline"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    riskSection
                    gapsSection
                    roadmapSection
                    descriptionSection
                }
                .padding(16)
            }
            .background(Color.bgBase)
            .navigationTitle("Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.scarlet)
                }
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let course = course {
                HStack(spacing: 8) {
                    CourseColorDot(colorHex: course.color, size: 10)
                    Text(course.course_code)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.textSecondary)
                    Text("·")
                        .foregroundColor(.textTertiary)
                    Text(assignment.assignment_category.uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.textTertiary)
                        .tracking(0.8)
                }
            }
            Text(assignment.name)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.textPrimary)

            HStack(spacing: 12) {
                PriorityBadge(priority: assignment.priority)
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundColor(.textTertiary)
                    Text("Due \(assignment.dueDateFormatted)")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .padding(16)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var riskSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Readiness Assessment")

            HStack(spacing: 16) {
                readinessGauge(value: readinessScore, label: "Readiness")
                VStack(alignment: .leading, spacing: 8) {
                    Text(riskLabel)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(riskColor)
                    Text(riskDescription)
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                        .lineSpacing(3)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var gapsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Knowledge Gaps")
            VStack(spacing: 8) {
                ForEach(knowledgeGaps, id: \.self) { gap in
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 13))
                            .foregroundColor(.priorityMedium)
                        Text(gap)
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                        Spacer()
                    }
                    .padding(10)
                    .background(Color.bgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(16)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var roadmapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recovery Roadmap")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(roadmapSteps, id: \.0) { step in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.scarletMuted)
                                .frame(width: 26, height: 26)
                            Text(step.0)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.scarlet)
                        }
                        Text(step.1)
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                            .padding(.top, 4)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    if step.0 != roadmapSteps.last?.0 {
                        Rectangle()
                            .fill(Color.bgSurface)
                            .frame(width: 1, height: 12)
                            .padding(.leading, 12)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var descriptionSection: some View {
        if let desc = assignment.description, !desc.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Description")
                Text(desc)
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                    .lineSpacing(4)
            }
            .padding(16)
            .background(Color.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Helpers

    private var readinessScore: Double {
        switch assignment.priority {
        case "critical": return 0.22
        case "high": return 0.45
        case "medium": return 0.62
        default: return 0.80
        }
    }

    private var riskLabel: String {
        switch assignment.priority {
        case "critical": return "High Risk"
        case "high": return "Elevated Risk"
        case "medium": return "Moderate Risk"
        default: return "Low Risk"
        }
    }

    private var riskColor: Color {
        priorityColor(assignment.priority)
    }

    private var riskDescription: String {
        switch assignment.priority {
        case "critical": return "Immediate action required. Follow the recovery roadmap below."
        case "high": return "Begin work now. Gap analysis suggests focused prep needed."
        case "medium": return "On track but review gaps before submission."
        default: return "Looking good. Final review recommended."
        }
    }

    private func readinessGauge(value: Double, label: String) -> some View {
        ZStack {
            Circle()
                .stroke(Color.bgSurface, lineWidth: 6)
                .frame(width: 72, height: 72)
            Circle()
                .trim(from: 0, to: value)
                .stroke(riskColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 72, height: 72)
            VStack(spacing: 0) {
                Text("\(Int(value * 100))%")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(.textPrimary)
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(.textTertiary)
            }
        }
    }
}
