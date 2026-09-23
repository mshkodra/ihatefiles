# ihatefiles — Implementation Plan

## Context

`ihatefiles` replaces a folder of one-off Python/ffmpeg scripts (`~/file-converters`) with a single native macOS GUI: YouTube/Twitter/generic downloaders (MP4/MP3/thumbnail, playlists), video tools (convert/split/concat/overlay), image tools (convert/resize/compress), and PDF tools (merge/split/rotate/extract/compress/image-to-pdf). Its defining feature is a unified job queue — downloads are concurrency-capped and queue when the cap is hit, conversions run immediately/uncapped, and everything shows in one live Activity list — so the user can queue several downloads and keep working in other tool sections while they finish in the background.

The repo (`mshkodra/ihatefiles`, public) is bootstrapped with a layered CLAUDE.md architecture (App/Core/Downloaders/Converters/Resources, each scoped) and a 300-line-per-file hook, but contains zero Swift source yet. A UI mockup was already designed and approved (sidebar nav + persistent bottom progress strip + full Queue view with grouped history — https://claude.ai/artifact/VaBwtnhGdWYxGps49FPSpH). Research into the existing Python scripts extracted the exact yt-dlp/ffmpeg flags and behaviors to replicate (see per-phase notes below); none of them implement real progress reporting, so that's designed fresh here.

**New hard rule starting now**: every phase lands as its own branch + PR, never a direct push to `master`.

## Ground rules

- **Project format**: a real `.xcodeproj` (SwiftUI App lifecycle, macOS App template), not an SPM executable — needed for a proper `.app` bundle (icon, Info.plist, `MenuBarExtra`, Copy-Files build phases for vendored binaries).
- **Module boundaries**: Core/Downloaders/Converters/Resources stay as groups in one app target (not separate SPM libraries) — keeps iteration fast; boundaries enforced by the existing CLAUDE.md convention + PR review, not the compiler. Worth revisiting (extract Core into a local package) only if the project grows much further.
- **Deployment target**: macOS 15 (Sequoia+) — dev machine runs macOS 26/Xcode 26.6/Swift 6.3.3, no need to support older systems for a personal tool, and macOS 15 gives `@Observable`/`NavigationSplitView` without back-compat shims.
- **Sandbox**: disabled for v1 — the app's core job is spawning arbitrary `Process` subprocesses against user-chosen files anywhere on disk; sandboxing that cleanly needs security-scoped bookmarks/XPC helpers with no payoff until (if ever) shipping via the App Store.
- **Testing**: one `ihatefilesTests` XCTest target, created in Phase 1, grows as phases add files.
- **Binary vendoring**: `yt-dlp`/`ffmpeg` are NOT committed to the (public) git repo — they're fetched by a checked-in, checksum-pinned script into a gitignored `Resources/bin/`. Avoids repo bloat and redistribution-license ambiguity.

## Phase 0 — Xcode Project Skeleton

**Goal**: buildable, runnable, empty SwiftUI window; existing directories wired in as Xcode groups. First PR — establishes the branch/PR workflow in practice.

**Build**: `ihatefiles.xcodeproj` (macOS App template, SwiftUI lifecycle, macOS 15 target, sandbox off). `App/ihatefilesApp.swift` (`@main`, one `WindowGroup`). `App/ContentView.swift` (trivial placeholder). Add `Core/`, `Downloaders/`, `Converters/`, `Resources/` as file-system-synchronized groups so files dropped there later compile automatically.

**Verify**: ⌘B zero errors, ⌘R shows the placeholder window, all five directories visible in the navigator. Push branch, open PR, merge.

## Phase 1 — Core Domain Model & Queue Engine (fake runner)

**Goal**: the architectural crux. Build `Job`/`JobManager`/`JobRunner` and prove concurrency-cap + cancellation correctness with unit tests against a simulated runner — zero dependency on SwiftUI, yt-dlp, or ffmpeg. Highest-risk piece; must be right before anything builds on it.

**Build**:
- `Core/Job.swift` — `struct Job: Identifiable`: `id`, `kind: JobKind`, `input`, `status` (`.queued/.running/.done/.failed/.cancelled`), `progress: Double`, `createdAt`/`updatedAt`.
- `Core/JobKind.swift` — enum of subtypes, extended by later phases.
- `Core/JobRunner.swift` — protocol: `func run(job: Job, progress: @escaping (Double) -> Void) async throws`, `func cancel()`.
- `Core/JobManager.swift` (+ `Core/JobManager+Scheduling.swift` if it nears the line cap) — owns `[Job]` and a configurable `downloadConcurrencyLimit`; downloads beyond the cap sit `.queued` until a slot frees, conversions run immediately/uncapped in a new `Task`.
- `Core/CancellationToken.swift` — `JobManager.cancel(jobId:)` calls the runner's `cancel()` and frees a slot immediately.
- `ihatefilesTests/FakeRunner.swift` — simulates progress via `Task.sleep` ticks, configurable to fail.
- `ihatefilesTests/JobManagerTests.swift` — cap=2/5 downloads → only 2 running, a finished slot frees the next queued one; cap=2/5 conversions → all 5 run immediately; cancel frees a slot; a failure doesn't block the rest of the queue.

**Verify**: ⌘U, all `JobManagerTests` pass. No UI needed — correctness proven by tests.

## Phase 2 — Navigation Shell + Live Queue UI (still fake jobs)

**Goal**: build the real sidebar/Queue/progress-strip UI from the mockup, wired live to `JobManager`, proving the live-progress pipeline before any real-tool risk.

**Build**: `App/AppSection.swift` (sidebar destinations). `App/RootView.swift` (`NavigationSplitView`, sidebar + detail + persistent bottom `ProgressStrip`). `App/Views/PlaceholderToolView.swift` (stand-in for the four tool sections, with a debug button enqueuing `FakeRunner` jobs for this phase only). `App/Views/QueueView.swift` (flat list bound to `JobManager.jobs`; grouped styling deferred to Phase 13). `App/Views/StatusPill.swift`. `App/Views/ProgressStrip.swift` ("N running · N queued · N done"). `JobManager` constructed once in `ihatefilesApp.swift` and shared via `@Environment`.

**Verify**: build & run, navigate all 5 sections confirming the strip persists and stays live. Enqueue fake jobs with cap=2, visually confirm exactly 2 `.running` at a time, rest `.queued`, pills recolor on completion, strip counts match Queue.

## Phase 3 — Binary Vendoring Infrastructure

**Goal**: get real `yt-dlp`/`ffmpeg` into the app bundle reproducibly, prove they're resolvable/executable. No downloader/converter logic yet.

**Decisions**: `yt-dlp` — vendor the official `yt-dlp_macos` GitHub release binary, pinned to a specific version tag. `ffmpeg` — ship **arm64-only** for v1 via a statically-linked redistribution-safe build (e.g. evermeet.cx's LGPL/"shared" variant, to sidestep GPL obligations) — not the local Homebrew build (dynamically links Homebrew-prefix dylibs, not relocatable), not a self-built lipo universal (can't be tested — dev machine is Apple Silicon-only). Revisit if Intel support is ever requested.

**Build**: `Resources/Scripts/fetch-binaries.sh` (pinned versions/URLs/SHA256, downloads + chmod +x + checksum-verifies, fails loudly on mismatch). `Resources/VERSIONS.md` (checked-in record; upgrades = deliberate diff + re-run). `Resources/Licenses/{yt-dlp,ffmpeg}-LICENSE`. `Resources/BinaryLocator.swift` (`static var ytDlpURL/ffmpegURL: URL`, throws a clear "run fetch-binaries.sh" error if missing). Xcode Run Script phase invokes the fetch script if `Resources/bin/` is stale; Copy Files phase ships the binaries into `Contents/Resources/`. `.gitignore` excludes `Resources/bin/`.

**Verify**: run the fetch script once, confirm checksums match. Build & run; a temporary DEBUG-only check shells both binaries' `--version`/`-version` via `BinaryLocator` and prints to console. Remove/gate before Phase 4.

## Phase 4 — Vertical Slice: YouTube Single Video → MP4

**Goal**: first real end-to-end feature — paste a URL, real download, real progress in the Phase 2 UI, file on disk.

**Build**: `Downloaders/ProcessRunning.swift` (shared `Process`+`Pipe`+stdout-streaming helper — every later runner reuses this). `Downloaders/YouTubeVideoRunner.swift` (argv: `yt-dlp <url> -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" --merge-output-format mp4 -o <template> --newline` — `--newline` added vs. the old script so progress lines are parseable). `Downloaders/YtDlpProgressParser.swift` (parses `[download]  NN.N%` lines; unit-tested with fixtures). `App/Views/DownloaderView.swift` (URL field + "Download as MP4"; other buttons stubbed). `ihatefilesTests/YtDlpProgressParserTests.swift`.

**Verify**: paste a real public YouTube URL, confirm progress climbs live in strip + Queue, confirm child processes actually spawn (`ps`), confirm `.done` + playable file on disk. Cancel mid-download → `.cancelled`, no orphaned process.

## Phase 5 — MP3 Extraction + Thumbnail Extraction

**Goal**: round out the single-video slice.

**Build**: `YouTubeVideoRunner` extended with a `DownloadFormat` (`.mp4`/`.mp3`) — MP3 branch adds `-x --audio-format mp3 --audio-quality 192K`. `Downloaders/ThumbnailRunner.swift` (`--write-thumbnail --skip-download --convert-thumbnails jpg`). `DownloaderView` enables the MP3/Thumbnail buttons.

**Verify**: download the same test URL as MP3 (confirm ~192kbps) and thumbnail-only (image, no video); both show correct progress/completion.

## Phase 6 — YouTube Playlist Downloads

**Goal**: playlist support with per-video progress/failure visibility, not one opaque blob job.

**Build**: `Job` gets `parentId: UUID?` for playlist grouping. `Downloaders/YouTubePlaylistRunner.swift` (`-o` template with `%(playlist_index)s - %(title)s.%(ext)s`, parses `Downloading item N of M` to fan out one child `Job` per entry). `DownloaderView` detects playlist URLs and routes accordingly.

**Verify**: download a short real playlist (2-3 videos); each is its own Queue entry with independent progress; parent/child grouping renders sensibly; files correctly named/ordered.

## Phase 7 — Twitter/X Downloads

**Goal**: preserve the old script's "auto-best vs. explicit format picker" UX.

**Build**: `Downloaders/TwitterProbeRunner.swift` (`yt-dlp -F`/`--dump-json` without downloading, filters to video-bearing formats sorted by bitrate). `Downloaders/TwitterDownloadRunner.swift` (`-f best` auto, or `-f <format_id>` explicit). `App/Views/TwitterFormatPickerSheet.swift`.

**Verify**: paste a real X video URL, probe returns a sensible list, download via both Auto and an explicit pick, confirm correct resolution on disk.

## Phase 8 — Generic yt-dlp URL Runner

**Goal**: catch-all for any yt-dlp-supported site.

**Build**: `Downloaders/GenericURLRunner.swift` (default best-format, reuses `ProcessRunning`/`YtDlpProgressParser`). `Downloaders/URLSniffer.swift` (host-based routing so `DownloaderView` becomes one smart field dispatching to YouTube/Twitter/generic).

**Verify**: paste a URL from a third supported site, confirm it downloads via the generic path and appears correctly in Queue.

## Phase 9 — Video Converter: Convert (real progress)

**Goal**: first Converters runner; first real proof (not just unit-tested) that conversions run uncapped alongside capped downloads.

**Build**: `Converters/VideoConvertRunner.swift` (`ffmpeg -i <in> -c:v libx264 -preset medium -crf 23 -c:a aac -b:a 128k -progress pipe:1 -y <out>` — `-progress pipe:1` added vs. the old script). `Converters/FfmpegProgressParser.swift` (parses `out_time_ms=`/`progress=` against known duration; unit-tested). `Converters/VideoDurationProbe.swift` (ffprobe, reused by split/concat). `App/Views/VideoToolView.swift` (file picker, format, Convert button).

**Verify**: convert a real `.webm`→`.mp4`, confirm smooth progress and playable output. Specifically confirm in Queue that this conversion runs immediately even while a download sits `.queued` behind the cap — the real-app proof of Phase 1's tested behavior.

## Phase 10 — Video Converter: Split, Concat, Overlay

**Goal**: round out video tools; make the concat strategy explicit.

**Decision**: keep shelling to `ffmpeg` for both concat modes rather than reimplementing via `AVMutableComposition`/`AVAssetExportSession` — avoids a second parallel muxing path; the Process machinery already exists.

**Build**: `Converters/VideoSplitRunner.swift` (`VideoDurationProbe` + two stream-copy `ffmpeg -ss/-t -c copy` calls). `Converters/VideoConcatRunner.swift` (`.fast` = concat demuxer/`-c copy`, validates matching codecs first with a clear error if mismatched; `.compatible` = `-filter_complex concat`, re-encodes, handles mismatched resolutions). `Converters/VideoOverlayRunner.swift` (filter_complex overlay, webcam at 20% of screen width preserving its own aspect ratio, positioned **top-right** with 20px margin — fixing the old script's top-left comment vs. top-right actual behavior). Split into `VideoSplitPanel.swift`/`VideoConcatPanel.swift`/`VideoOverlayPanel.swift` for the line cap.

**Verify**: split at a timestamp, confirm correctly-lengthed outputs. Concat same-codec clips (fast, near-instant) and mismatched-resolution clips (compatible mode). Overlay a webcam clip, visually confirm top-right placement at ~20% width with correct aspect ratio.

## Phase 11 — Image Converter

**Goal**: first fully-native runner (no bundled binary).

**Build**: `Converters/ImageConvertRunner.swift` (ImageIO/`CGImageDestination`-based convert, resize, compress-quality; progress jumps 0→1 since ImageIO gives no fine-grained progress — document as a legitimate exception in Converters' CLAUDE.md). `App/Views/ImageToolView.swift`.

**Verify**: convert `.png`→`.jpg`, confirm correct RGB flattening (no alpha corruption, matching old `.convert("RGB")` behavior but making the flattening choice explicit); resize confirms dimensions; compress confirms reduced size at acceptable quality.

## Phase 12 — PDF Tools

**Goal**: complete the ihatepdf.cv-equivalent set via PDFKit, fixing the old in-place-overwrite bug.

**Build**: `Converters/PDFMergeRunner.swift`, `PDFSplitRunner.swift`, `PDFPageOpsRunner.swift` (rotate + extract), `PDFCompressRunner.swift`, `ImageToPDFRunner.swift` — one small file per operation. **Bug fix**: `ImageToPDFRunner`'s append-to-existing-PDF mode writes to a new output path (or confirms via `NSSavePanel`) instead of silently overwriting the source, unlike `append_image_to_pdf.py`. `App/Views/PDFToolView.swift` (+ sub-panels as needed).

**Verify**: merge 2+ PDFs (correct order), split (correct ranges), rotate/extract/compress (visual check), append an image to a PDF and confirm the **original file is untouched** with a new file produced.

## Phase 13 — Queue View Polish & Full UI Fidelity

**Goal**: close the gap to the approved mockup now that every job kind exists to populate it meaningfully.

**Build**: `App/Views/QueueGrouping.swift` (pure function bucketing `[Job]` into In Progress / Needs Attention / Today / Earlier). `QueueView` reworked to render grouped sections. `StatusPill` refined to the mockup's exact colors. `ProgressStrip` visual refinement.

**Verify**: side-by-side comparison against the mockup for all groupings/colors. Mixed scenario (queued-behind-cap downloads, immediately-running conversions, one failed job, some done today/earlier) — confirm every job lands in its expected bucket.

## Phase 14 — Settings, Cancellation Polish, Menu Bar Extra, Housekeeping

**Goal**: last-mile polish, deliberately last.

**Build**: `App/AppSettings.swift` (`@AppStorage`: concurrency cap, default output dir, default quality) + `App/SettingsView.swift` feeding `JobManager`'s cap. `App/MenuBarExtraView.swift` + `MenuBarExtra` scene. Cancellation UX audit across all views. Final app icon. Root `CLAUDE.md` "Non-obvious patterns" filled in with real decisions made along the way (sandbox off, arm64-only ffmpeg, binaries fetched-not-committed, dual concat strategy, top-right overlay fix, PDF overwrite fix).

**Verify**: change the concurrency cap in Settings, confirm `JobManager` respects it live and persists across relaunch; menu bar extra shows live counts with the main window closed; full manual pass through every tool section against the mockup.

## Critical files

- `Core/JobManager.swift`, `Core/Job.swift`, `Core/JobRunner.swift` — the queue engine every runner and the UI depend on.
- `Downloaders/YouTubeVideoRunner.swift`, `Downloaders/ProcessRunning.swift` — the first real vertical slice and the shared subprocess pattern every later runner copies.
- `Resources/BinaryLocator.swift` — where every runner resolves bundled binaries from.
