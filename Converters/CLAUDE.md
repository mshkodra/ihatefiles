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

<!-- Fill in as decisions get made for this module specifically. -->
