#!/bin/sh
# Runs one of the CI runner scripts the way the app would (plain sh; as root
# for the Linux ones, as a normal user for the macOS ones) and checks it
# without registering a runner anywhere:
#   1. with url and token empty it installs, and the runner binary runs;
#   2. running it again works too;
#   3. a url without a token is refused;
#   4. GitHub/GitLab reject a made-up token, the script fails, and nothing
#      is left registered.
# github-runner has to refuse Alpine instead: GitHub's runner needs glibc.
# POSIX sh on purpose — the Alpine image has no bash.
set -u
name="$1"
dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$dir/scripts/$name/script.noshell"
[ -f "$script" ] || { echo "no such script: $name"; exit 1; }

sudo=""
case "$name" in
    *-macos)
        # Keeps the runner out of the real ~/actions-runner / ~/gitlab-runner.
        RUNNER_DIR="${RUNNER_DIR:-$(mktemp -d)}"
        export RUNNER_DIR
        ;;
    *) [ "$(id -u)" -eq 0 ] || sudo=sudo ;;
esac

case "$name" in
    github-runner)
        bogus_url=https://github.com/bostrot/wsl-scripts
        installed() { $sudo runuser -u github-runner -- /opt/actions-runner/bin/Runner.Listener --version; }
        registered() { $sudo test -f /opt/actions-runner/.runner; }
        ;;
    github-runner-macos)
        bogus_url=https://github.com/bostrot/wsl-scripts
        installed() { "$RUNNER_DIR/bin/Runner.Listener" --version; }
        registered() { test -f "$RUNNER_DIR/.runner"; }
        ;;
    gitlab-runner)
        bogus_url=https://gitlab.com
        installed() { /usr/local/bin/gitlab-runner --version | sed -n 's/^Version: *//p'; }
        registered() { $sudo grep -q '^\[\[runners\]\]' /etc/gitlab-runner/config.toml 2>/dev/null; }
        ;;
    gitlab-runner-macos)
        bogus_url=https://gitlab.com
        installed() { "$RUNNER_DIR/gitlab-runner" --version | sed -n 's/^Version: *//p'; }
        registered() { grep -q '^\[\[runners\]\]' "$RUNNER_DIR/config.toml" 2>/dev/null; }
        ;;
    *) echo "$name is not a runner script"; exit 1 ;;
esac

out=$(mktemp)
run() { $sudo env RUNNER_URL= RUNNER_TOKEN= "$@" sh "$script" >"$out" 2>&1; }
fail() { tail -30 "$out"; echo "FAIL: $*"; exit 1; }

if [ "$name" = github-runner ] && [ -f /etc/alpine-release ]; then
    run && fail "should refuse Alpine"
    grep -q "does not run on Alpine" "$out" || fail "no Alpine explanation"
    echo "== $name refuses Alpine, as it should"
    exit 0
fi

echo "== $name: install without a token"
run || fail "install exited non-zero"
grep -q "not registered yet" "$out" || fail "did not say it is unregistered"
version=$(installed 2>/dev/null)
[ -n "$version" ] || fail "the installed runner does not run"
echo "runner $version runs"

echo "== $name: run again"
run || fail "second run exited non-zero"
[ "$(installed 2>/dev/null)" = "$version" ] || fail "second run broke the install"

echo "== $name: url without a token"
run RUNNER_URL="$bogus_url" && fail "accepted a url without a token"
grep -q "Fill in both" "$out" || fail "no explanation for the missing token"

echo "== $name: made-up token"
run RUNNER_URL="$bogus_url" RUNNER_TOKEN=glrt-wslm-ci-not-a-real-token && fail "accepted a made-up token"
grep -q "failed" "$out" || fail "no explanation for the rejected token"
registered && fail "something got registered"

echo "== $name works"
