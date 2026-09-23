# App

SwiftUI views, the app entry point, and navigation/window scenes. This is the presentation layer only — it displays state from Core and triggers actions on it, and never runs a download or conversion itself.

## Belongs here

- The `App` struct and `WindowGroup`/`Scene` definitions
- SwiftUI views for each tool section (Downloader, Video, Image, PDF) and the Queue/Activity panel
- View-local state (e.g. form input bindings, selected tab) and navigation structure
- File pickers (`NSOpenPanel`/`NSSavePanel`) and drag-and-drop handling that hands off input paths to Core

## Does NOT belong here

- Job queue logic, concurrency limiting, or process spawning — see Core instead
- Direct calls to `yt-dlp`/`ffmpeg`/`PDFKit` — see Downloaders and Converters instead

## Non-obvious patterns

<!-- Fill in as decisions get made for this module specifically. -->
