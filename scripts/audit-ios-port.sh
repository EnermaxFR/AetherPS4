#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-.}"
FAIL=0
warn(){ printf '::warning::%s\n' "$*"; }
error(){ printf '::error::%s\n' "$*"; FAIL=1; }
scan(){
  local label="$1" regex="$2" out
  out=$(grep -RInE \
    --exclude-dir=.git \
    --exclude-dir=build \
    --exclude-dir=docs \
    --exclude-dir=tests \
    --exclude='*.md' \
    --exclude='*.min.js' \
    "$regex" "$ROOT" 2>/dev/null || true)
  if [[ -n "$out" ]]; then
    warn "$label"
    # Avoid `printf | head` under pipefail: head closes the pipe early and
    # printf receives SIGPIPE, which previously made the audit fail itself.
    while IFS= read -r line; do
      printf '%s\n' "$line"
      (( ++count >= 200 )) && break
    done <<< "$out"
  fi
}
count=0
# Static audit for APIs/dependencies that commonly break an iOS cross-build.
scan 'Shell/process execution found; verify every call is excluded/replaced on iOS' 'std::system\(|(^|[^A-Za-z_])system\(|popen\(|fork\(|exec(v|ve|vp|vpe|l|le|lp|lpe)?\('
count=0
scan 'Linux-only runtime API found; verify iOS guards' 'epoll_(create|create1|ctl|wait|pwait)|eventfd\(|timerfd_|signalfd\(|inotify_'
count=0
scan 'Dynamic loading found; verify iOS/static-link strategy' 'dlopen\(|dlsym\(|dlclose\('
count=0
scan 'Executable/JIT memory found; verify iOS JIT implementation/entitlements' 'MAP_JIT|PROT_EXEC|pthread_jit_write_protect_np|mprotect\('
count=0
scan 'Desktop-only frameworks/UI references found; verify they are not linked into iOS target' 'Qt[0-9]?::|X11|wayland|AppKit|NSApplication'
count=0
scan 'CMake runtime probes found; cross compilation must not try to execute target binaries' 'try_run\(|check_cxx_source_runs\(|check_c_source_runs\('
# Hard failures: obvious host/Linux library paths in build-relevant source/CMake.
if grep -RInE \
  --exclude-dir=.git --exclude-dir=build --exclude-dir=docs --exclude-dir=tests \
  --exclude='*.md' --exclude='*.min.js' \
  '(/usr/local/lib/.*\.so|/usr/lib/.*\.so|libuuid\.so)' "$ROOT" 2>/dev/null; then
  error 'Host/Linux .so path is reachable in build-relevant source/CMake; guard or remove it for iOS'
fi
exit "$FAIL"
