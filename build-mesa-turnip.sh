#!/usr/bin/env bash
# ==============================================================================
# build-mesa-turnip.sh
# Build Mesa Turnip Vulkan Driver with Qualcomm KGSL Kernel Backend
# Run inside Debian arm64 chroot as root.
# ==============================================================================
set -euo pipefail

MESA_VERSION="${MESA_VERSION:-25.2.6}"
BUILD_ROOT="${BUILD_ROOT:-/opt/mesa-kgsl-build}"
INSTALL_PREFIX="${INSTALL_PREFIX:-/opt/mesa-kgsl}"
JOBS="${JOBS:-8}"

echo "=== Building Mesa Turnip KGSL ($MESA_VERSION) ==="

mkdir -p "$BUILD_ROOT"
cd "$BUILD_ROOT"

# Install build dependencies
apt-get update
apt-get install -y --no-install-recommends \
  build-essential ninja-build python3-pip python3-setuptools python3-wheel \
  bison flex pkg-config libx11-dev libxext-dev libxdamage-dev libxcb-glx0-dev \
  libxcb-dri2-0-dev libxcb-dri3-dev libxcb-present-dev libxcb-sync-dev \
  libxshmfence-dev libxxf86vm-dev libxrandr-dev glslang-tools python3-mako \
  python3-yaml wget tar xz-utils libvulkan-dev vulkan-tools

# Use python virtual environment for recent meson if required
if ! command -v meson &>/dev/null; then
  python3 -m venv "$BUILD_ROOT/venv"
  "$BUILD_ROOT/venv/bin/pip" install --upgrade pip meson
  export PATH="$BUILD_ROOT/venv/bin:$PATH"
fi

# Download Mesa source if not present
if [ ! -d "mesa-$MESA_VERSION" ]; then
  echo "Downloading Mesa $MESA_VERSION..."
  wget -c "https://archive.mesa3d.org/mesa-$MESA_VERSION.tar.xz"
  tar -xf "mesa-$MESA_VERSION.tar.xz"
fi

echo "Configuring Meson for Turnip KGSL..."
meson setup build-turnip "mesa-$MESA_VERSION" \
  --prefix="$INSTALL_PREFIX" \
  --libdir=lib \
  --buildtype=release \
  -Dgallium-drivers= \
  -Dvulkan-drivers=freedreno \
  -Dfreedreno-kmds=kgsl \
  -Dplatforms=x11 \
  -Degl=disabled \
  -Dglx=disabled \
  -Dgbm=disabled \
  -Dllvm=disabled \
  -Dbuild-tests=false

echo "Compiling Turnip with -j$JOBS..."
ninja -C build-turnip -j"$JOBS"

echo "Installing Turnip to $INSTALL_PREFIX..."
ninja -C build-turnip install

# Generate ICD JSON
mkdir -p "$INSTALL_PREFIX/share/vulkan/icd.d"
cat <<EOF > "$INSTALL_PREFIX/share/vulkan/icd.d/turnip_icd.json"
{
  "file_format_version": "1.0.0",
  "ICD": {
    "library_path": "$INSTALL_PREFIX/lib/libvulkan_freedreno.so",
    "api_version": "1.3.0"
  }
}
EOF

echo "✓ Turnip KGSL build completed successfully!"
echo "ICD Location: $INSTALL_PREFIX/share/vulkan/icd.d/turnip_icd.json"
