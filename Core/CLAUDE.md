# Core

The Job model and JobManager: the concurrency-limited queue engine that every download and conversion runs through. This is the shared spine the UI observes and the runners report progress into — it has no knowledge of SwiftUI or of any specific tool (yt-dlp, ffmpeg, PDFKit).

## Belongs here

- The `Job` type (id, kind, input, status, progress) and its status lifecycle (queued/running/done/failed/cancelled)
- `JobManager`: owns the job list, enforces the download concurrency cap (queues extra downloads until a slot frees), and runs conversions immediately/in parallel without that cap
- Shared protocols/types that Downloaders and Converters runners conform to, so JobManager can drive any of them uniformly
- Cancellation plumbing

## Does NOT belong here

- SwiftUI views or view state — see App instead
- The actual `Process` invocations for yt-dlp/ffmpeg, or PDFKit/ImageIO calls — see Downloaders and Converters instead

## Non-obvious patterns

<!-- Fill in as decisions get made for this module specifically. -->
