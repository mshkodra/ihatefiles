import SwiftUI

/// Presents the formats probed by `TwitterProbeRunner`, with an "Auto (best)"
/// default plus each specific format — mirroring twitter_download.py's
/// interactive picker (Enter = best).
struct TwitterFormatPickerSheet: View {
    let formats: [TwitterFormat]
    let onSelect: (_ formatId: String?) -> Void
    let onCancel: () -> Void

    @State private var selectedFormatId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Choose a format")
                .font(.title3.bold())
                .padding([.top, .horizontal])
                .padding(.bottom, 8)

            List(selection: $selectedFormatId) {
                Label("Auto (best)", systemImage: "wand.and.stars")
                    .tag(String?.none)

                ForEach(formats) { format in
                    formatRow(format)
                        .tag(String?.some(format.id))
                }
            }
            .listStyle(.inset)
            .frame(minWidth: 360, minHeight: 240)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Download") { onSelect(selectedFormatId) }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    private func formatRow(_ format: TwitterFormat) -> some View {
        HStack {
            Text(format.note)
            Spacer()
            if let tbr = format.tbr {
                Text("\(Int(tbr)) kbps")
                    .foregroundStyle(.secondary)
            }
            if let bytes = format.filesizeBytes {
                Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                    .foregroundStyle(.secondary)
            }
            Text(format.ext)
                .foregroundStyle(.secondary)
                .font(.caption.monospaced())
        }
        .font(.callout)
    }
}

#Preview {
    TwitterFormatPickerSheet(
        formats: [
            TwitterFormat(formatId: "832", note: "1280x720", tbr: 2500, ext: "mp4", filesizeBytes: 12_400_000),
            TwitterFormat(formatId: "631", note: "640x360", tbr: 800, ext: "mp4", filesizeBytes: 4_100_000),
        ],
        onSelect: { _ in },
        onCancel: {}
    )
}
