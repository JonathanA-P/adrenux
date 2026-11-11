# Snapdragon Adreno Linux GPU Acceleration Guide (Turnip KGSL + Mesa Zink)

Complete guide and modular scripts to run an **ARM64 Debian Chroot** on Android with full **Hardware GPU Acceleration (Vulkan + OpenGL)** using open-source Mesa drivers (**Turnip KGSL** and **Zink**), displaying natively via **Termux:X11**.

---

## 🚀 Architecture Overview

Standard Linux chroots on Android typically default to CPU software rendering (`llvmpipe`), resulting in high CPU usage, thermal throttling, and poor window compositor performance. This project establishes a direct hardware pipeline to Qualcomm Adreno GPUs:

```text
┌────────────────────────────────────────────────────────┐
│ Desktop Environment / Apps (GNOME 43, XFCE4, Chromium)│
└───────────────────────────┬────────────────────────────┘
                            │ (OpenGL API calls)
                            ▼
┌────────────────────────────────────────────────────────┐
│ Mesa Zink (Gallium OpenGL-over-Vulkan Driver)           │
│ Configuration: GALLIUM_THREAD=0, LIBGL_KOPPER_DRI2=1    │
└───────────────────────────┬────────────────────────────┘
                            │ (Vulkan API calls)
                            ▼
┌────────────────────────────────────────────────────────┐
│ Mesa Turnip (Freedreno Vulkan Driver)                  │
│ Backend: Kernel Graphics Support Layer (KGSL)          │
└───────────────────────────┬────────────────────────────┘
                            │ (Direct ioctl calls)
                            ▼
┌────────────────────────────────────────────────────────┐
│ Android Kernel Device Node: /dev/kgsl-3d0              │
└───────────────────────────┬────────────────────────────┘
                            │ (Physical Hardware)
                            ▼
┌────────────────────────────────────────────────────────┐
│ Qualcomm Adreno GPU (600 / 700 Series)                 │
└────────────────────────────────────────────────────────┘
```

---

## 📱 Hardware Compatibility Matrix

This setup utilizes Mesa Turnip compiled with the **KGSL** (`-Dfreedreno-kmds=kgsl`) kernel backend. It communicates directly with Qualcomm's `/dev/kgsl-3d0` character device present in stock and custom Android kernels.

### 1. Supported Qualcomm Adreno GPUs & SoCs

| GPU Family | Adreno Model | Qualcomm Snapdragon SoCs | Status | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Adreno 600 Series** | **Adreno 612** | Snapdragon 675 (SM6150) | **Verified Working** | 120 FPS vkcube, ~88 FPS glxgears, GNOME 43 |
| | **Adreno 610** | Snapdragon 665, 662, 460 | Supported | Full Turnip KGSL compatibility |
| | **Adreno 615 / 616** | Snapdragon 670, 710, 712 | Supported | Full Turnip KGSL compatibility |
| | **Adreno 618** | Snapdragon 720G, 730, 730G, 732G | Supported | Excellent performance |
| | **Adreno 619** | Snapdragon 750G, 690, 695, 480, 480+ | Supported | Full Turnip KGSL compatibility |
| | **Adreno 620** | Snapdragon 765, 765G, 768G | Supported | Full Turnip KGSL compatibility |
| | **Adreno 630** | Snapdragon 845 | Supported | Mature Freedreno/Turnip target |
| | **Adreno 640** | Snapdragon 855, 855+ | Supported | High performance |
| | **Adreno 642L / 643** | Snapdragon 778G, 778G+, 782G | Supported | Very high performance |
| | **Adreno 650** | Snapdragon 865, 865+, 870 | Supported | Flagship performance |
| | **Adreno 660** | Snapdragon 888, 888+ | Supported | Flagship performance |
| **Adreno 700 Series** | **Adreno 730** | Snapdragon 8 Gen 1, 8+ Gen 1 | Supported | Requires Mesa 24.x/25.x |
| | **Adreno 740** | Snapdragon 8 Gen 2 | Supported | Requires Mesa 24.x/25.x |
| | **Adreno 750** | Snapdragon 8 Gen 3 | Supported | Requires Mesa 24.x/25.x |

> [!NOTE]
> **Unsupported Devices:** MediaTek (Mali / Immortalis) and Samsung Exynos (Mali / Xclipse RDNA) GPUs do not use the Qualcomm KGSL/Freedreno architecture and are **incompatible** with this Turnip driver. Older Adreno GPUs (Adreno 5xx or older) lack modern Vulkan 1.3 support.

### 2. Software & Kernel Prerequisites
- **Root Access:** Magisk, KernelSU, or APatch (required for chroot mounts and setting `/dev/kgsl-3d0` read/write permissions).
- **Kernel Version:** Linux 4.9, 4.14, 4.19, 5.4, 5.10, 5.15+ with Qualcomm KGSL driver.
- **Android OS:** Android 9 through Android 15.
- **Termux:** Latest build from GitHub / F-Droid.
- **Termux:X11:** Companion application for X11 display rendering.
- **Linux Distribution:** Debian 12 (Bookworm) arm64 or Ubuntu 22.04/24.04 arm64 installed via `chroot-distro`.

---

## 🛠️ Step-by-Step Installation

### Step 1: Install Termux & Debian Rootfs

In Termux:
```bash
pkg update && pkg install -y tsu chroot-distro pulseaudio
chroot-distro install debian
```

### Step 2: Prepare Chroot Filesystem Mounts

Run `scripts/mount-chroot.sh` as root in Android (`su`):
```bash
su -c "sh /path/to/scripts/mount-chroot.sh"
```
This script bind-mounts `/dev`, `/dev/pts`, `/dev/shm`, `/proc`, `/sys`, sets `/dev/kgsl-3d0` permissions to `666`, and bridges the Termux X11 UNIX socket.

### Step 3: Build Mesa Turnip Vulkan (KGSL Backend)

Inside the Debian chroot (`chroot-distro login debian`):
```bash
bash /path/to/scripts/build-mesa-turnip.sh
```
*Exact Meson Configuration applied:*
```bash
meson setup build-turnip mesa-25.2.6 \
  --prefix=/opt/mesa-kgsl --libdir=lib --buildtype=release \
  -Dgallium-drivers= \
  -Dvulkan-drivers=freedreno \
  -Dfreedreno-kmds=kgsl \
  -Dplatforms=x11 \
  -Degl=disabled -Dglx=disabled -Dgbm=disabled \
  -Dllvm=disabled -Dbuild-tests=false
```

### Step 4: Build Mesa Zink (OpenGL over Vulkan)

Inside the Debian chroot:
```bash
bash /path/to/scripts/build-mesa-zink.sh
```

> [!IMPORTANT]
> **Critical Mesa Gotcha (`-Dgbm=enabled`):**
> In Mesa 25.x, compiling with `-Dglx=dri` without `-Dgbm=enabled` will silently skip compiling `subdir('gallium/targets/dril')`, resulting in missing `zink_dri.so`. `-Dgbm=enabled` is **mandatory** for generating `zink_dri.so`.

*Exact Meson Configuration applied:*
```bash
meson setup build-zink mesa-25.2.6 \
  --prefix=/opt/mesa-zink --libdir=lib --buildtype=release \
  -Dgallium-drivers=zink \
  -Dvulkan-drivers= \
  -Dplatforms=x11 -Dglx=dri -Degl=enabled -Dgles2=enabled \
  -Dgbm=enabled -Dllvm=disabled -Dbuild-tests=false
```

---

## 🎮 Launching the Hardware-Accelerated Desktop

### 1. Start Termux:X11
In Termux (as normal user):
```bash
termux-x11 :2 &
am start -n com.termux.x11/com.termux.x11.MainActivity
```

### 2. Launch Accelerated Desktop Session
Inside Debian Chroot:
```bash
# Launch GNOME Shell 43
bash /path/to/scripts/start-desktop.sh gnome

# Or launch XFCE4
bash /path/to/scripts/start-desktop.sh xfce
```

### Essential Stability Environment Variables:
```bash
export VK_ICD_FILENAMES=/opt/mesa-kgsl/share/vulkan/icd.d/turnip_icd.json
export LD_LIBRARY_PATH=/opt/mesa-zink/lib:$LD_LIBRARY_PATH
export LIBGL_DRIVERS_PATH=/opt/mesa-zink/lib/dri
export MESA_LOADER_DRIVER_OVERRIDE=zink
export GALLIUM_DRIVER=zink

# CRITICAL FIX FOR COMPOSITOR STABILITY:
# Fixes multithreaded queue crash in tu_CmdPipelineBarrier2
export GALLIUM_THREAD=0
export LIBGL_KOPPER_DRI2=1
export GSK_RENDERER=cairo
export GTK_A11Y=none
export NO_AT_BRIDGE=1
```

---

## 📊 Verification & Diagnostics

Run `scripts/test-gpu.sh` inside the chroot:
```bash
bash /path/to/scripts/test-gpu.sh
```

### Expected Outputs:

1. **Vulkan Check (`vulkaninfo`):**
   ```text
   deviceName     = Turnip Adreno (TM) 612
   driverName     = freedreno
   apiVersion     = 1.3.318
   ```
2. **Vulkan Rendering (`vkcube`):**
   ```text
   Selected GPU 0: Turnip Adreno (TM) 612, type: IntegratedGpu
   FRAME_TEST_EXIT=0 (120 frames rendered without error)
   ```
3. **OpenGL Check (`glxinfo -B`):**
   ```text
   OpenGL vendor string: Mesa
   OpenGL renderer string: zink (Turnip Adreno (TM) 612)
   OpenGL core profile version string: 4.0 (Core Profile) Mesa 25.2.6
   Accelerated: yes
   ```
4. **OpenGL Performance (`glxgears`):**
   ```text
   Running synchronized to the vertical refresh.
   432 frames in 5.0 seconds = 86.400 FPS
   ```

---

## ⚡ Performance Tuning (`scripts/tune-hardware.sh`)

To eliminate CPU bottlenecks and storage latency on Snapdragon chips, run `scripts/tune-hardware.sh` as root:
- **CPU:** Brings all Kryo big and LITTLE cores online and sets scaling governors to `schedutil` or `performance`.
- **GPU:** Unlocks max Adreno devfreq clock rates (`745 MHz` turbo on Adreno 612).
- **Storage:** Optimizes UFS 2.1 / 3.1 I/O queue schedulers (`deadline`, `read_ahead_kb=2048`).
- **IPC:** Enlarges network & X11 Unix socket buffers (`net.core.wmem_default=8388608`) to prevent compositor stutter.

---

## 📄 License
MIT License. Open-source and free for the community.
