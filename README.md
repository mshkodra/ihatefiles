# ihatefiles

A native macOS app that replaces a folder of one-off scripts with one GUI: video/audio downloaders (YouTube, Twitter/X, generic), video/image conversion, and PDF tools, all backed by a concurrency-limited job queue so downloads run in the background while you keep working.

Built with Swift/SwiftUI, bundled `yt-dlp`/`ffmpeg`, and native `PDFKit`/`ImageIO`. See `CLAUDE.md` for architecture.
