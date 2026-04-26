#pragma once

#include <QString>

// DownloadPaths
// ─────────────
// Free functions for picking a sane on-disk filename for a download. Pulled
// out of DownloadsModel so the cross-platform sanitization rules + the
// collision-resolution loop can be unit-tested without spinning up a Qt
// model + network stack.
//
// Sanitization is the *intersection* of what's legal on Windows and POSIX:
// Windows is the stricter of the two (rejects < > : " / \ | ? * + control
// chars + reserved device names like CON, PRN, AUX), so anything that
// passes will land safely on either filesystem.
namespace plazma::download_paths {

// Root folder for video downloads. Resolves to ~/Videos/Plazma on Linux
// (locale-equivalent via xdg-user-dirs) and %USERPROFILE%\Videos\Plazma on
// Windows. Falls back to the system Downloads folder, then the home
// directory, if MoviesLocation is unavailable.
[[nodiscard]] QString defaultRoot();

// Strip / replace illegal characters, collapse whitespace runs, neutralize
// reserved Windows device names, and clamp to a length that leaves headroom
// for collision suffixes ("(1)", "(2)", …) and UTF-8 multibyte characters.
[[nodiscard]] QString sanitizeFilename(const QString& title);

// Pick the file extension. Preference order:
//   1. URL path suffix if it looks like a known video container.
//   2. Caller-supplied MIME, mapped through QMimeDatabase.
//   3. Hard fallback to "mp4".
[[nodiscard]] QString extensionFor(const QString& sourceUrl, const QString& mime);

// Resolve a final, non-colliding destination path for `title` inside `root`.
// If a file (or its `.part` sibling) already exists at the natural name,
// appends " (1)", " (2)", … up to a sane cap before giving up.
[[nodiscard]] QString computeDestPath(
    const QString& root,
    const QString& title,
    const QString& sourceUrl,
    const QString& mime
);

// Re-derive a fresh destination path from a stored entry whose extension
// changed mid-flight (e.g., a Content-Type header arrived after we already
// computed a guess from the URL). The previous path is consulted only for
// its parent folder; the filename is recomputed end-to-end so the "(1)"
// collision logic still applies if a sibling appeared in the meantime.
[[nodiscard]] QString rederivePath(
    const QString& previousDestPath,
    const QString& title,
    const QString& sourceUrl,
    const QString& mime
);

}  // namespace plazma::download_paths
