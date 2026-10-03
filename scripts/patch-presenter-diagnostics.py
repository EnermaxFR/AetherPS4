#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: patch-presenter-diagnostics.py <AetherPS4 engine root>")

p = Path(sys.argv[1]) / "src/video_core/renderer_vulkan/vk_presenter.cpp"
s = p.read_text()

# Keep this patch deliberately diagnostic-only: it must not change Vulkan synchronization.
# We want the next on-device run to tell us whether iOS stalls before acquire, during acquire,
# during queue submission, or during swapchain presentation.
acquire = """    if (!swapchain.AcquireNextImage()) {
"""
acquire_repl = """    if (trace) {
        LOG_INFO(Render_Vulkan,
                 "MAXPS4_FRAME_DIAG id={} stage=acquire_begin frame={} swapchainFrameIndex={} imageCount={}",
                 trace_id, frame ? int(frame->id) : -1, swapchain.GetFrameIndex(),
                 swapchain.GetImageCount());
    }
    if (!swapchain.AcquireNextImage()) {
"""
if "MAXPS4_FRAME_DIAG id={} stage=acquire_begin" not in s:
    if acquire not in s:
        raise SystemExit("AcquireNextImage anchor changed; refusing unsafe patch")
    s = s.replace(acquire, acquire_repl, 1)

present = """        const bool presented = swapchain.Present();
"""
present_repl = """        if (trace) {
            LOG_INFO(Render_Vulkan, "MAXPS4_FRAME_DIAG id={} stage=present_begin", trace_id);
        }
        const bool presented = swapchain.Present();
        if (trace) {
            LOG_INFO(Render_Vulkan, "MAXPS4_FRAME_DIAG id={} stage=present_end ok={}", trace_id,
                     presented);
        }
"""
if "MAXPS4_FRAME_DIAG id={} stage=present_begin" not in s:
    if present not in s:
        raise SystemExit("swapchain.Present anchor changed; refusing unsafe patch")
    s = s.replace(present, present_repl, 1)

p.write_text(s)
print(f"patched {p}")
