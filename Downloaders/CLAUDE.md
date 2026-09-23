# Downloaders

Runners that wrap the bundled `yt-dlp` binary for YouTube, Twitter/X, playlist, and generic-URL downloads, including thumbnail extraction. Each runner builds a command line, spawns it via `Process`, and parses stdout into progress updates for a `Job`.

## Belongs here

- One runner per source (YouTube video, YouTube playlist, Twitter/X, generic yt-dlp URL)
- yt-dlp argument construction (format/quality selection, output paths, thumbnail flags)
- Parsing yt-dlp's `[download] NN.N%` stdout lines into `Job` progress updates

## Does NOT belong here

- The concurrency cap or queue ordering — see Core instead, which decides when a runner is allowed to start
- Video/image/PDF conversion (ffmpeg/PDFKit/ImageIO) — see Converters instead
- Bundling/locating the yt-dlp binary itself — see Resources instead

## Non-obvious patterns

<!-- Fill in as decisions get made for this module specifically. -->
