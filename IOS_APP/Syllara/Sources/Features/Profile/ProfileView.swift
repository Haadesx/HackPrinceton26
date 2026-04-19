import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var searchQuery: String = ""
    @Published var searchResults: [UniversityResult] = []
    @Published var selectedUniversity: UniversityResult?
    @Published var universityProfile: UniversityProfile?
    @Published var transcriptResult: TranscriptImportResult?
    @Published var isSearching = false
    @Published var isLoadingProfile = false
    @Published var isImporting = false
    @Published var error: String?

    private var searchTask: Task<Void, Never>?

    func search() {
        searchTask?.cancel()
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000) // debounce
            guard !Task.isCancelled else { return }
            isSearching = true
            do {
                let r = try await APIClient.shared.searchUniversities(query: searchQuery)
                searchResults = r.results
            } catch {
                self.error = error.localizedDescription
            }
            isSearching = false
        }
    }

    func selectUniversity(_ uni: UniversityResult) {
        selectedUniversity = uni
        searchResults = []
        searchQuery = uni.name
        loadProfile(slug: uni.slug)
    }

    func loadProfile(slug: String) {
        isLoadingProfile = true
        Task {
            do {
                universityProfile = try await APIClient.shared.fetchUniversityProfile(slug: slug)
            } catch {
                // Profile load is best-effort
            }
            isLoadingProfile = false
        }
    }

    func importTranscript(data: Data, fileName: String) async {
        guard let uni = selectedUniversity else { return }
        isImporting = true
        error = nil
        do {
            transcriptResult = try await APIClient.shared.importTranscript(
                universitySlug: uni.slug,
                fileData: data,
                fileName: fileName
            )
        } catch {
            self.error = error.localizedDescription
        }
        isImporting = false
    }
}

struct ProfileView: View {
    @StateObject private var vm = ProfileViewModel()
    @State private var showFilePicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    universitySearchSection
                    if let profile = vm.universityProfile {
                        universityProfileSection(profile)
                    }
                    transcriptSection
                    if let result = vm.transcriptResult {
                        transcriptResultSection(result)
                    }
                }
                .padding(16)
            }
            .background(Color.bgBase)
            .navigationTitle("Academic Profile")
            .navigationBarTitleDisplayMode(.large)
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf, .text, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) {
                    Task { await vm.importTranscript(data: data, fileName: url.lastPathComponent) }
                }
            case .failure(let err):
                vm.error = err.localizedDescription
            }
        }
    }

    // MARK: - University Search

    private var universitySearchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "University", subtitle: "Search and select your institution")

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.textTertiary)
                        .font(.system(size: 14))
                    TextField("Search universities…", text: $vm.searchQuery)
                        .font(.system(size: 14))
                        .foregroundColor(.textPrimary)
                        .tint(.scarlet)
                        .onChange(of: vm.searchQuery) { _, _ in vm.search() }
                    if vm.isSearching {
                        ProgressView().progressViewStyle(.circular).scaleEffect(0.7).tint(.textSecondary)
                    }
                }
                .padding(12)
                .background(Color.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if !vm.searchResults.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(vm.searchResults) { uni in
                            Button { vm.selectUniversity(uni) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(uni.name)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.textPrimary)
                                        if let loc = uni.location {
                                            Text(loc)
                                                .font(.system(size: 12))
                                                .foregroundColor(.textTertiary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11))
                                        .foregroundColor(.textTertiary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                            }
                            Divider().background(Color.white.opacity(0.05))
                        }
                    }
                    .background(Color.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            if let selected = vm.selectedUniversity {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Color.scarletMuted).frame(width: 36, height: 36)
                        Image(systemName: "building.columns")
                            .font(.system(size: 14))
                            .foregroundColor(.scarlet)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selected.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        if let loc = selected.location {
                            Text(loc)
                                .font(.system(size: 12))
                                .foregroundColor(.textSecondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.priorityLow)
                }
                .padding(12)
                .background(Color.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - University Profile

    private func universityProfileSection(_ profile: UniversityProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Institution Profile")
            VStack(alignment: .leading, spacing: 12) {
                if let desc = profile.description {
                    Text(desc)
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                        .lineSpacing(3)
                }
                if let programs = profile.programs, !programs.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PROGRAMS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.textTertiary)
                            .tracking(1.2)
                        FlowLayout(items: programs) { program in
                            Text(program)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.bgSurface)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(14)
            .background(Color.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Transcript Upload

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Transcript Import", subtitle: "PDF or TXT transcript")

            Button { showFilePicker = true } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(Color.scarletMuted).frame(width: 40, height: 40)
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 16))
                            .foregroundColor(.scarlet)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Upload Transcript")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        Text("Supported: PDF, TXT")
                            .font(.system(size: 12))
                            .foregroundColor(.textTertiary)
                    }
                    Spacer()
                    if vm.isImporting {
                        ProgressView().progressViewStyle(.circular).scaleEffect(0.8).tint(.scarlet)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.textTertiary)
                    }
                }
                .padding(14)
                .background(Color.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
            }
            .disabled(vm.selectedUniversity == nil || vm.isImporting)
            .opacity(vm.selectedUniversity == nil ? 0.5 : 1)

            if vm.selectedUniversity == nil {
                Text("Select a university above before importing a transcript.")
                    .font(.system(size: 12))
                    .foregroundColor(.textTertiary)
            }

            if let err = vm.error {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundColor(.priorityCritical)
            }
        }
    }

    // MARK: - Transcript Result

    private func transcriptResultSection(_ result: TranscriptImportResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Matched Courses")
                Spacer()
                if result.status == "success" {
                    Label("Imported", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.priorityLow)
                }
            }

            if let courses = result.matched_courses, !courses.isEmpty {
                ForEach(courses) { course in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(course.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.textPrimary)
                            if let code = course.course_code {
                                Text(code)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.textSecondary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            if let grade = course.grade {
                                Text(grade)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(.scarlet)
                            }
                            if let credits = course.credits {
                                Text("\(credits, specifier: "%.0f") cr")
                                    .font(.system(size: 11))
                                    .foregroundColor(.textTertiary)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            } else if let msg = result.message {
                Text(msg)
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

// MARK: - FlowLayout

struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let items: Data
    let content: (Data.Element) -> Content

    @State private var totalHeight: CGFloat = .zero

    var body: some View {
        GeometryReader { geo in
            self.generateContent(in: geo)
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in geo: GeometryProxy) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0
        var rowHeight: CGFloat = 0

        return ZStack(alignment: .topLeading) {
            ForEach(Array(items.enumerated()), id: \.element) { _, item in
                content(item)
                    .padding([.horizontal, .vertical], 3)
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > geo.size.width {
                            width = 0
                            height -= rowHeight
                            rowHeight = 0
                        }
                        let result = width
                        width -= d.width
                        rowHeight = max(rowHeight, d.height)
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        return result
                    }
            }
        }
        .background(heightCapture($totalHeight))
    }

    private func heightCapture(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geo in
            Color.clear.preference(key: HeightKey.self, value: geo.size.height)
        }
        .onPreferenceChange(HeightKey.self) { binding.wrappedValue = $0 }
    }
}

struct HeightKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
