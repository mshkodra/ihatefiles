# Script audit & dev environment survey

Research performed while planning the Phase 0-14 implementation (see `docs/plans/2026-09-22-implementation-plan.md`). Source: the nine scripts in `~/file-converters`, and a survey of this machine's toolchain. Captures exact flags/behavior worth replicating (or deliberately fixing) in the native rewrite, so it doesn't need re-deriving later.

## Per-script findings

**`youtube_download.py`** — uses the `yt_dlp` Python library directly (not the CLI binary). MP3: `format: "bestaudio/best"` + `FFmpegExtractAudio` postprocessor, `preferredcodec: mp3`, `preferredquality: 192`. MP4: format selector `"bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"`, `merge_output_format: mp4`. No playlist handling, no progress hooks.

**`twitter_download.py`** — two-phase: probe formats via `extract_info(download=False)`, filter to video-bearing formats (`vcodec not in (None, "none")`), sort by `tbr` descending, present an interactive picker (Enter = "best"); then download using either the literal `"best"` or the chosen `format_id` as the format selector. `-f` flag skips the prompt for scriptable use. Good UX pattern, preserved as Phase 7's probe/picker.

**`png_to_jpg.py`** — `Image.open(src).convert("RGB").save(dst, "JPEG")`. The `.convert("RGB")` matters: PNG can be RGBA, JPEG has no alpha channel. No quality param (Pillow default ~75). PIL's RGB convert composites transparency onto **black**, not white — worth an explicit, deliberate choice in the native (ImageIO) rewrite rather than silently inheriting that.

**`append_image_to_pdf.py`** — PIL converts the image to a one-page in-memory PDF, pypdf appends it to the existing document, then **overwrites the source PDF path in place**. Flagged as a bug to fix, not preserve — Phase 12's `ImageToPDFRunner` writes to a new path (or confirms via save panel) instead.

**`webm_to_mp4.py`** — `ffmpeg -i <in> -c:v libx264 -preset medium -crf 23 -c:a aac -b:a 128k -y <out>`. No progress-reporting flags at all (just a blocking `subprocess.run`) — Phase 9 adds `-progress pipe:1` since none of these scripts implement real progress.

**`split_video.py`** — `ffprobe -show_entries format=duration` for total length, validates the split point is in range, then two stream-copy calls: `ffmpeg -i <in> -t <split> -c copy -y <part1>` and `ffmpeg -i <in> -ss <split> -c copy -y <part2>`. `-ss` is placed after `-i` (slow/accurate seek), inconsistent with the "fast" framing but is what's actually there. Split points snap to the nearest keyframe under stream copy — a real UX caveat to surface in the app, not just internally.

**`concat_videos.py`** vs **`concat_videos_fast.py`** — two deliberately different strategies: moviepy (`concatenate_videoclips(method="compose")`, then `write_videofile(codec='libx264', preset='ultrafast', fps=30, bitrate='5000k')`) re-encodes and tolerates mismatched resolutions; the ffmpeg concat-demuxer version (`ffmpeg -f concat -safe 0 -i <filelist.txt> -c copy`) stream-copies (fast, needs compatible codecs/resolution/fps). Phase 10 keeps both as `.compatible`/`.fast` modes, both shelling to bundled ffmpeg rather than reimplementing via AVFoundation.

**`embed_a_onto_b.py`** — picture-in-picture overlay via `ffprobe` for each input's dimensions, then a single `filter_complex` pass: webcam scaled to 20% of the screen recording's width (`overlay_width = screen_width * 0.20`), preserving the webcam's own aspect ratio, positioned at `x = screen_width - overlay_width - 20, y = 20`. That's actually **top-right** with a 20px margin, despite the docstring/comments saying "top-left" — a real comment/behavior mismatch in the original. Phase 10 standardizes on top-right (the shipped behavior) rather than "fixing" it to match the stale comment. Audio is taken implicitly from the screen recording only (webcam audio dropped) since `filter_complex` here only maps video and default stream mapping grabs audio from the first input that has it.

## Cross-cutting patterns

- **ffmpeg preflight check** (`ffmpeg -version`, catch `CalledProcessError`/`FileNotFoundError`) appears in every ffmpeg-calling script → maps to `BinaryLocator` validating the bundled binary at launch/first use (Phase 3).
- **Overwrite confirmation via `input()`** (`webm_to_mp4.py`, `split_video.py`, `embed_a_onto_b.py`) → maps to an `NSAlert`/SwiftUI confirmation dialog.
- **No progress reporting anywhere** — none of the scripts parse ffmpeg's `-progress` output, stderr `time=` lines, or use yt-dlp's `progress_hooks`. This is designed fresh for the app (Phases 4 and 9), since the queue's whole value proposition depends on real percentages.
- **stderr captured only on failure**, decoded and printed — good pattern for surfacing ffmpeg errors in-app.
- **Library → native mapping**: `PIL.Image` → `ImageIO`/`CGImageDestination`; `pypdf.PdfWriter` → `PDFKit.PDFDocument`; `moviepy`/ffmpeg-concat → continue shelling to bundled ffmpeg (avoids a second parallel muxing/encoding implementation); `yt_dlp.YoutubeDL` Python API → shell out to a **bundled standalone `yt-dlp` binary** via `Process` (Swift can't import the Python library), reconstructing the same behavior via CLI flags.

## Dev environment survey

| Item | Result |
|---|---|
| macOS | 26.3.1 (Tahoe), build 25D771280a |
| Xcode | 26.6, build 17F113 |
| Swift | 6.3.3 (swiftlang-6.3.3.1.3), target `arm64-apple-macosx26.0` |
| ffmpeg | installed via Homebrew, `/opt/homebrew/bin/ffmpeg`, v8.1, **arm64-only Mach-O** (not universal) |
| yt-dlp | installed via pip only, `/Library/Frameworks/Python.framework/.../bin/yt-dlp`, v2026.06.09 — a **Python shim script**, not a bundleable binary |
| yt-dlp via Homebrew | available (`2026.8.19`, bottled) but not installed locally; bottles are typically arch-specific too |

**Implication** (drives Phase 3's decisions): neither locally-installed copy can be bundled as-is. ffmpeg is arm64-only Mach-O — fine for this Apple Silicon dev machine, not universal. yt-dlp is a Python script requiring a full Python framework — the app needs yt-dlp's official standalone `yt-dlp_macos` release binary instead. A macOS 14/15 minimum deployment target is reasonable given the toolchain versions above; macOS 26 itself would be unnecessarily restrictive as a floor.
