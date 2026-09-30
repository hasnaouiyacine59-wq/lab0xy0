#!/usr/bin/env bash
#
# bootstrap.sh [--check] [--yes]
#
# Install everything this lab needs to build a kernel, and then prove it by
# running preflight.sh. Idempotent: re-running is cheap and safe.
#
#   --check   report what is missing, install nothing (exit 1 if anything is)
#   --yes     do not prompt before installing (for non-interactive use, e.g. a
#             devcontainer onCreateCommand)
#
# The package list is the one in ../BUILD-HOST.md; keeping it here as well means
# the docs and the machine cannot drift apart, because preflight.sh checks the
# same tools afterwards.
#
# Run on the BUILD host. See ../BUILD-HOST.md.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CHECK=0; ASSUME_YES=0
usage() {
    cat <<'EOF'
Usage: bootstrap.sh [--check] [--yes]

  --check   report missing requirements only; install nothing
  --yes     install without prompting
EOF
}
while [ $# -gt 0 ]; do
    case "$1" in
        --check) CHECK=1; shift ;;
        --yes|-y) ASSUME_YES=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "error: unknown argument: $1" >&2; usage; exit 2 ;;
    esac
done

# Keep this list identical to ../BUILD-HOST.md and to preflight.sh's checks.
PKGS_REQUIRED="build-essential gcc make flex bison bc libelf-dev libssl-dev \
libncurses-dev xz-utils cpio kmod rsync zstd git curl ca-certificates python3"
PKGS_OPTIONAL="qemu-system-x86 qemu-utils dwarves busybox-static libguestfs-tools"

echo "=============================================================="
echo " bootstrap.sh — build host dependencies"
echo "=============================================================="

# --- distro guard ---------------------------------------------------------
if [ ! -r /etc/os-release ]; then
    echo "error: cannot identify the distribution (no /etc/os-release)." >&2
    exit 1
fi
# shellcheck disable=SC1091
. /etc/os-release
echo "distro        : ${PRETTY_NAME:-$ID $VERSION_ID}"
# Accept any Debian derivative (ubuntu, kali, devuan, raspbian, ...) via ID_LIKE,
# not just the two IDs named literally.
case " ${ID:-} ${ID_LIKE:-} " in
    *debian*|*ubuntu*) ;;
    *) echo "error: this script installs Debian/Ubuntu packages; '$ID' (ID_LIKE='${ID_LIKE:-}') is not a Debian derivative." >&2
       echo "       Install the equivalent packages by hand — see ../BUILD-HOST.md." >&2
       exit 1 ;;
esac

APT=apt-get
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null; then SUDO=sudo; else
        echo "error: not root and sudo is unavailable; run as root or install packages manually." >&2
        exit 1
    fi
fi

# --- check mode -----------------------------------------------------------
missing_pkg() {
    local p="$1"
    # dpkg-query avoids depending on `command -v` for packages that install files.
    dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q 'ok installed'
}
# Sets MISSING to the list of absent packages from its arguments. Note the
# shift/"$*": an unquoted variable expands to many words, so "$2" alone would
# only ever see the first package.
report() { # $1 = label, rest = package names
    local label="$1"; shift
    MISSING=""
    local p
    for p in "$@"; do
        missing_pkg "$p" || MISSING="$MISSING $p"
    done
    if [ -n "$MISSING" ]; then
        echo "$label missing:$MISSING"
    else
        echo "$label: all present"
    fi
}

echo
report required $PKGS_REQUIRED
MISSING_REQUIRED="$MISSING"
report optional $PKGS_OPTIONAL
MISSING_OPTIONAL="$MISSING"

if [ "$CHECK" -eq 1 ]; then
    echo
    if [ -z "$MISSING_REQUIRED" ]; then
        echo "check: all REQUIRED packages present."
        exit 0
    fi
    echo "check: required packages are missing. Run: bootstrap.sh --yes"
    exit 1
fi

# --- install --------------------------------------------------------------
if [ -z "$MISSING_REQUIRED" ] && [ -z "$MISSING_OPTIONAL" ]; then
    echo
    echo "all packages already present; nothing to install."
else
    echo
    if [ "$ASSUME_YES" -eq 0 ]; then
        printf 'Install the missing packages now? [y/N] '
        read -r ans
        case "$ans" in y|Y|yes|YES) ;; *) echo "aborted; nothing installed."; exit 1 ;; esac
    fi
    echo
    echo "running: apt-get update"
    $SUDO $APT update -qq || { echo "error: apt-get update failed" >&2; exit 1; }
    echo "running: apt-get install (required + optional)"
    $SUDO $APT install -y --no-install-recommends $PKGS_REQUIRED $PKGS_OPTIONAL \
        || { echo "error: apt-get install failed" >&2; exit 1; }
fi

# --- KVM is optional; never fail on it -----------------------------------
if [ -e /dev/kvm ]; then
    echo "/dev/kvm present — QEMU can use hardware acceleration."
else
    echo "/dev/kvm ABSENT — QEMU will fall back to TCG (slow)."
    echo "  Building is unaffected. Fuzzing throughput will be poor, which is"
    echo "  expected on most managed/CI hosts. See ../BUILD-HOST.md."
fi

# --- prove it -------------------------------------------------------------
echo
echo "=============================================================="
echo " running preflight.sh"
echo "=============================================================="
"$REPO_ROOT/kernel/scripts/preflight.sh"
rc=$?
echo
if [ "$rc" -eq 0 ]; then
    echo "bootstrap complete: this host can build the lab."
else
    echo "bootstrap finished, but preflight still reports NOT READY."
    echo "Fix the [FAIL] items above. The most common remaining blocker is an"
    echo "unset kernel pin:  kernel/scripts/resolve-kernel-pin.sh"
fi
exit "$rc"