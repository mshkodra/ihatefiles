import SwiftUI

struct StatusPill: View {
    let status: JobStatus

    var body: some View {
        Text(label)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var label: String {
        switch status {
        case .queued: return "Queued"
        case .running: return "Running"
        case .done: return "Done"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    private var color: Color {
        switch status {
        case .queued: return .gray
        case .running: return .accentColor
        case .done: return .green
        case .failed: return .red
        case .cancelled: return .orange
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        ForEach([JobStatus.queued, .running, .done, .failed, .cancelled], id: \.self) { status in
            StatusPill(status: status)
        }
    }
    .padding()
}
