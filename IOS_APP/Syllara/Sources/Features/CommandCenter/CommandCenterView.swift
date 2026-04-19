import SwiftUI

@MainActor
final class CommandCenterViewModel: ObservableObject {
    @Published var courses: [Course] = []
    @Published var assignments: [Assignment] = []
    @Published var announcements: [Announcement] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var isUsingDemoData = false

    var urgentAssignments: [Assignment] {
        assignments
            .filter { $0.priority == "critical" || $0.priority == "high" }
            .filter { !$0.has_submitted_submissions }
            .sorted { $0.priorityLevel > $1.priorityLevel }
    }

    var recentAnnouncements: [Announcement] {
        Array(announcements.prefix(5))
    }

    func load() async {
        isLoading = true
        error = nil
        isUsingDemoData = false
        do {
            async let c = APIClient.shared.fetchCourses()
            async let a = APIClient.shared.fetchAssignments()
            async let ann = APIClient.shared.fetchAnnouncements()
            (courses, assignments, announcements) = try await (c, a, ann)
        } catch {
            courses = DemoContent.courses
            assignments = DemoContent.assignments
            announcements = DemoContent.announcements
            isUsingDemoData = true
        }
        isLoading = false
    }
}

struct CommandCenterView: View {
    @StateObject private var vm = CommandCenterViewModel()
    @State private var selectedAssignment: Assignment?

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    LoadingView(message: "Loading mission control…")
                } else if let err = vm.error {
                    ErrorView(message: err, retry: { Task { await vm.load() } })
                } else {
                    content
                }
            }
            .navigationTitle("Command Center")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await vm.load() } } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            .background(Color.bgBase)
            .sheet(item: $selectedAssignment) { assignment in
                AssignmentDetailView(assignment: assignment, course: vm.courses.first { $0.id == assignment.course_id })
            }
        }
        .task { await vm.load() }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if vm.isUsingDemoData {
                    demoBanner
                }
                systemStatusBanner
                urgentSection
                courseGrid
                announcementsSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - System Status Banner

    private var systemStatusBanner: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SPRING 2026 — RUTGERS MSCS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.textTertiary)
                    .tracking(1.2)
                Text("\(vm.urgentAssignments.count) items require attention")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary)
            }
            Spacer()
            ZStack {
                Circle().fill(Color.scarletMuted).frame(width: 44, height: 44)
                Text("\(vm.urgentAssignments.count)")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(.scarlet)
            }
        }
        .padding(16)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.scarlet.opacity(0.25), lineWidth: 1)
        )
    }

    private var demoBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .foregroundColor(.scarlet)
            Text("Showing offline demo data because the backend is unavailable.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.textSecondary)
            Spacer()
        }
        .padding(12)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }

    // MARK: - Urgent Assignments

    private var urgentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "At Risk", subtitle: "Requires immediate action")
            if vm.urgentAssignments.isEmpty {
                Text("All clear — no critical items.")
                    .font(.system(size: 14))
                    .foregroundColor(.textTertiary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(vm.urgentAssignments) { assignment in
                    AssignmentRow(assignment: assignment, course: vm.courses.first { $0.id == assignment.course_id })
                        .onTapGesture { selectedAssignment = assignment }
                }
            }
        }
    }

    // MARK: - Course Grid

    private var courseGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Enrolled Courses")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(vm.courses) { course in
                    CourseCard(course: course)
                }
            }
        }
    }

    // MARK: - Announcements

    private var announcementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Announcements")
            ForEach(vm.recentAnnouncements) { ann in
                AnnouncementRow(announcement: ann, course: vm.courses.first { $0.id == ann.course_id })
            }
        }
    }
}

// MARK: - Assignment Row

struct AssignmentRow: View {
    let assignment: Assignment
    let course: Course?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(priorityColor(assignment.priority))
                .frame(width: 3)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    PriorityBadge(priority: assignment.priority)
                    Spacer()
                    if let days = assignment.daysUntilDue {
                        Text(days <= 0 ? "Overdue" : "\(days)d left")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(days <= 1 ? .priorityCritical : .textSecondary)
                    }
                }
                Text(assignment.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(2)

                if let course = course {
                    HStack(spacing: 6) {
                        CourseColorDot(colorHex: course.color)
                        Text(course.course_code)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.textSecondary)
                    }
                }
                Text("Due \(assignment.dueDateFormatted)")
                    .font(.system(size: 11))
                    .foregroundColor(.textTertiary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundColor(.textTertiary)
                .padding(.top, 4)
        }
        .padding(14)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
}

// MARK: - Course Card

struct CourseCard: View {
    let course: Course

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                CourseColorDot(colorHex: course.color, size: 10)
                Text(course.course_code)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.textTertiary)
                    .lineLimit(1)
            }
            Text(course.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.textPrimary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Progress")
                        .font(.system(size: 10))
                        .foregroundColor(.textTertiary)
                    Spacer()
                    Text("\(course.progress)%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.textSecondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.bgSurface).frame(height: 3)
                        Capsule()
                            .fill(Color(hex: course.color) ?? .scarlet)
                            .frame(width: geo.size.width * CGFloat(course.progress) / 100, height: 3)
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(14)
        .frame(height: 150)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
}

// MARK: - Announcement Row

struct AnnouncementRow: View {
    let announcement: Announcement
    let course: Course?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let course = course {
                    HStack(spacing: 5) {
                        CourseColorDot(colorHex: course.color)
                        Text(course.course_code)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.textSecondary)
                    }
                }
                Spacer()
                if let priority = announcement.priority {
                    PriorityBadge(priority: priority)
                }
            }
            Text(announcement.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.textPrimary)
            Text(announcement.message)
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
                .lineLimit(3)
        }
        .padding(14)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
}
