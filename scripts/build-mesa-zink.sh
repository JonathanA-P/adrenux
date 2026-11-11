#!/usr/bin/env bash
# ==============================================================================
# build-mesa-zink.sh
# Build Mesa Zink OpenGL-over-Vulkan Driver with DRI/GLX support
# Run inside Debian arm64 chroot as root.
# ==============================================================================
set -euo pipefail

MESA_VERSION="${MESA_VERSION:-25.2.6}"
BUILD_ROOT="${BUILD_ROOT:-/opt/mesa-kgsl-build}"
INSTALL_PREFIX="${INSTALL_PREFIX:-/opt/mesa-zink}"
JOBS="${JOBS:-8}"

echo "=== Building Mesa Zink ($MESA_VERSION) ==="

mkdir -p "$BUILD_ROOT"
cd "$BUILD_ROOT"

# Ensure meson is in PATH
if [ -d "$BUILD_ROOT/venv/bin" ]; then
  export PATH="$BUILD_ROOT/venv/bin:$PATH"
fi

if [ ! -d "mesa-$MESA_VERSION" ]; then
  echo "Downloading Mesa $MESA_VERSION..."
  wget -c "https://archive.mesa3d.org/mesa-$MESA_VERSION.tar.xz"
  tar -xf "mesa-$MESA_VERSION.tar.xz"
fi

# CRITICAL NOTE:
# In Mesa meson build files, `subdir('gallium/targets/dril')` (which builds zink_dri.so)
# requires `with_gallium and with_gbm` to be true when compiling with X11 DRI.
# Therefore, -Dgbm=enabled is MANDATORY for zink_dri.so generation!

echo "Configuring Meson for Zink (with -Dgbm=enabled)..."
meson setup build-zink "mesa-$MESA_VERSION" \
  --prefix="$INSTALL_PREFIX" \
  --libdir=lib \
  --buildtype=release \
  -Dgallium-drivers=zink \
  -Dvulkan-drivers= \
  -Dplatforms=x11 \
  -Dglx=dri \
  -Degl=enabled \
  -Dgles2=enabled \
  -Dgbm=enabled \
  -Dllvm=disabled \
  -Dbuild-tests=false

echo "Compiling Zink with -j$JOBS..."
ninja -C build-zink -j"$JOBS"

echo "Installing Zink to $INSTALL_PREFIX..."
ninja -C build-zink install

# Verify DRI driver exists
if [ -f "$INSTALL_PREFIX/lib/dri/zink_dri.so" ]; then
  echo "✓ Zink build verified! $INSTALL_PREFIX/lib/dri/zink_dri.so is present."
else
  echo "⚠ Warning: zink_dri.so not found in $INSTALL_PREFIX/lib/dri/."
fi
