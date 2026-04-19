import SwiftUI

enum StudyArtifact: String, CaseIterable {
    case quiz = "Quiz"
    case flashcards = "Flashcards"
    case studyGuide = "Study Guide"

    var icon: String {
        switch self {
        case .quiz: return "questionmark.circle"
        case .flashcards: return "rectangle.stack"
        case .studyGuide: return "doc.text"
        }
    }
}

enum StudyLabResult {
    case quiz([QuizQuestion])
    case flashcards([FlashCard])
    case studyGuide(String)
    case none

    var hasContent: Bool {
        switch self {
        case .none:
            return false
        default:
            return true
        }
    }
}

@MainActor
final class StudyLabViewModel: ObservableObject {
    @Published var courses: [Course] = []
    @Published var selectedCourse: Course?
    @Published var topic: String = ""
    @Published var selectedArtifact: StudyArtifact = .quiz
    @Published var isGenerating = false
    @Published var error: String?
    @Published var result: StudyLabResult = .none

    // Quiz state
    @Published var currentQuestionIndex = 0
    @Published var selectedAnswerIndex: Int? = nil
    @Published var showExplanation = false

    // Flashcard state
    @Published var currentCardIndex = 0
    @Published var cardFlipped = false

    func loadCourses() async {
        do {
            courses = try await APIClient.shared.fetchCourses()
        } catch {
            courses = DemoContent.courses
        }
        if selectedCourse == nil { selectedCourse = courses.first }
    }

    func generate() async {
        guard let course = selectedCourse, !topic.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isGenerating = true
        error = nil
        result = .none
        currentQuestionIndex = 0
        selectedAnswerIndex = nil
        showExplanation = false
        currentCardIndex = 0
        cardFlipped = false

        let req = GenerateRequest(topic: topic, course_id: course.id, additional_context: nil)
        do {
            switch selectedArtifact {
            case .quiz:
                let r = try await APIClient.shared.generateQuiz(req)
                result = .quiz(r.questions)
            case .flashcards:
                let r = try await APIClient.shared.generateFlashcards(req)
                result = .flashcards(r.cards)
            case .studyGuide:
                let r = try await APIClient.shared.generateStudyGuide(req)
                result = .studyGuide(r.content)
            }
            NotificationManager.shared.notifyStudyLabReady(artifact: selectedArtifact, topic: topic)
        } catch {
            self.error = error.localizedDescription
        }
        isGenerating = false
    }

    func resetResult() {
        error = nil
        result = .none
        currentQuestionIndex = 0
        selectedAnswerIndex = nil
        showExplanation = false
        currentCardIndex = 0
        cardFlipped = false
    }
}

struct StudyLabView: View {
    @StateObject private var vm = StudyLabViewModel()
    @StateObject private var audio = AudioManager()
    @FocusState private var isTopicFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    configPanel
                    if vm.isGenerating {
                        generatingView
                    } else if let err = vm.error {
                        ErrorView(message: err, retry: { Task { await vm.generate() } })
                            .frame(height: 200)
                    } else {
                        resultView
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture {
                isTopicFieldFocused = false
            }
            .background(Color.bgBase)
            .navigationTitle("Study Lab")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isTopicFieldFocused = false
                    }
                }
            }
        }
        .task { await vm.loadCourses() }
    }

    // MARK: - Config Panel

    private var configPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Course picker
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Course")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.courses) { course in
                            Button { vm.selectedCourse = course } label: {
                                HStack(spacing: 6) {
                                    CourseColorDot(colorHex: course.color)
                                    Text(course.course_code)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                }
                                .foregroundColor(vm.selectedCourse?.id == course.id ? .white : .textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(vm.selectedCourse?.id == course.id ? Color.scarlet : Color.bgCard)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.06), lineWidth: 1))
                            }
                        }
                    }
                }
            }

            // Topic input
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Topic")
                HStack {
                    TextField("e.g. Dynamic Programming, NLP Transformers…", text: $vm.topic)
                        .font(.system(size: 14))
                        .foregroundColor(.textPrimary)
                        .tint(.scarlet)
                        .focused($isTopicFieldFocused)
                    if !vm.topic.isEmpty {
                        Button { vm.topic = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.textTertiary)
                        }
                    }
                }
                .padding(12)
                .background(Color.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.07), lineWidth: 1))
            }

            if vm.result.hasContent || vm.error != nil {
                Button {
                    isTopicFieldFocused = false
                    vm.resetResult()
                } label: {
                    HStack {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Start Over")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.bgSurface)
                    .clipShape(Capsule())
                }
            }

            // Artifact type
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Generate")
                HStack(spacing: 8) {
                    ForEach(StudyArtifact.allCases, id: \.self) { artifact in
                        Button { vm.selectedArtifact = artifact } label: {
                            VStack(spacing: 6) {
                                Image(systemName: artifact.icon)
                                    .font(.system(size: 16))
                                Text(artifact.rawValue)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(vm.selectedArtifact == artifact ? .white : .textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(vm.selectedArtifact == artifact ? Color.scarlet : Color.bgCard)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        }
                    }
                }
            }

            Button {
                isTopicFieldFocused = false
                Task { await vm.generate() }
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 13))
                    Text("Generate")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.vertical, 14)
                .background(vm.topic.isEmpty ? Color.bgSurface : Color.scarlet)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(vm.topic.isEmpty || vm.isGenerating)
        }
        .padding(16)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var generatingView: some View {
        VStack(spacing: 16) {
            ProgressView().progressViewStyle(.circular).tint(.scarlet).scaleEffect(1.2)
            Text("Generating \(vm.selectedArtifact.rawValue.lowercased())…")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var resultView: some View {
        switch vm.result {
        case .quiz(let questions):
            QuizView(questions: questions, vm: vm)
        case .flashcards(let cards):
            FlashcardsView(cards: cards, vm: vm)
        case .studyGuide(let content):
            StudyGuideView(content: content, audio: audio)
        case .none:
            EmptyView()
        }
    }
}

// MARK: - Quiz View

struct QuizView: View {
    let questions: [QuizQuestion]
    @ObservedObject var vm: StudyLabViewModel

    var question: QuizQuestion { questions[vm.currentQuestionIndex] }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("QUIZ")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.textTertiary)
                    .tracking(1.5)
                Spacer()
                Text("\(vm.currentQuestionIndex + 1) / \(questions.count)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.textSecondary)
            }

            Text(question.question)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.textPrimary)
                .lineSpacing(3)

            VStack(spacing: 8) {
                ForEach(question.options.indices, id: \.self) { idx in
                    quizOption(idx: idx)
                }
            }

            if vm.showExplanation {
                VStack(alignment: .leading, spacing: 8) {
                    Text("EXPLANATION")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.textTertiary)
                        .tracking(1.2)
                    Text(question.explanation)
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                        .lineSpacing(3)
                }
                .padding(12)
                .background(Color.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if vm.currentQuestionIndex < questions.count - 1 {
                    Button {
                        vm.currentQuestionIndex += 1
                        vm.selectedAnswerIndex = nil
                        vm.showExplanation = false
                    } label: {
                        HStack {
                            Spacer()
                            Text("Next Question")
                                .font(.system(size: 14, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12))
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .background(Color.scarlet)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                } else {
                    Text("Quiz complete!")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.priorityLow)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.priorityLow.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(16)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func quizOption(idx: Int) -> some View {
        let isSelected = vm.selectedAnswerIndex == idx
        let isCorrect = idx == question.correct_index
        let answered = vm.selectedAnswerIndex != nil

        var bgColor: Color = Color.bgSurface
        var borderColor: Color = Color.white.opacity(0.07)
        if answered {
            if isCorrect { bgColor = Color.priorityLow.opacity(0.15); borderColor = Color.priorityLow.opacity(0.5) }
            else if isSelected { bgColor = Color.priorityCritical.opacity(0.15); borderColor = Color.priorityCritical.opacity(0.5) }
        } else if isSelected {
            bgColor = Color.scarletMuted; borderColor = Color.scarlet.opacity(0.4)
        }

        return Button {
            if vm.selectedAnswerIndex == nil {
                vm.selectedAnswerIndex = idx
                withAnimation { vm.showExplanation = true }
            }
        } label: {
            HStack {
                Text(["A","B","C","D"][safe: idx] ?? "\(idx+1)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(answered && isCorrect ? .priorityLow : .textTertiary)
                    .frame(width: 22)
                Text(question.options[idx])
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer()
                if answered && isCorrect {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.priorityLow)
                } else if answered && isSelected {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.priorityCritical)
                }
            }
            .padding(12)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(borderColor, lineWidth: 1))
        }
        .disabled(vm.selectedAnswerIndex != nil)
    }
}

// MARK: - Flashcards View

struct FlashcardsView: View {
    let cards: [FlashCard]
    @ObservedObject var vm: StudyLabViewModel

    var card: FlashCard { cards[vm.currentCardIndex] }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("FLASHCARDS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.textTertiary)
                    .tracking(1.5)
                Spacer()
                Text("\(vm.currentCardIndex + 1) / \(cards.count)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.textSecondary)
            }

            ZStack {
                flashcardFace(
                    sideLabel: "FRONT",
                    text: card.front,
                    isVisible: !vm.cardFlipped
                )

                flashcardFace(
                    sideLabel: "BACK",
                    text: card.back,
                    isVisible: vm.cardFlipped
                )
                .rotation3DEffect(.degrees(180), axis: (0, 1, 0))
            }
            .frame(minHeight: 200)
            .rotation3DEffect(.degrees(vm.cardFlipped ? 180 : 0), axis: (0, 1, 0))
            .onTapGesture {
                withAnimation(.spring(response: 0.5)) { vm.cardFlipped.toggle() }
            }

            HStack(spacing: 12) {
                if vm.currentCardIndex > 0 {
                    Button {
                        vm.currentCardIndex -= 1
                        vm.cardFlipped = false
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textSecondary)
                            .frame(width: 44, height: 44)
                            .background(Color.bgCard)
                            .clipShape(Circle())
                    }
                }
                Spacer()
                if vm.currentCardIndex < cards.count - 1 {
                    Button {
                        vm.currentCardIndex += 1
                        vm.cardFlipped = false
                    } label: {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.scarlet)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(16)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func flashcardFace(sideLabel: String, text: String, isVisible: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.bgCard)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.07), lineWidth: 1))
            .overlay {
                VStack(spacing: 12) {
                    Text(sideLabel)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.textTertiary)
                        .tracking(1.5)
                    Text(text)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 20)
                    Text("Tap to flip")
                        .font(.system(size: 11))
                        .foregroundColor(.textTertiary)
                }
                .padding(24)
                .opacity(isVisible ? 1 : 0)
            }
    }
}

// MARK: - Study Guide View

struct StudyGuideView: View {
    let content: String
    @ObservedObject var audio: AudioManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("STUDY GUIDE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.textTertiary)
                    .tracking(1.5)
                Spacer()
            }
            TTSPlaybackBar(audio: audio, text: content)
            Text(content)
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
                .lineSpacing(5)
        }
        .padding(16)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// Safe array subscript
extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
