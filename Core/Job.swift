import Foundation

enum JobStatus: String, Codable, Sendable {
    case queued
    case running
    case done
    case failed
    case cancelled
}

struct Job: Identifiable, Sendable {
    let id: UUID
    let kind: JobKind
    let input: String
    var status: JobStatus
    var progress: Double
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        kind: JobKind,
        input: String,
        status: JobStatus = .queued,
        progress: Double = 0,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.input = input
        self.status = status
        self.progress = progress
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}
