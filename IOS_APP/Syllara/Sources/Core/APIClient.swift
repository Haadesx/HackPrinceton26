import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int, String)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .networkError(let e): return e.localizedDescription
        case .decodingError(let e): return "Decoding failed: \(e.localizedDescription)"
        case .serverError(let code, let msg): return "Server error \(code): \(msg)"
        case .noData: return "No data received"
        }
    }
}

@MainActor
final class APIClient: ObservableObject {
    private static let defaultBaseURL: String = {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "BrainBrewAPIBaseURL") as? String,
           !configured.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return configured
        }
        return "http://127.0.0.1:8000"
    }()

    static let shared = APIClient()
    var baseURL: String = defaultBaseURL

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        return URLSession(configuration: config)
    }()

    private func url(_ path: String) throws -> URL {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        return url
    }

    // MARK: - Generic GET

    func get<T: Decodable>(_ path: String) async throws -> T {
        let request = URLRequest(url: try url(path))
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try decode(T.self, from: data)
    }

    // MARK: - Generic POST

    func post<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response {
        var request = URLRequest(url: try url(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try decode(Response.self, from: data)
    }

    // MARK: - Multipart POST (for file upload)

    func postMultipart(_ path: String, fields: [String: String], fileData: Data, fileName: String, mimeType: String) async throws -> Data {
        var request = URLRequest(url: try url(path))
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return data
    }

    // MARK: - SSE Streaming Chat

    func streamChat(request chatRequest: ChatRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var request = URLRequest(url: try self.url("/api/chat"))
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.httpBody = try JSONEncoder().encode(chatRequest)

                    let (bytes, response) = try await self.session.bytes(for: request)
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                        continuation.finish(throwing: APIError.serverError(httpResponse.statusCode, "Chat stream failed"))
                        return
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let raw = String(line.dropFirst(6))
                        if raw == "[DONE]" { break }
                        if let data = raw.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let content = json["content"] as? String {
                            continuation.yield(content)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Helpers

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(http.statusCode, msg)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}

// MARK: - Endpoint helpers

extension APIClient {
    func fetchHealth() async throws -> HealthResponse {
        try await get("/api/health")
    }

    func fetchCourses() async throws -> [Course] {
        try await get("/api/courses")
    }

    func fetchAssignments() async throws -> [Assignment] {
        try await get("/api/assignments")
    }

    func fetchAnnouncements() async throws -> [Announcement] {
        try await get("/api/announcements")
    }

    func fetchConcepts() async throws -> [ConceptNode] {
        try await get("/api/concepts")
    }

    func fetchConnections() async throws -> [ConceptEdge] {
        try await get("/api/connections")
    }

    func generateStudyGuide(_ req: GenerateRequest) async throws -> StudyGuideResponse {
        try await post("/api/generate/study-guide", body: req)
    }

    func generateFlashcards(_ req: GenerateRequest) async throws -> FlashcardsResponse {
        try await post("/api/generate/flashcards", body: req)
    }

    func generateQuiz(_ req: GenerateRequest) async throws -> QuizResponse {
        try await post("/api/generate/quiz", body: req)
    }

    func searchUniversities(query: String) async throws -> UniversitySearchResponse {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await get("/api/universities/search?q=\(encoded)")
    }

    func fetchUniversityProfile(slug: String) async throws -> UniversityProfile {
        try await get("/api/universities/\(slug)/profile")
    }

    func importTranscript(universitySlug: String, fileData: Data, fileName: String) async throws -> TranscriptImportResult {
        let raw = try await postMultipart(
            "/api/transcript/import",
            fields: ["university_slug": universitySlug],
            fileData: fileData,
            fileName: fileName,
            mimeType: fileName.hasSuffix(".pdf") ? "application/pdf" : "text/plain"
        )
        return try decode(TranscriptImportResult.self, from: raw)
    }

    func textToSpeech(text: String, voiceId: String? = nil) async throws -> Data {
        struct VoiceRequest: Encodable { let text: String; let voice_id: String? }
        var req = URLRequest(url: try url("/api/voice"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(VoiceRequest(text: text, voice_id: voiceId))
        let (data, response) = try await session.data(for: req)
        try validateResponse(response, data: data)
        return data
    }

    func transcribeAudio(fileData: Data, fileName: String = "recording.m4a") async throws -> String {
        let raw = try await postMultipart(
            "/api/transcribe",
            fields: [:],
            fileData: fileData,
            fileName: fileName,
            mimeType: "audio/m4a"
        )
        struct TranscribeResponse: Decodable { let text: String }
        let result = try decode(TranscribeResponse.self, from: raw)
        return result.text
    }
}
