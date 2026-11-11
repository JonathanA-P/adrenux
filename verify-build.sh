#!/usr/bin/env bash
# ==============================================================================
# verify-build.sh
# Verifies compiled Mesa Turnip and Zink libraries (AArch64 ELF & dependencies)
# ==============================================================================
set -euo pipefail

TURNIP_LIB="${1:-/opt/mesa-kgsl/lib/libvulkan_freedreno.so}"
ZINK_LIB="${2:-/opt/mesa-zink/lib/dri/zink_dri.so}"

echo "======================================================="
echo "   Mesa Turnip & Zink Build Verification (ARM64)       "
echo "======================================================="

# 1. Turnip Vulkan Driver Check
echo -e "\n[1/2] Checking Turnip Vulkan Driver: $TURNIP_LIB"
if [ ! -s "$TURNIP_LIB" ]; then
  echo "[-] ERROR: Turnip Vulkan library not found at $TURNIP_LIB"
else
  if readelf -h "$TURNIP_LIB" 2>/dev/null | grep -q 'Machine:.*AArch64'; then
    echo "[+] Turnip ELF header: Valid AArch64 binary"
  else
    echo "[-] WARNING: Binary is not valid AArch64"
  fi

  MISSING_DEPS=$(ldd "$TURNIP_LIB" 2>/dev/null | grep 'not found' || true)
  if [ -n "$MISSING_DEPS" ]; then
    echo "[-] WARNING: Missing dynamic dependencies in Turnip:"
    echo "$MISSING_DEPS"
  else
    echo "[+] Turnip dynamic dependencies: All resolved"
  fi
fi

# 2. Zink DRI Driver Check
echo -e "\n[2/2] Checking Zink OpenGL Driver: $ZINK_LIB"
if [ ! -s "$ZINK_LIB" ]; then
  echo "[-] ERROR: Zink DRI library not found at $ZINK_LIB"
else
  if readelf -h "$ZINK_LIB" 2>/dev/null | grep -q 'Machine:.*AArch64'; then
    echo "[+] Zink ELF header: Valid AArch64 binary"
  else
    echo "[-] WARNING: Binary is not valid AArch64"
  fi

  MISSING_DEPS=$(ldd "$ZINK_LIB" 2>/dev/null | grep 'not found' || true)
  if [ -n "$MISSING_DEPS" ]; then
    echo "[-] WARNING: Missing dynamic dependencies in Zink:"
    echo "$MISSING_DEPS"
  else
    echo "[+] Zink dynamic dependencies: All resolved"
  fi
fi

echo -e "\n======================================================="
echo " Build Verification Finished"
echo "======================================================="
