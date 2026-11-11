#!/usr/bin/env bash
# ==============================================================================
# start-desktop.sh
# Launch Hardware-Accelerated Desktop via Zink -> Turnip KGSL -> Adreno
# Run inside Debian chroot as normal user or root.
# ==============================================================================
set -euo pipefail

DISPLAY_NUM="${DISPLAY:-:2}"
DESKTOP="${1:-gnome}" # Options: gnome, xfce, custom

TURNIP_ICD="${TURNIP_ICD:-/opt/mesa-kgsl/share/vulkan/icd.d/turnip_icd.json}"
ZINK_LIB="${ZINK_LIB:-/opt/mesa-zink/lib}"

if [ ! -f "$TURNIP_ICD" ]; then
  echo "Error: Turnip Vulkan ICD not found at $TURNIP_ICD" >&2
  exit 1
fi

if [ ! -f "$ZINK_LIB/dri/zink_dri.so" ]; then
  echo "Error: Zink DRI driver not found at $ZINK_LIB/dri/zink_dri.so" >&2
  exit 1
fi

echo "=== Initializing Hardware Accelerated Desktop on $DISPLAY_NUM ==="
echo "Driver Pipeline: OpenGL (Zink) -> Vulkan (Turnip KGSL) -> Adreno GPU"

export DISPLAY="$DISPLAY_NUM"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true

# Vulkan Turnip ICD
export VK_ICD_FILENAMES="$TURNIP_ICD"

# OpenGL Zink Driver Override & Library Paths
export LD_LIBRARY_PATH="$ZINK_LIB:${LD_LIBRARY_PATH:-}"
export LIBGL_DRIVERS_PATH="$ZINK_LIB/dri"
export MESA_LOADER_DRIVER_OVERRIDE=zink
export GALLIUM_DRIVER=zink

# CRITICAL STABILITY TUNING:
# 1. GALLIUM_THREAD=0: Eliminates multithreaded queue race condition in
#    Turnip's tu_CmdPipelineBarrier2 when called by zink_resource_image_barrier.
# 2. LIBGL_KOPPER_DRI2=1: Ensures Kopper routes presentations reliably over DRI2/X11.
# 3. GSK_RENDERER=cairo: Prevents GTK4 NGL/Vulkan pipeline crashes on mobile drivers.
export GALLIUM_THREAD=0
export LIBGL_KOPPER_DRI2=1
export GSK_RENDERER=cairo
export GTK_A11Y=none
export NO_AT_BRIDGE=1

# Clean shader cache to prevent stale shader binary mismatch
export MESA_SHADER_CACHE_DIR=/tmp/.shader_cache
export MESA_SHADER_CACHE_MAX_SIZE=512M
mkdir -p "$MESA_SHADER_CACHE_DIR" 2>/dev/null || true

if [ "$DESKTOP" = "gnome" ]; then
  echo "Starting GNOME Shell 43 (X11)..."
  exec dbus-run-session -- gnome-shell --x11
elif [ "$DESKTOP" = "xfce" ]; then
  echo "Starting XFCE4 Desktop..."
  exec dbus-run-session -- startxfce4
else
  echo "Running custom command: $*"
  exec "$@"
fi
