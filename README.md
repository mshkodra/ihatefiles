# ihatefiles

A native macOS app that replaces a folder of one-off scripts with one GUI: video/audio downloaders (YouTube, Twitter/X, generic), video/image conversion, and PDF tools, all backed by a concurrency-limited job queue so downloads run in the background while you keep working.

Built with Swift/SwiftUI, bundled `yt-dlp`/`ffmpeg`, and native `PDFKit`/`ImageIO`. See `CLAUDE.md` for architecture.

## Setup

1. Run `Resources/Scripts/fetch-binaries.sh` to download the vendored `yt-dlp`/`ffmpeg` binaries into `Resources/bin/` (gitignored, checksum-verified — see `Resources/VERSIONS.md` for what's pinned and why).
2. Run `xcodegen generate` to produce `ihatefiles.xcodeproj` before opening/building — it's gitignored since it's fully derived from `project.yml`. The project also re-runs step 1 automatically as a build phase, so it's safe to skip manually, but running it once up front avoids the first build silently blocking on a download.
