#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-.}"
warn(){ printf '::warning::%s\n' "$*"; }
scan(){
  local label="$1" regex="$2" out count=0
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
    while IFS= read -r line; do
      printf '%s\n' "$line"
      (( ++count >= 200 )) && break
    done <<< "$out"
  fi
}

# This audit is intentionally diagnostic-only. Potential compatibility issues
# are reported as GitHub Actions warnings but never stop the iOS build. The
# compiler/linker remains the authority for actual build failures.
scan 'Shell/process execution found; verify every call is excluded/replaced on iOS' 'std::system\(|(^|[^A-Za-z_])system\(|popen\(|fork\(|exec(v|ve|vp|vpe|l|le|lp|lpe)?\('
scan 'Linux-only runtime API found; verify iOS guards' 'epoll_(create|create1|ctl|wait|pwait)|eventfd\(|timerfd_|signalfd\(|inotify_'
scan 'Dynamic loading found; verify iOS/static-link strategy' 'dlopen\(|dlsym\(|dlclose\('
scan 'Executable/JIT memory found; verify iOS JIT implementation/entitlements' 'MAP_JIT|PROT_EXEC|pthread_jit_write_protect_np|mprotect\('
scan 'Desktop-only frameworks/UI references found; verify they are not linked into iOS target' 'Qt[0-9]?::|X11|wayland|AppKit|NSApplication'
scan 'CMake runtime probes found; cross compilation must not try to execute target binaries' 'try_run\(|check_cxx_source_runs\(|check_c_source_runs\('
scan 'Host/Linux shared-library path found; verify it is unreachable for the iOS target' '(/usr/local/lib/.*\.so|/usr/lib/.*\.so|libuuid\.so)'

printf 'iOS compatibility audit completed (warnings are non-blocking).\n'
exit 0
