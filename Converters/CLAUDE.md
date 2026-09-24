# Converters

Runners for video, image, and PDF operations: video convert/split/concat/overlay via the bundled `ffmpeg` binary, image convert/resize/compress via `ImageIO`/`CoreImage`, and PDF merge/split/rotate/extract/compress/image-to-pdf via `PDFKit`. These run immediately/in parallel and are not subject to the download concurrency cap.

## Belongs here

- One runner per operation family (video, image, PDF), each reporting progress into a `Job`
- ffmpeg argument construction and `-progress pipe:1` parsing for video ops
- Native `PDFKit`/`ImageIO` calls for PDF and image ops (prefer these over shelling out where Apple's frameworks cover the operation)

## Does NOT belong here

- Download logic (yt-dlp) — see Downloaders instead
- Queue ordering or the download concurrency cap — see Core instead
- Bundling/locating the ffmpeg binary itself — see Resources instead

## Non-obvious patterns

- `ImageConvertRunner` jumps progress straight from 0 to 1 on completion rather than reporting intermediate values. This is intentional, not a bug: ImageIO/CoreGraphics operations are synchronous with no fine-grained progress signal to parse, unlike ffmpeg's `-progress pipe:1` or yt-dlp's percentage lines. Don't try to fake interpolated progress for native (non-subprocess) runners.
- Converting to JPEG explicitly flattens alpha onto a chosen background color (white, by default) rather than leaving it undefined or inheriting the old Python script's `PIL.Image.convert("RGB")` behavior, which silently composited onto black.
