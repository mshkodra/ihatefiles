# ihatefiles

A native macOS app (Swift/SwiftUI) that replaces a folder of one-off terminal scripts with a single GUI file-utility tool: video/audio downloaders (YouTube, Twitter/X, generic yt-dlp-supported sites, with thumbnail extraction), video tools (convert/split/concat/overlay), image tools (convert/resize/compress), and PDF tools equivalent to ihatepdf.cv (merge/split/rotate/extract/compress/image-to-pdf). Its key differentiator is a unified job queue: downloads are concurrency-limited and queue when the cap is hit, while conversions run immediately in parallel, and every job (queued/running/done/failed) shows in one Activity list with progress and cancel support.

## Stack

- Swift + SwiftUI (macOS app target, built via Xcode)
- Bundled `yt-dlp` and `ffmpeg` binaries invoked via `Process` for downloads/video conversion
- Native `PDFKit` for PDF operations, `ImageIO`/`CoreImage` for image operations
- Swift concurrency (`async`/`await`, actors) for the job queue and concurrency-limited downloads

## Commands

- Install: open `ihatefiles.xcodeproj` (or `.xcworkspace`) in Xcode — no package manager step yet
- Run: build and run from Xcode (⌘R)
- Test: run the test target from Xcode (⌘U)
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

<!-- Fill in as real decisions get made — the highest-value content in this file. Things like "why X instead of the obvious Y", intentional deviations from convention, gotchas a new contributor (or agent) would otherwise rediscover the hard way. -->

## Adding a new module

Use the `add-module` skill rather than creating a directory by hand — it scaffolds the directory, its scoped CLAUDE.md, and adds a row to the table above.
