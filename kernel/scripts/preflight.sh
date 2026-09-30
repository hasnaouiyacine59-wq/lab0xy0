#!/usr/bin/env bash
#
# preflight.sh — verify this machine can build the lab, before any large work.
#
# Read-only: it inspects the host and reports; it downloads and builds nothing.
# Safe to run anywhere. Run this FIRST on a candidate build host.
#
# Exit codes:
#   0  all required checks passed
#   1  one or more required checks FAILED (do not start a build)
#   2  usage error

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAIL=0
WARN=0

ok()   { printf '  [ OK   ] %s\n' "$*"; }
fail() { printf '  [ FAIL ] %s\n' "$*"; FAIL=1; }
warn() { printf '  [ WARN ] %s\n' "$*"; WARN=1; }

echo "=============================================================="
echo " lab0xy0 preflight — build host check"
echo "=============================================================="

# --- 1. host shape -------------------------------------------------------
echo
echo "-- host --"
echo "  uname      : $(uname -srm)"
echo "  nproc      : $(nproc)"
free_h=$(free -h | awk '/^Mem:/ {print $7}')
total_h=$(free -h | awk '/^Mem:/ {print $2}')
echo "  memory     : ${total_h} total, ${free_h} available"

if [ "$(uname -m)" != "x86_64" ]; then
    fail "architecture is $(uname -m); the lab targets an x86_64 guest/kernel."
else
    ok "architecture x86_64"
fi

# --- 2. disk (the binding constraint) ------------------------------------
echo
echo "-- disk --"
avail_kb=$(df -Pk "$REPO_ROOT" | awk 'NR==2 {print $4}')
avail_gb=$((avail_kb / 1024 / 1024))
echo "  free on repo filesystem: ${avail_gb} GB"
if   [ "$avail_gb" -ge 40 ]; then ok    "disk ${avail_gb} GB — comfortable for multiple profiles"
elif [ "$avail_gb" -ge 25 ]; then ok    "disk ${avail_gb} GB — enough for baseline + one profile"
elif [ "$avail_gb" -ge 12 ]; then warn  "disk ${avail_gb} GB — tight; build one profile at a time and prune"
else fail "disk ${avail_gb} GB — insufficient; free space before building (see kernel/BUILD-HOST.md)"; fi

# --- 3. required tools ---------------------------------------------------
echo
echo "-- required tools --"
for t in gcc make ld as flex bison bc cpio tar xz curl sha256sum; do
    if command -v "$t" >/dev/null 2>&1; then ok "$t ($(${t} --version 2>/dev/null | head -1))"
    else fail "$t MISSING (Debian/Ubuntu: build-essential flex bison bc cpio xz-utils)"; fi
done

# --- 4. required headers/libraries ---------------------------------------
echo
echo "-- required headers --"
for h in /usr/include/openssl/opensslv.h /usr/include/zlib.h; do
    [ -f "$h" ] && ok "$h" || fail "$h MISSING (libssl-dev / zlib1g-dev)"
done
if [ -f /usr/include/libelf.h ] || [ -f /usr/include/gelf.h ]; then
    ok "libelf headers present"
else
    warn "libelf headers missing (libelf-dev) — needed unless ORC/BTF is disabled"
fi

# --- 5. qemu / kvm (for later boot validation) ---------------------------
echo
echo "-- qemu / kvm (boot validation, not needed to compile) --"
if command -v qemu-system-x86_64 >/dev/null 2>&1; then
    ok "qemu-system-x86_64 present"
else
    warn "qemu-system-x86_64 missing (qemu-system-x86) — required to BOOT and validate"
fi
if [ -e /dev/kvm ]; then ok "/dev/kvm present (KVM acceleration available)"
else warn "/dev/kvm absent — QEMU will fall back to slow TCG"; fi

# --- 6. repository state -------------------------------------------------
echo
echo "-- repository state --"
if [ -f "$REPO_ROOT/vendor/arm/AX504X08X-SW-99002-r54p0-01eac0.tar.gz" ]; then
    ok "primary Kbase archive present"
    ( cd "$REPO_ROOT/vendor/arm" && sha256sum -c SHA256SUMS >/dev/null 2>&1 ) \
        && ok "vendor archive checksum verifies" \
        || fail "vendor archive checksum MISMATCH"
else
    fail "primary Kbase archive missing under vendor/arm/"
fi
if [ -f "$REPO_ROOT/patches/virtual-device/SHA256SUMS" ]; then
    ( cd "$REPO_ROOT/patches/virtual-device" && sha256sum -c SHA256SUMS >/dev/null 2>&1 ) \
        && ok "six virtual-device patch checksums verify" \
        || fail "patch checksum mismatch"
else
    fail "patches/virtual-device/SHA256SUMS missing"
fi

# --- 7. kernel pin -------------------------------------------------------
echo
echo "-- kernel pin --"
PIN="$REPO_ROOT/kernel/sources/kernel.pin"
# Read ONLY uncommented, non-empty pin lines; ignore any commented examples.
pin_field() { grep -E "^$1=" "$PIN" 2>/dev/null | grep -v '^#' | head -1 | cut -d= -f2-; }
ver="$(pin_field version)"
url="$(pin_field url)"
sha="$(pin_field sha256)"
# Guard against an ambiguous pin file (more than one active version= line).
nver=$(grep -E '^version=' "$PIN" 2>/dev/null | grep -vc '^#' || true)
echo "  pinned version: ${ver:-<UNSET>}"
if [ "${nver:-0}" -gt 1 ]; then
    fail "kernel.pin has $nver active 'version=' lines — it must have exactly one"
fi
if [ -z "$ver" ] || [ "$ver" = "UNSET" ]; then
    warn "kernel.pin version is UNSET — pin a latest suitable stable/LTS release before fetching"
elif [ -z "$url" ]; then
    fail "kernel.pin has a version but no url — an exact (non-floating) url is required"
elif [ -z "$sha" ]; then
    fail "kernel.pin has a version but NO sha256 — a checksum is mandatory"
else
    ok "kernel pinned: $ver (url + checksum present)"
fi

# --- verdict -------------------------------------------------------------
echo
echo "=============================================================="
if [ "$FAIL" -ne 0 ]; then
    echo " RESULT: NOT READY — fix the [FAIL] items above before building."
    echo "=============================================================="
    exit 1
fi
echo " RESULT: READY to proceed (warnings are advisory)."
echo " Order: fetch-kernel.sh -> apply-patches.sh -> build.sh --profile <p>"
echo "=============================================================="
exit 0