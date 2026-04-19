import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isStreaming = false
    @Published var selectedCourse: String? = nil
    @Published var courses: [Course] = []
    @Published var error: String?

    private var streamingMessage: ChatMessage?

    func loadCourses() async {
        do {
            courses = try await APIClient.shared.fetchCourses()
        } catch {
            courses = DemoContent.courses
        }
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        inputText = ""
        error = nil

        let userMsg = ChatMessage(role: "user", content: text)
        messages.append(userMsg)

        let assistantMsg = ChatMessage(role: "assistant", content: "")
        messages.append(assistantMsg)
        let assistantID = messages.count - 1

        isStreaming = true

        let payload = ChatRequest(
            messages: messages.dropLast().map { ChatMessagePayload(role: $0.role, content: $0.content) },
            course_context: selectedCourse
        )

        do {
            for try await chunk in APIClient.shared.streamChat(request: payload) {
                messages[assistantID].content += chunk
            }
        } catch {
            messages[assistantID].content = "Error: \(error.localizedDescription)"
            self.error = error.localizedDescription
        }
        isStreaming = false
    }

    func clearHistory() {
        messages.removeAll()
    }
}

struct ChatView: View {
    @StateObject private var vm = ChatViewModel()
    @StateObject private var audio = AudioManager()
    @StateObject private var recorder = VoiceRecorder()
    @Namespace private var bottomID
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                courseFilter
                    .background(Color.bgBase)
                messageList
                inputBar
            }
            .background(Color.bgBase)
            .navigationTitle("Brain Brew Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { vm.clearHistory() } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.textSecondary)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isInputFocused = false
                    }
                }
            }
        }
        .task { await vm.loadCourses() }
        .onChange(of: recorder.state) { _, newState in
            if case .done(let text) = newState {
                vm.inputText = text
                isInputFocused = true
            }
        }
    }

    // MARK: - Course Filter

    private var courseFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All Courses", value: nil)
                ForEach(vm.courses) { course in
                    filterChip(label: course.course_code, value: course.id)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.bgBase)
        .overlay(Divider().background(Color.white.opacity(0.05)), alignment: .bottom)
    }

    private func filterChip(label: String, value: String?) -> some View {
        let active = vm.selectedCourse == value
        return Button { vm.selectedCourse = value } label: {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(active ? .white : .textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(active ? Color.scarlet : Color.bgCard)
                .clipShape(Capsule())
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if vm.messages.isEmpty {
                        emptyChatState
                    }
                    ForEach(vm.messages) { message in
                        MessageBubble(message: message, audio: audio)
                            .id(message.id)
                    }
                    Color.clear.frame(height: 1).id(bottomID)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture {
                isInputFocused = false
            }
            .onChange(of: vm.messages.count) { _, _ in
                withAnimation { proxy.scrollTo(bottomID, anchor: .bottom) }
            }
            .onChange(of: vm.messages.last?.content) { _, _ in
                proxy.scrollTo(bottomID, anchor: .bottom)
            }
        }
    }

    private var emptyChatState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36))
                .foregroundColor(.textTertiary)
            Text("Ask anything about your courses,\nassignments, or concepts.")
                .font(.system(size: 14))
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color.white.opacity(0.05))
            HStack(alignment: .bottom, spacing: 10) {
                voiceButton
                TextField("Message Brain Brew…", text: $vm.inputText, axis: .vertical)
                    .font(.system(size: 14))
                    .foregroundColor(.textPrimary)
                    .tint(.scarlet)
                    .lineLimit(5)
                    .focused($isInputFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.07), lineWidth: 1))

                sendButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.bgBase)
        }
    }

    private var voiceButton: some View {
        Button {
            switch recorder.state {
            case .idle: recorder.requestPermissionAndRecord()
            case .recording: recorder.stopAndTranscribe()
            default: recorder.cancel()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.scarlet : Color.bgCard)
                    .frame(width: 38, height: 38)
                Image(systemName: isRecording ? "stop.fill" : "mic")
                    .font(.system(size: 15))
                    .foregroundColor(isRecording ? .white : .textSecondary)
            }
        }
    }

    private var sendButton: some View {
        Button {
            isInputFocused = false
            Task { await vm.sendMessage() }
        } label: {
            ZStack {
                Circle()
                    .fill(vm.inputText.isEmpty ? Color.bgCard : Color.scarlet)
                    .frame(width: 38, height: 38)
                if vm.isStreaming {
                    ProgressView().progressViewStyle(.circular).scaleEffect(0.6).tint(.white)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(vm.inputText.isEmpty ? .textTertiary : .white)
                }
            }
        }
        .disabled(vm.inputText.isEmpty || vm.isStreaming)
    }

    private var isRecording: Bool {
        if case .recording = recorder.state { return true }
        return false
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    @ObservedObject var audio: AudioManager
    @State private var showTTS = false

    var isUser: Bool { message.role == "user" }
    private var formattedBlocks: [ChatFormattedBlock] {
        ChatMessageFormatter.blocks(from: message.content)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                bubbleContent
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isUser ? Color.scarlet : Color.bgCard)
                    .clipShape(BubbleShape(isUser: isUser))

                if !isUser && !message.content.isEmpty {
                    HStack(spacing: 6) {
                        Button {
                            withAnimation { showTTS.toggle() }
                        } label: {
                            Image(systemName: "speaker.wave.2")
                                .font(.system(size: 11))
                                .foregroundColor(.textTertiary)
                        }
                        if showTTS {
                            TTSPlaybackBar(audio: audio, text: message.content)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }

            if !isUser { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        if isUser {
            Text(message.content.isEmpty ? "…" : message.content)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .lineSpacing(3)
        } else {
            AssistantMessageContent(blocks: formattedBlocks)
        }
    }
}

struct BubbleShape: Shape {
    let isUser: Bool

    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 16
        var path = Path()

        if isUser {
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: r, height: r))
        } else {
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: r, height: r))
        }
        return path
    }
}

enum ChatFormattedBlock: Equatable {
    case heading(String)
    case numbered(String, String)
    case bullet(String)
    case paragraph(String)
    case code(String)
}

enum ChatMessageFormatter {
    static func blocks(from raw: String) -> [ChatFormattedBlock] {
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
        let trimmed = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return [.paragraph("…")]
        }

        var blocks: [ChatFormattedBlock] = []
        var paragraphLines: [String] = []
        var codeLines: [String] = []
        var insideCodeBlock = false

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            let joined = paragraphLines
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .joined(separator: " ")
                .replacingOccurrences(of: "  ", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty {
                blocks.append(.paragraph(joined))
            }
            paragraphLines.removeAll()
        }

        func flushCode() {
            guard !codeLines.isEmpty else { return }
            let code = codeLines.joined(separator: "\n").trimmingCharacters(in: .newlines)
            if !code.isEmpty {
                blocks.append(.code(code))
            }
            codeLines.removeAll()
        }

        for line in trimmed.components(separatedBy: "\n") {
            let stripped = line.trimmingCharacters(in: .whitespaces)

            if stripped.hasPrefix("```") {
                if insideCodeBlock {
                    flushCode()
                } else {
                    flushParagraph()
                }
                insideCodeBlock.toggle()
                continue
            }

            if insideCodeBlock {
                codeLines.append(line)
                continue
            }

            if stripped.isEmpty {
                flushParagraph()
                continue
            }

            if let heading = headingText(from: stripped) {
                flushParagraph()
                blocks.append(.heading(heading))
                continue
            }

            if let numbered = numberedItem(from: stripped) {
                flushParagraph()
                blocks.append(.numbered(numbered.index, numbered.text))
                continue
            }

            if let bullet = bulletItem(from: stripped) {
                flushParagraph()
                blocks.append(.bullet(bullet))
                continue
            }

            paragraphLines.append(stripped)
        }

        flushParagraph()
        flushCode()
        return blocks
    }

    private static func headingText(from line: String) -> String? {
        if line.hasPrefix("#") {
            return line.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).nilIfEmpty
        }

        if line.hasSuffix(":") && line.count <= 42 {
            return String(line.dropLast()).trimmingCharacters(in: .whitespaces).nilIfEmpty
        }

        return nil
    }

    private static func numberedItem(from line: String) -> (index: String, text: String)? {
        guard let dot = line.firstIndex(of: ".") else { return nil }
        let prefix = String(line[..<dot])
        guard !prefix.isEmpty, prefix.allSatisfy(\.isNumber) else { return nil }
        let text = String(line[line.index(after: dot)...]).trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : (prefix, text)
    }

    private static func bulletItem(from line: String) -> String? {
        let prefixes = ["- ", "* ", "• "]
        for prefix in prefixes where line.hasPrefix(prefix) {
            let text = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            return text.nilIfEmpty
        }
        return nil
    }
}

struct AssistantMessageContent: View {
    let blocks: [ChatFormattedBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let text):
                    Text(text.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.scarlet)
                        .tracking(1.2)
                case .numbered(let index, let text):
                    HStack(alignment: .top, spacing: 10) {
                        Text(index)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.scarlet)
                            .frame(width: 18, alignment: .leading)
                        Text(text)
                            .font(.system(size: 14))
                            .foregroundColor(.textPrimary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                case .bullet(let text):
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Color.scarlet)
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)
                        Text(text)
                            .font(.system(size: 14))
                            .foregroundColor(.textPrimary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                case .paragraph(let text):
                    Text(text)
                        .font(.system(size: 14))
                        .foregroundColor(.textPrimary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                case .code(let text):
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(text)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color.bgSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
