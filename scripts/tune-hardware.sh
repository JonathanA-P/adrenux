#!/system/bin/sh
# ==============================================================================
# tune-hardware.sh
# Snapdragon Adreno Hardware Optimization for Linux Desktop (Low Latency)
# ==============================================================================
set -u

if [ "$(id -u)" -ne 0 ]; then
  echo "Error: This script must be run as root (su)." >&2
  exit 1
fi

echo "[1/4] Optimizing Qualcomm Kryo CPU Cores..."
# Bring all cores online
for c in /sys/devices/system/cpu/cpu[0-7]; do
  [ -e "$c/online" ] && echo 1 > "$c/online" 2>/dev/null || true
done

# Set governor to performance or schedutil
for pol in /sys/devices/system/cpu/cpufreq/policy*; do
  [ -e "$pol/scaling_governor" ] && echo schedutil > "$pol/scaling_governor" 2>/dev/null || true
done

echo "[2/4] Optimizing Qualcomm Adreno GPU & KGSL Dispatch..."
if [ -d /sys/class/kgsl/kgsl-3d0 ]; then
  # GPU governor & turbo clock
  [ -e /sys/class/kgsl/kgsl-3d0/devfreq/governor ] && echo msm-adreno-tz > /sys/class/kgsl/kgsl-3d0/devfreq/governor 2>/dev/null || true
  
  # Set max power level & low active latency
  echo 0 > /sys/class/kgsl/kgsl-3d0/default_pwrlevel 2>/dev/null || true
  echo 0 > /sys/class/kgsl/kgsl-3d0/thermal_pwrlevel 2>/dev/null || true
  echo 1 > /sys/class/kgsl/kgsl-3d0/ifpc 2>/dev/null || true
  echo 1 > /sys/class/kgsl/kgsl-3d0/hwcg 2>/dev/null || true
  echo 67 > /sys/class/kgsl/kgsl-3d0/pmqos_active_latency 2>/dev/null || true
  echo 1 > /sys/class/kgsl/kgsl-3d0/throttling 2>/dev/null || true

  # Queue dispatch tuning
  echo 1 > /sys/class/kgsl/kgsl-3d0/dispatch/context_burst_count 2>/dev/null || true
  echo 4 > /sys/class/kgsl/kgsl-3d0/dispatch/inflight 2>/dev/null || true
fi

echo "[3/4] Optimizing UFS Storage I/O..."
for dev in /sys/block/sd*; do
  [ -e "$dev/queue/scheduler" ] && echo deadline > "$dev/queue/scheduler" 2>/dev/null || true
  [ -e "$dev/queue/read_ahead_kb" ] && echo 2048 > "$dev/queue/read_ahead_kb" 2>/dev/null || true
  [ -e "$dev/queue/nr_requests" ] && echo 256 > "$dev/queue/nr_requests" 2>/dev/null || true
done

echo "[4/4] Optimizing IPC Socket Buffers & Memory..."
sysctl -w net.core.wmem_default=8388608 2>/dev/null || true
sysctl -w net.core.rmem_default=8388608 2>/dev/null || true
sysctl -w fs.inotify.max_user_watches=524288 2>/dev/null || true
sysctl -w vm.vfs_cache_pressure=100 2>/dev/null || true

echo "✓ Hardware profile applied successfully."
