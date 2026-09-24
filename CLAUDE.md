# ihatefiles

A native macOS app (Swift/SwiftUI) that replaces a folder of one-off terminal scripts with a single GUI file-utility tool: video/audio downloaders (YouTube, Twitter/X, generic yt-dlp-supported sites, with thumbnail extraction), video tools (convert/split/concat/overlay), image tools (convert/resize/compress), and PDF tools equivalent to ihatepdf.cv (merge/split/rotate/extract/compress/image-to-pdf). Its key differentiator is a unified job queue: downloads are concurrency-limited and queue when the cap is hit, while conversions run immediately in parallel, and every job (queued/running/done/failed) shows in one Activity list with progress and cancel support.

## Stack

- Swift + SwiftUI (macOS app target, built via Xcode)
- Bundled `yt-dlp` and `ffmpeg` binaries invoked via `Process` for downloads/video conversion
- Native `PDFKit` for PDF operations, `ImageIO`/`CoreImage` for image operations
- Swift concurrency (`async`/`await`, actors) for the job queue and concurrency-limited downloads

## Commands

- Install: `xcodegen generate` to produce `ihatefiles.xcodeproj` (it's gitignored — `project.yml` is the source of truth), then open it in Xcode
- Run: build and run from Xcode (⌘R), or `xcodebuild -scheme ihatefiles build`
- Test: ⌘U in Xcode, or `xcodebuild -scheme ihatefiles test`
- Lint: none configured yet

## Directory map

| Path | Purpose |
|---|---|
| App | SwiftUI views, app entry point, navigation/window scenes |
| Core | Job model, JobManager (concurrency-limited queue engine), shared types/protocols |
| Downloaders | YouTube/Twitter/generic download runners wrapping bundled yt-dlp |
| Converters | Video/image/PDF conversion runners (ffmpeg, ImageIO, PDFKit) |
| Resources | Bundled binaries (yt-dlp, ffmpeg) and static app assets |
| docs | Implementation plans and research findings |

Directories with their own CLAUDE.md have scoped rules — read that file before working inside them.

## File size policy

Source files are capped at 300 lines. This is enforced by a PreToolUse hook (`.claude/hooks/check_line_limit.py`) — a Write or Edit that would push a file over the limit is blocked, not just discouraged. Split a growing file into smaller modules instead of raising the limit.

## Non-obvious patterns

- **App Sandbox is off.** The app's whole job is spawning arbitrary subprocesses against user-chosen files anywhere on disk — sandboxing that cleanly needs security-scoped bookmarks/XPC helpers, with no payoff until (if ever) shipping via the App Store.
- **`ihatefiles.xcodeproj` is gitignored and generated.** `project.yml` (XcodeGen) is the single source of truth, since XcodeGen can't produce Xcode 16's auto-syncing folder groups — every new file needs a fresh `xcodegen generate`, and committing the generated project would mean a noisy mechanical diff on every phase's changes.
- **Vendored `ffmpeg` is arm64-only and GPL v2+, not LGPL.** No genuine LGPL arm64 build was actually available when sourced (Phase 3) — accepted for personal use; revisit (source or build a true LGPL binary) only if the app is ever distributed to other people, since GPL obligations kick in on distribution, not personal use.
- **No `ffprobe` is vendored.** `VideoDurationProbe`/`VideoDimensionsProbe` parse ffmpeg's own stderr (`Duration:` / `Stream #...Video:...WIDTHxHEIGHT` lines) instead of shelling to a second binary — ffmpeg alone is sufficient for duration/dimension probing here.
- **Video overlay is intentionally top-right, not top-left.** The original Python script's comments said "top-left" but its actual math placed the overlay top-right with a 20px margin — the rewrite standardizes on the real (top-right) behavior and drops the stale comment.
- **PDF image-append can't overwrite its source.** `ImageToPDFRunner` throws if the output path equals an existing-PDF input path, making the old script's silent-overwrite bug structurally impossible rather than just documented against.
- **Concurrency cap changes take effect live.** `JobManager.downloadConcurrencyLimit` has a `didSet` that immediately starts any newly-affordable queued downloads — changing it from Settings doesn't wait for an unrelated enqueue/finish event to notice.
- **Workflow: no PRs.** Early phases used branch+PR; from Phase 7 onward the project settled into committing straight to `master` for faster unattended iteration through the phased plan.

## Adding a new module

Use the `add-module` skill rather than creating a directory by hand — it scaffolds the directory, its scoped CLAUDE.md, and adds a row to the table above.
