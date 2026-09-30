#!/usr/bin/env bash
#
# codespace-setup.sh [--check] [--yes] [--https]
#
# One-time setup for a fresh GitHub Codespace (or any fresh clone of this repo on
# a Debian/Ubuntu host). It prepares the things that are NOT apt packages and that
# otherwise fail at a confusing moment:
#
#   1. machine spec vs preflight thresholds   -> fail EARLY, not after a build
#   2. build toolchain                        -> delegated to bootstrap.sh
#   3. git identity                           -> needed to commit the kernel pin
#   4. GitHub access                          -> the remote is SSH; a fresh
#                                               codespace has no key
#   5. gh CLI                                 -> optional, for pushing the pin
#   6. preflight.sh                           -> the single authoritative verdict
#
# It does NOT fetch a kernel, build anything, or change the pin. Those are separate
# deliberate steps (see ../BUILD-HOST.md).
#
#   --check   report only; change nothing and install nothing
#   --yes     non-interactive (for CI or a scripted setup)
#   --https   switch the origin remote to HTTPS instead of relying on SSH
#
# Exit codes:  0 ready   1 something is still wrong   2 usage error

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREFLIGHT="$REPO_ROOT/kernel/scripts/preflight.sh"
BOOTSTRAP="$REPO_ROOT/kernel/scripts/bootstrap.sh"

CHECK=0; ASSUME_YES=0; USE_HTTPS=0
usage() {
    cat <<'EOF'
Usage: codespace-setup.sh [--check] [--yes] [--https]

  --check   report only; install and change nothing
  --yes     non-interactive
  --https   prefer the HTTPS remote over SSH
EOF
}
while [ $# -gt 0 ]; do
    case "$1" in
        --check)  CHECK=1; shift ;;
        --yes|-y) ASSUME_YES=1; shift ;;
        --https)  USE_HTTPS=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "error: unknown argument: $1" >&2; usage; exit 2 ;;
    esac
done

PROBLEMS=0
say()  { printf '%s\n' "$*"; }
hdr()  { printf '\n--- %s ---\n' "$*"; }
ok()   { printf '  [ ok      ] %s\n' "$*"; }
warn() { printf '  [ warn    ] %s\n' "$*"; }
bad()  { printf '  [ problem ] %s\n' "$*"; PROBLEMS=$((PROBLEMS+1)); }
act()  { printf '  [ action  ] %s\n' "$*"; }

cd "$REPO_ROOT" || { say "error: repo root not found: $REPO_ROOT" >&2; exit 1; }

say "=============================================================="
say " codespace-setup.sh — GitHub Codespaces / fresh clone setup"
say "=============================================================="
if [ "${CODESPACES:-}" = "true" ]; then
    say "environment : GitHub Codespaces (CODESPACES=true)"
    say "repository  : ${CODESPACE_REPO_FOLDER:-unknown}"
else
    say "environment : plain host (not a Codespace)"
fi

# --- 1. machine spec ------------------------------------------------------
hdr "machine spec"
avail_kb=$(df -Pk "$REPO_ROOT" | awk 'NR==2 {print $4}')
avail_gb=$((avail_kb / 1024 / 1024))
mem_gb=$(awk '/^MemTotal:/ {printf "%d", $2/1024/1024}' /proc/meminfo)
mem_avail_gb=$(awk '/^MemAvailable:/ {printf "%d", $2/1024/1024}' /proc/meminfo)
cpus=$(nproc)
say "  cpus        : $cpus"
say "  memory      : ${mem_gb} GB total, ${mem_avail_gb} GB available"
say "  free disk   : ${avail_gb} GB on the repo filesystem"

# Thresholds match ../BUILD-HOST.md (8 GB minimum, 16 GB preferred; >=25 GB disk,
# 40 GB preferred). Do not invent different numbers here.
if [ "$cpus" -lt 4 ]; then
    bad "only $cpus CPUs — pick a 4-core codespace machine before building"
else ok "$cpus CPUs"; fi
if [ "$mem_gb" -lt 8 ]; then
    bad "only ${mem_gb} GB RAM — BUILD-HOST.md requires 8 GB minimum, 16 GB preferred"
elif [ "$mem_gb" -lt 16 ]; then
    warn "${mem_gb} GB RAM — meets the 8 GB minimum but 16 GB is preferred; use -j cautiously"
else ok "${mem_gb} GB RAM"; fi
if [ "$avail_gb" -lt 25 ]; then
    bad "${avail_gb} GB free disk — need >=25 GB (40 preferred). Pick the 64 GB machine."
    act "free space, or choose a larger machine, BEFORE starting a build"
else
    if [ "$avail_gb" -lt 40 ]; then
        warn "${avail_gb} GB free — enough for baseline + one profile; prune between builds"
    else ok "${avail_gb} GB free disk"; fi
fi

if [ ! -e /dev/kvm ]; then
    warn "/dev/kvm absent — QEMU will fall back to TCG (slow). Expected on Codespaces."
    say "             Compilation is unaffected; fuzzing throughput will be poor."
fi

if [ "$CHECK" -eq 1 ]; then
    hdr "check mode"
    say "No changes were made. Re-run without --check to set the host up."
    [ "$PROBLEMS" -eq 0 ] && exit 0 || exit 1
fi

# --- 2. toolchain ---------------------------------------------------------
hdr "build toolchain"
if bash "$BOOTSTRAP" --check >/dev/null 2>&1; then
    ok "all required build packages already installed"
else
    say "  installing via bootstrap.sh (see kernel/BUILD-HOST.md) ..."
    if bash "$BOOTSTRAP" --yes; then
        ok "bootstrap.sh finished"
    else
        warn "bootstrap.sh reported a problem — see its output above"
        bad "build dependencies may be incomplete"
    fi
fi

# --- 3. git identity ------------------------------------------------------
hdr "git identity"
if git config --get user.email >/dev/null 2>&1 && git config --get user.name >/dev/null 2>&1; then
    ok "identity set: $(git config --get user.name) <$(git config --get user.email)>"
else
    HANDLE=$(git remote get-url origin 2>/dev/null \
             | sed -n 's#.*github\.com[:/]\([^/]*\)/.*#\1#p' | head -1)
    [ -n "$HANDLE" ] || HANDLE=$(id -un)
    if [ "$ASSUME_YES" -eq 1 ]; then
        # Repo-local, so it cannot leak into unrelated repos on a shared host.
        git config user.name "$HANDLE"
        git config user.email "${HANDLE}@users.noreply.github.com"
        act "set repo-local identity from the GitHub handle"
        say "             user.name  = $HANDLE"
        say "             user.email = ${HANDLE}@users.noreply.github.com"
        say "             Change it if you want a different author identity:"
        say "               git config user.email 'you@example.com'"
    else
        say "  No git identity configured. Enter one (or press Enter to accept defaults):"
        read -r -p "  name  [$HANDLE]: " G_NAME || G_NAME=""
        read -r -p "  email [${HANDLE}@users.noreply.github.com]: " G_EMAIL || G_EMAIL=""
        [ -n "$G_NAME" ]  || G_NAME="$HANDLE"
        [ -n "$G_EMAIL" ] || G_EMAIL="${HANDLE}@users.noreply.github.com"
        git config user.name "$G_NAME"
        git config user.email "$G_EMAIL"
        act "identity set: $G_NAME <$G_EMAIL>"
    fi
    say "  (needed to commit the kernel pin)"
fi

# Docker/container ownership mismatch makes git refuse the working tree.
if git status >/dev/null 2>&1; then
    ok "git can read the working tree"
else
    act "adding this checkout to safe.directory (container uid mismatch)"
    git config --global --add safe.directory "$REPO_ROOT" 2>/dev/null \
        || git config --global --add safe.directory '*' 2>/dev/null || true
    git status >/dev/null 2>&1 && ok "working tree readable" \
        || bad "git still cannot read the working tree"
fi

# --- 4. GitHub access -----------------------------------------------------
hdr "github access"
REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
say "  origin = ${REMOTE:-<none>}"

if [ "$USE_HTTPS" -eq 1 ] && [ -n "$REMOTE" ]; then
    HTTPS_REMOTE=$(printf '%s' "$REMOTE" | sed 's#^git@github.com:#https://github.com/#')
    act "switching origin to HTTPS: $HTTPS_REMOTE"
    git remote set-url origin "$HTTPS_REMOTE"
    REMOTE="$HTTPS_REMOTE"
fi

case "$REMOTE" in
    git@github.com:*|ssh://*github.com*)
        mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
        KEY="$HOME/.ssh/id_ed25519"
        if [ -f "$KEY" ]; then
            ok "SSH key exists: $KEY"
        else
            act "generating an SSH key (Codespaces-specific key, no passphrase)"
            ssh-keygen -t ed25519 -N "" -C "codespace-$(hostname)" -f "$KEY" >/dev/null 2>&1 \
                || warn "ssh-keygen failed — try the HTTPS remote instead (--https)"
        fi
        if [ -f "$KEY" ]; then
            # Idempotent Host entry.
            if ! grep -q '^Host github.com$' "$HOME/.ssh/config" 2>/dev/null; then
                {
                    printf 'Host github.com\n'
                    printf '    HostName github.com\n'
                    printf '    User git\n'
                    printf '    IdentityFile %s\n' "$KEY"
                    printf '    IdentitiesOnly yes\n'
                    printf '    AddKeysToAgent yes\n'
                } >> "$HOME/.ssh/config"
                chmod 600 "$HOME/.ssh/config"
                act "wrote $HOME/.ssh/config"
            fi
            say ""
            say "  ACTION REQUIRED — add this public key to GitHub once:"
            say "    https://github.com/settings/ssh/keys"
            say ""
            ssh-keygen -y -f "$KEY" 2>/dev/null | sed 's/^/    /'
            say ""
        fi
        if ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 \
             | grep -q 'successfully authenticated'; then
            ok "SSH authentication to github.com works"
        else
            warn "SSH to github.com is NOT working yet (expected until the key is added)."
            say "             Either add the key above, or re-run with --https."
        fi
        ;;
    https://github.com/*)
        if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
            ok "HTTPS remote with gh authenticated ($(gh api user -q .login 2>/dev/null))"
        elif [ -n "${GITHUB_TOKEN:-}" ]; then
            ok "HTTPS remote with GITHUB_TOKEN set"
        else
            warn "HTTPS remote, but no credentials visible."
            say "             Run: gh auth login      (or set GITHUB_TOKEN)"
        fi
        ;;
    *)
        bad "cannot determine the GitHub remote; check: git remote -v"
        ;;
esac

# --- 5. gh CLI (optional) -------------------------------------------------
hdr "gh cli (optional)"
if command -v gh >/dev/null 2>&1; then
    ok "gh present: $(gh --version 2>/dev/null | head -1)"
elif command -v apt-get >/dev/null 2>&1; then
    act "installing gh"
    if [ "$ASSUME_YES" -eq 1 ] || { printf '  install gh? [y/N] '; read -r a; case "$a" in y|Y|yes) ;; *) a=n ;; esac; }; then
        SUDO=""; [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null && SUDO=sudo
        $SUDO apt-get install -y --no-install-recommends gh >/dev/null 2>&1 \
            && ok "gh installed" \
            || warn "gh install failed; optional — skip it"
    else
        warn "skipped gh (optional)"
    fi
else
    warn "gh not available and no apt-get; optional, skip it"
fi

# --- 6. auto-stop advice --------------------------------------------------
if [ "${CODESPACES:-}" = "true" ]; then
    hdr "codespaces advice"
    warn "auto-stop will suspend this codespace during a long make -j and kill it"
    say "             Raise or disable the idle timeout before starting a build,"
    say "             or run under:  nohup ... > build/logs/nohup.log 2>&1 &"
fi

# --- 7. verdict -----------------------------------------------------------
hdr "verdict"
bash "$PREFLIGHT"
rc=$?

hdr "next steps"
if [ "$rc" -eq 0 ]; then
    ok "preflight READY — you can resolve the pin and fetch"
    cat <<'EOF'
  bash kernel/scripts/resolve-kernel-pin.sh --dry-run   # inspect the choice
  bash kernel/scripts/resolve-kernel-pin.sh
  git commit -am "pin kernel <version>" && git push     # keep the pin reproducible
  bash kernel/scripts/fetch-kernel.sh
  bash kernel/scripts/apply-patches.sh
  bash kernel/scripts/build.sh --profile baseline
EOF
else
    say "  preflight is NOT READY. Fix the [FAIL] items above, then re-run"
    say "  kernel/scripts/preflight.sh. Most likely: the kernel pin, or disk/RAM."
fi

exit "$rc"