# Vendored binary versions

Mirrors what `Resources/Scripts/fetch-binaries.sh` pins. An upgrade means bumping the version/URL/checksum in *both* places and re-running the script — never edit `Resources/bin/` contents by hand.

| Binary | Version | Source | Checksum verified against |
|---|---|---|---|
| yt-dlp | `2026.08.19` | [yt-dlp GitHub release](https://github.com/yt-dlp/yt-dlp/releases/tag/2026.08.19), `yt-dlp_macos` asset (universal x86_64+arm64) | yt-dlp's own published `SHA2-256SUMS` for this release |
| ffmpeg | `9.0` (arm64) | [osxexperts.net](https://www.osxexperts.net/), `ffmpeg9arm.zip` | Self-computed at fetch time (see below — no official checksum is published by the source) |

## Deviations from the original plan (read before changing sourcing)

The plan called for ffmpeg from evermeet.cx, specifically an LGPL/"shared" (non-GPL) build, to avoid GPL redistribution obligations. Verified at Phase 3 implementation time that **neither assumption holds**:

- evermeet.cx's `ffmpeg`/release build is **x86_64 only** — there is no arm64 build available there.
- evermeet.cx does not offer an LGPL-only variant at all; its only build is configured `--enable-gpl` (statically links libx264/libx265), making it **GPL v2+**, not LGPL.

osxexperts.net's `ffmpeg9arm.zip` was substituted since it's an actual arm64 build with no Homebrew-prefix dylib dependencies (`otool -L` shows only Apple system frameworks — relocatable, satisfies the plan's "redistribution-safe" intent on that specific axis). Its `ffmpeg -version` output confirms it's also built with `--enable-gpl`, so it is **GPL v2+ as well** — the same licensing situation the plan was trying to avoid, just from the only arm64 source found rather than a deliberately-chosen one.

**This needs a human decision before the app is distributed to anyone beyond local personal use**: ship as GPL (meaning the app's own source likely needs to be GPL-compatible or offered alongside, depending on how tightly the binary is invoked vs. linked — invoking it as a separate `Process`, as this app does, is the common way apps route around GPL viral-licensing concerns, but that's a legal read worth confirming, not an engineering one), find/build a genuine LGPL-only arm64 ffmpeg, or accept the current state for a personal-use app that was never going to hit the App Store anyway. Not resolved as part of this phase — flagged here and in the PR for a decision.

Also worth noting: yt-dlp's checksum is verified against the **project's own published** `SHA2-256SUMS` file (strong provenance). ffmpeg's checksum is **self-computed at fetch time** and pinned here — osxexperts.net doesn't publish an independent checksum to verify against, so this is "consistent every time we fetch it," not "independently attested by the source," a materially weaker guarantee.
