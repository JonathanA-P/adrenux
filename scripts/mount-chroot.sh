#!/system/bin/sh
# ==============================================================================
# mount-chroot.sh
# Safely mount Android kernel filesystems and IPC sockets into Debian Chroot
# ==============================================================================
set -eu

ROOTFS="${1:-/data/data/com.termux/files/usr/var/lib/chroot-distro/containers/debian/rootfs}"
TERMUX_TMP="/data/data/com.termux/files/usr/tmp"

if [ "$(id -u)" -ne 0 ]; then
  echo "Error: This script must be run as root (su)." >&2
  exit 1
fi

if [ ! -d "$ROOTFS" ]; then
  echo "Error: Target rootfs '$ROOTFS' not found." >&2
  exit 1
fi

echo "[1/4] Preparing X11 socket directory..."
mkdir -p "$TERMUX_TMP/.X11-unix"
chmod 1777 "$TERMUX_TMP/.X11-unix"

safe_mount() {
  local target="$1"
  shift
  if ! grep -q "[[:space:]]$target[[:space:]]" /proc/mounts 2>/dev/null; then
    mkdir -p "$target"
    mount "$@" "$target"
    echo "  + Mounted $target"
  else
    echo "  = Already mounted: $target"
  fi
}

echo "[2/4] Mounting kernel filesystems into chroot..."
mount -o remount,suid /data 2>/dev/null || true
safe_mount "$ROOTFS" -o bind,suid "$ROOTFS"
safe_mount "$ROOTFS/dev" -o bind /dev
safe_mount "$ROOTFS/dev/cpuset" -o bind /dev/cpuset
safe_mount "$ROOTFS/dev/stune" -o bind /dev/stune
safe_mount "$ROOTFS/sys" -o bind /sys
safe_mount "$ROOTFS/proc" -t proc proc
mount -o remount,hidepid=0 "$ROOTFS/proc" 2>/dev/null || true
safe_mount "$ROOTFS/dev/pts" -t devpts -o rw,nosuid,noexec,relatime,gid=5,mode=620,ptmxmode=666 devpts
safe_mount "$ROOTFS/tmp/.X11-unix" -o bind "$TERMUX_TMP/.X11-unix"

echo "[3/4] Initializing POSIX shared memory & KGSL permissions..."
mkdir -p "$ROOTFS/dev/shm" "$ROOTFS/tmp/.shader_cache"
safe_mount "$ROOTFS/dev/shm" -t tmpfs -o rw,nosuid,nodev,mode=1777 tmpfs
chmod 1777 "$ROOTFS/dev/shm" 2>/dev/null || true
chmod 1777 "$ROOTFS/tmp/.shader_cache" 2>/dev/null || true

# Essential hardware nodes for Qualcomm Turnip KGSL Vulkan and inputs
chmod 666 /dev/kgsl-3d0 /dev/ion /dev/fuse /dev/uinput /dev/uhid 2>/dev/null || true

echo "[4/4] Mounting Android Internal Storage..."
mkdir -p "$ROOTFS/sdcard"
safe_mount "$ROOTFS/sdcard" -o bind /data/media/0

echo "✓ Debian chroot filesystem mounts ready at $ROOTFS."
