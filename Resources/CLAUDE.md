# Resources

Bundled binaries (`yt-dlp`, `ffmpeg`) and static app assets (icons, images). This directory holds what ships inside the app bundle's `Contents/Resources/`, plus the helper code that locates those binaries at runtime.

## Belongs here

- Vendored `yt-dlp`/`ffmpeg` executables (or the build step that fetches/copies them in)
- A small helper for resolving the bundled binary path at runtime, used by Downloaders and Converters
- App icon and other static assets

## Does NOT belong here

- Any logic that constructs command-line arguments or parses tool output — see Downloaders and Converters instead
- The job queue — see Core instead

## Non-obvious patterns

<!-- Fill in as decisions get made for this module specifically. -->
