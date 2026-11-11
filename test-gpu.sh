#!/usr/bin/env bash
# ==============================================================================
# test-gpu.sh
# Diagnostic and verification suite for Turnip KGSL and Zink OpenGL
# ==============================================================================
set -u

DISPLAY_NUM="${DISPLAY:-:2}"
TURNIP_ICD="${TURNIP_ICD:-/opt/mesa-kgsl/share/vulkan/icd.d/turnip_icd.json}"
ZINK_LIB="${ZINK_LIB:-/opt/mesa-zink/lib}"

export DISPLAY="$DISPLAY_NUM"
export VK_ICD_FILENAMES="$TURNIP_ICD"
export LD_LIBRARY_PATH="$ZINK_LIB:${LD_LIBRARY_PATH:-}"
export LIBGL_DRIVERS_PATH="$ZINK_LIB/dri"
export MESA_LOADER_DRIVER_OVERRIDE=zink
export GALLIUM_DRIVER=zink
export GALLIUM_THREAD=0
export LIBGL_KOPPER_DRI2=1

echo "======================================================="
echo " Qualcomm Adreno GPU Hardware Acceleration Diagnostics "
echo "======================================================="

echo -e "\n[1/4] Checking Vulkan Physical Devices (Turnip)..."
if command -v vulkaninfo &>/dev/null; then
  vulkaninfo --summary 2>/dev/null | grep -E "(deviceName|driverName|apiVersion)" || vulkaninfo | grep -i "device name" || true
else
  echo "vulkaninfo not found, skipping."
fi

echo -e "\n[2/4] Testing Vulkan Rendering (vkcube 120 frames)..."
if command -v vkcube &>/dev/null; then
  timeout -k 2s 15s vkcube --c 120 --width 640 --height 480 2>&1 | grep -i "Selected GPU" || true
  echo "✓ vkcube executed."
else
  echo "vkcube not found, skipping."
fi

echo -e "\n[3/4] Checking OpenGL via Zink (glxinfo)..."
if command -v glxinfo &>/dev/null; then
  glxinfo -B | grep -E "(OpenGL vendor|OpenGL renderer|OpenGL version|Accelerated)" || true
else
  echo "glxinfo not found, skipping."
fi

echo -e "\n[4/4] Testing OpenGL Rendering (glxgears 5 seconds)..."
if command -v glxgears &>/dev/null; then
  timeout -k 2s 6s glxgears 2>&1 | head -n 5 || true
else
  echo "glxgears not found, skipping."
fi

echo -e "\n======================================================="
echo " Diagnostics Completed. "
echo "======================================================="
