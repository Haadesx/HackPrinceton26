import Foundation

// MARK: - Courses

struct Course: Codable, Identifiable, Hashable {
    let id: String
    let course_code: String
    let name: String
    let workflow_state: String
    let color: String
    let instructor: String
    let credits: Int
    let progress: Int
}

// MARK: - Assignments

struct Assignment: Codable, Identifiable, Hashable {
    let id: String
    let course_id: String
    let name: String
    let assignment_category: String
    let due_at: String
    let points_possible: Double
    let description: String?
    let status: String
    let priority: String
    let has_submitted_submissions: Bool
}

// MARK: - Announcements

struct Announcement: Codable, Identifiable, Hashable {
    let id: String
    let course_id: String
    let title: String
    let message: String
    let posted_at: String
    let author: String?
    let priority: String?
}

// MARK: - Knowledge Graph

struct ConceptNode: Codable, Identifiable, Hashable {
    let id: String
    let label: String
    let course_id: String
    let description: String
}

struct ConceptEdge: Codable, Hashable {
    let source: String
    let target: String
    let relationship: String

    init(source: String, target: String, relationship: String) {
        self.source = source
        self.target = target
        self.relationship = relationship
    }

    private enum CodingKeys: String, CodingKey {
        case source
        case target
        case relationship
        case sourceID = "source_id"
        case targetID = "target_id"
        case label
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = try container.decodeIfPresent(String.self, forKey: .source)
            ?? container.decode(String.self, forKey: .sourceID)
        target = try container.decodeIfPresent(String.self, forKey: .target)
            ?? container.decode(String.self, forKey: .targetID)
        relationship = try container.decodeIfPresent(String.self, forKey: .relationship)
            ?? container.decode(String.self, forKey: .label)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(source, forKey: .source)
        try container.encode(target, forKey: .target)
        try container.encode(relationship, forKey: .relationship)
    }
}

struct GraphData {
    var nodes: [ConceptNode]
    var edges: [ConceptEdge]
}

// MARK: - Chat

struct ChatMessage: Codable, Identifiable {
    var id: UUID = UUID()
    let role: String
    var content: String

    private enum CodingKeys: String, CodingKey {
        case role, content
    }
}

struct ChatRequest: Codable {
    let messages: [ChatMessagePayload]
    let course_context: String?
}

struct ChatMessagePayload: Codable {
    let role: String
    let content: String
}

// MARK: - Study Generation

struct GenerateRequest: Codable {
    let topic: String
    let course_id: String
    let additional_context: String?
}

struct StudyGuideResponse: Codable {
    let content: String
    let topic: String
    let course_id: String
}

struct FlashCard: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    let front: String
    let back: String
    let course_id: String

    private enum CodingKeys: String, CodingKey {
        case front, back, course_id
    }
}

struct FlashcardsResponse: Codable {
    let cards: [FlashCard]
    let topic: String
    let course_id: String
}

struct QuizQuestion: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    let question: String
    let options: [String]
    let correct_index: Int
    let explanation: String

    private enum CodingKeys: String, CodingKey {
        case question, options, correct_index, explanation
    }
}

struct QuizResponse: Codable {
    let questions: [QuizQuestion]
    let topic: String
    let course_id: String
}

// MARK: - Universities

struct UniversityResult: Codable, Identifiable, Hashable {
    var id: String { slug }
    let slug: String
    let name: String
    let location: String?
    let website: String?
}

struct UniversitySearchResponse: Codable {
    let results: [UniversityResult]
}

struct UniversityProfile: Codable {
    let slug: String
    let name: String
    let location: String?
    let programs: [String]?
    let description: String?
}

struct TranscriptImportResult: Codable {
    let status: String
    let matched_courses: [MatchedCourse]?
    let message: String?
    let filename: String?
}

struct MatchedCourse: Codable, Identifiable {
    var id: UUID = UUID()
    let course_code: String?
    let name: String
    let credits: Double?
    let grade: String?

    private enum CodingKeys: String, CodingKey {
        case course_code, name, credits, grade
    }
}

// MARK: - Health

struct HealthResponse: Codable {
    let status: String
    let k2_ready: Bool
    let gemini_fallback_ready: Bool
}

// MARK: - Helpers

extension Assignment {
    var priorityLevel: PriorityLevel {
        switch priority.lowercased() {
        case "critical": return .critical
        case "high": return .high
        case "medium": return .medium
        default: return .low
        }
    }

    var dueDateFormatted: String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso2 = ISO8601DateFormatter()
        if let date = iso.date(from: due_at) ?? iso2.date(from: due_at) {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .short
            return f.string(from: date)
        }
        return due_at
    }

    var daysUntilDue: Int? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso2 = ISO8601DateFormatter()
        guard let date = iso.date(from: due_at) ?? iso2.date(from: due_at) else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: date).day
    }
}

enum PriorityLevel: Int, Comparable {
    case low = 0, medium = 1, high = 2, critical = 3

    static func < (lhs: PriorityLevel, rhs: PriorityLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
