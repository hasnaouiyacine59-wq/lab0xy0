#!/usr/bin/env bash
#
# fetch-kernel.sh — fetch the pinned Linux source tree, reproducibly.
#
# Reads kernel/sources/kernel.pin and downloads exactly one tarball, verifies
# its SHA-256, and extracts it to kernel/sources/linux/<version>/.
#
# Guarantees:
#   - pinned version only; no floating "latest"
#   - checksum from the pin file; mismatch is fatal (no blind retry)
#   - repository-relative source location
#   - refuses to run if the pin is unset or the checksum is absent
#
# Idempotent: if the extracted tree already exists and the tarball verifies, it
# is a no-op. Exit 0 on success, non-zero on any failure.
#
# Run on the BUILD host. See ../BUILD-HOST.md.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PIN_FILE="$REPO_ROOT/kernel/sources/kernel.pin"
SRC_ROOT="$REPO_ROOT/kernel/sources"
CACHE="$SRC_ROOT/cache"

die()  { printf '\nerror: %s\n' "$*" >&2; exit 1; }

# --- load the pin ---------------------------------------------------------
[ -f "$PIN_FILE" ] || die "pin file not found: $PIN_FILE"

pin_get() { grep -E "^$1=" "$PIN_FILE" | grep -v '^#' | head -1 | cut -d= -f2- ; }
pin_count() { grep -E "^$1=" "$PIN_FILE" | grep -vc '^#' || true; }

VERSION="$(pin_get version)"
URL="$(pin_get url)"
SHA256="$(pin_get sha256)"

for k in version url sha256; do
    n=$(pin_count "$k")
    [ "$n" -le 1 ] || die "kernel.pin has $n active '$k=' lines — expected exactly one."
done

printf '==============================================================\n'
printf ' fetch-kernel.sh — pinned fetch\n'
printf '==============================================================\n'
printf 'pin file : %s\n' "$PIN_FILE"
printf 'version  : %s\n' "${VERSION:-<UNSET>}"
printf 'url      : %s\n' "${URL:-<UNSET>}"
printf 'sha256   : %s\n' "${SHA256:-<UNSET>}"
printf '\n'

# --- validate the pin before touching the network ------------------------
case "$VERSION" in
    ""|UNSET) die "kernel.pin has no version. Choose a latest suitable stable/LTS
       release per Arm guidance, fill in kernel/sources/kernel.pin, then re-run." ;;
esac
[ -n "$URL" ]   || die "kernel.pin has no url for $VERSION."
[ -n "$SHA256" ] || die "kernel.pin has no sha256 for $VERSION. A checksum is mandatory."
[[ "$SHA256" =~ ^[0-9a-fA-F]{64}$ ]] || die "sha256 in kernel.pin is not a 64-hex value."

TARBALL="$CACHE/$(basename "$URL")"
DEST="$SRC_ROOT/linux/$VERSION"

# --- already present? ----------------------------------------------------
if [ -d "$DEST" ] && [ -f "$TARBALL" ] && \
   printf '%s  %s\n' "$SHA256" "$TARBALL" | sha256sum -c - >/dev/null 2>&1; then
    printf 'already present and verified: %s\n' "$DEST"
    printf 'Nothing to do.\n'
    exit 0
fi

mkdir -p "$CACHE" "$SRC_ROOT/linux"

# --- download ------------------------------------------------------------
# If a tarball exists but does NOT match the pin, that is a hard error, not a
# silent overwrite: it means either corruption or a changed pin.
if [ -f "$TARBALL" ]; then
    if printf '%s  %s\n' "$SHA256" "$TARBALL" | sha256sum -c - >/dev/null 2>&1; then
        printf 'cached tarball already matches pin; skipping download.\n'
    else
        die "cached tarball $(basename "$TARBALL") does NOT match the pinned
       checksum. Refusing to overwrite automatically. Remove it by hand after
       confirming the pin in kernel/sources/kernel.pin is correct:
         rm -f '$TARBALL'"
    fi
else
    printf 'downloading %s\n' "$URL"
    command -v curl >/dev/null || die "curl not found."
    curl -fL --retry 3 --retry-delay 2 -o "$TARBALL.part" "$URL" \
        || die "download failed: $URL"
    mv "$TARBALL.part" "$TARBALL"
fi

# --- verify (fatal on mismatch) -----------------------------------------
printf 'verifying sha256 ...\n'
printf '%s  %s\n' "$SHA256" "$TARBALL" | sha256sum -c - \
    || die "CHECKSUM MISMATCH for $TARBALL. Expected $SHA256.
       The download is corrupt or the pin is wrong. NOT auto-retried."
printf 'checksum OK\n\n'

# --- extract -------------------------------------------------------------
printf 'extracting to %s ...\n' "$DEST"
if [ -d "$DEST" ]; then
    die "destination already exists: $DEST (remove it if you want a clean extract)"
fi
mkdir -p "$DEST"
tar -xf "$TARBALL" -C "$DEST" --strip-components=1 \
    || die "extraction failed."

[ -f "$DEST/Makefile" ] || die "extracted tree looks wrong (no Makefile at $DEST)."

printf '\nextracted OK: %s\n' "$DEST"
printf 'Next: kernel/scripts/preflight.sh, then apply-patches.sh, then build.sh.\n'
exit 0