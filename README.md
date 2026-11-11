# Adrenux: Snapdragon Adreno Linux GPU Acceleration (Turnip KGSL + Mesa Zink)

Complete guide and automation scripts to run an **ARM64 Debian Chroot** on Android with native **Hardware GPU Acceleration (Vulkan + OpenGL)** using open-source Mesa drivers (**Turnip KGSL** and **Zink**) displayed via **Termux:X11**.

---

## Test Results & Screenshots

Direct device captures verifying the environment, hardware detection, and 3D rendering:

### 1. Debian 12 (Bookworm) ARM64 Boot & System Info
GNOME Shell 43.9 running on Qualcomm Snapdragon Kryo CPU with Mutter window compositor:

![Debian 12 ARM64 Neofetch](assets/debian-neofetch.png)

### 2. GPU Hardware Driver Verification (glxinfo & glxgears)
Direct terminal verification of `glxinfo` detecting `zink Vulkan 1.0 (Turnip Adreno (TM) 612 (MESA_TURNIP))` running alongside 3D `glxgears`:

![GPU Acceleration Verification](assets/gpu-test.png)

### 3. Desktop Environment & Applications
GNOME Shell 43 desktop interface and standard desktop browser (Firefox) running natively inside the chroot:

| GNOME Shell 43 Desktop | Firefox Running on Debian Chroot |
| :---: | :---: |
| ![GNOME Desktop](assets/gnome-desktop.png) | ![Firefox](assets/firefox-running.png) |

---

## Architecture

Standard Linux chroot setups on Android default to CPU software rendering (`llvmpipe`), causing high CPU load, thermal throttling, and choppy compositor rendering. This project routes rendering directly to the Qualcomm Adreno GPU hardware:

```text
+--------------------------------------------------------+
| Desktop Environment / Apps (GNOME 43, XFCE4, etc.)     |
+---------------------------+----------------------------+
                            | (OpenGL API calls)
                            v
+--------------------------------------------------------+
| Mesa Zink (Gallium OpenGL-over-Vulkan Driver)           |
| Configuration: GALLIUM_THREAD=0, LIBGL_KOPPER_DRI2=1    |
+---------------------------+----------------------------+
                            | (Vulkan API calls)
                            v
+--------------------------------------------------------+
| Mesa Turnip (Freedreno Vulkan Driver)                  |
| KMD Backend: Kernel Graphics Support Layer (KGSL)      |
+---------------------------+----------------------------+
                            | (Kernel ioctl)
                            v
+--------------------------------------------------------+
| Android Kernel Device Node: /dev/kgsl-3d0              |
+---------------------------+----------------------------+
                            | (Hardware GPU)
                            v
+--------------------------------------------------------+
| Qualcomm Adreno GPU (600 / 700 Series)                 |
+--------------------------------------------------------+
```

---

## Hardware Compatibility

This configuration uses Mesa Turnip compiled with the **KGSL** (`-Dfreedreno-kmds=kgsl`) backend, which interfaces directly with Qualcomm's `/dev/kgsl-3d0` character device found in Qualcomm Android kernels.

> [!NOTE]
> **Honest Compatibility Disclaimer:**
> This configuration has **only been tested and verified on Adreno 612 (Snapdragon 675)**.
> Other chipsets listed below share the same KGSL kernel interface architecture and in theory should work, but they **have not been physically tested** in this project. Do not assume guaranteed plug-and-play functionality without testing.

### Chipset & GPU Matrix

| GPU Family | Adreno Model | Snapdragon SoC Examples | Test Status | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Adreno 600 Series** | **Adreno 612** | Snapdragon 675 (SM6150) | **Tested & Working** | Verified with vkcube, glxgears, and GNOME 43 |
| | **Adreno 610** | Snapdragon 665, 662, 460 | Untested | Shared KGSL architecture, theoretically compatible |
| | **Adreno 615 / 616** | Snapdragon 670, 710, 712 | Untested | Shared KGSL architecture, theoretically compatible |
| | **Adreno 618** | Snapdragon 720G, 730, 730G, 732G | Untested | Shared KGSL architecture, theoretically compatible |
| | **Adreno 619** | Snapdragon 750G, 690, 695, 480 | Untested | Shared KGSL architecture, theoretically compatible |
| | **Adreno 620** | Snapdragon 765, 765G, 768G | Untested | Shared KGSL architecture, theoretically compatible |
| | **Adreno 630** | Snapdragon 845 | Untested | Mature target in upstream Freedreno |
| | **Adreno 640** | Snapdragon 855, 855+ | Untested | Shared KGSL architecture, theoretically compatible |
| | **Adreno 642L / 643** | Snapdragon 778G, 778G+, 782G | Untested | Shared KGSL architecture, theoretically compatible |
| | **Adreno 650** | Snapdragon 865, 865+, 870 | Untested | Shared KGSL architecture, theoretically compatible |
| | **Adreno 660** | Snapdragon 888, 888+ | Untested | Shared KGSL architecture, theoretically compatible |
| **Adreno 700 Series** | **Adreno 730** | Snapdragon 8 Gen 1 | Untested | Requires Mesa 24.x/25.x |
| | **Adreno 740** | Snapdragon 8 Gen 2 | Untested | Requires Mesa 24.x/25.x |
| | **Adreno 750** | Snapdragon 8 Gen 3 | Untested | Requires Mesa 24.x/25.x |

> [!WARNING]
> **Incompatible Devices:** MediaTek (Mali / Immortalis) and Samsung Exynos (Mali / Xclipse AMD) devices **are not supported** because they lack Qualcomm's KGSL driver interface. Legacy Adreno GPUs (Adreno 5xx and older) lack modern Vulkan 1.3 support.

### Realistic Expectations & Technical Limitations
- **Not a Native Desktop Replacement:** This project is intended for experimentation and portable Linux utilities. Real-world performance is strictly bound by your phone's thermal dissipation and kernel frequency throttles during sustained workloads.
- **Rendering Artifacts:** Certain applications with complex OpenGL shaders or unsupported extensions may produce visual artifacts during Zink-to-Vulkan translation.
- **Chroot Environment Boundaries:** Android chroot environments share the host kernel. Services like full PolKit/PolicyKit, UPower, and GNOME screencast run with restricted functionality or missing daemons.

### Requirements & Prerequisites
- **Root Access:** Magisk, KernelSU, or APatch (required for chroot mounts and `/dev/kgsl-3d0` read/write permissions).
- **Kernel Version:** Linux 4.9, 4.14, 4.19, 5.4, 5.10, or 5.15+ with KGSL driver enabled.
- **Android OS:** Android 9 through Android 14/15.
- **Termux & Termux:X11:** Latest releases from GitHub.
- **Linux Distribution:** Debian 12 (Bookworm) arm64 installed via `chroot-distro`.

---

## Installation & Setup

All automation scripts are located directly in the root of this repository.

### 1. Prepare Termux and Debian Rootfs
In Termux (regular user):
```bash
pkg update && pkg install -y tsu chroot-distro pulseaudio
chroot-distro install debian
```

### 2. Mount Chroot Filesystem
Run `mount-chroot.sh` as root in Android (`su`):
```bash
su
sh mount-chroot.sh
```
This script bind-mounts `/dev`, `/dev/pts`, `/dev/shm`, `/proc`, and `/sys`, grants `666` permissions to `/dev/kgsl-3d0`, and bridges the Termux X11 UNIX socket.

### 3. Compile Mesa Turnip & Zink Drivers

Log into the Debian chroot (`chroot-distro login debian`):

#### A. Build Turnip Vulkan (KGSL Backend)
```bash
bash build-mesa-turnip.sh
```
*Meson flags applied:*
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

#### B. Build Zink (OpenGL over Vulkan)
```bash
bash build-mesa-zink.sh
```
> [!IMPORTANT]
> **Mandatory `-Dgbm=enabled` Flag:**
> In Mesa 25.x, compiling GLX DRI without `-Dgbm=enabled` will cause Meson to silently omit `subdir('gallium/targets/dril')`, resulting in a missing `zink_dri.so`. Setting `-Dgbm=enabled` is strictly required.

*Meson flags applied:*
```bash
meson setup build-zink mesa-25.2.6 \
  --prefix=/opt/mesa-zink --libdir=lib --buildtype=release \
  -Dgallium-drivers=zink \
  -Dvulkan-drivers= \
  -Dplatforms=x11 -Dglx=dri -Degl=enabled -Dgles2=enabled \
  -Dgbm=enabled -Dllvm=disabled -Dbuild-tests=false
```

#### C. Verify Built Driver Binaries
Run the verification script to inspect AArch64 ELF headers and dynamic linker dependencies:
```bash
bash verify-build.sh
```

---

## Running the Accelerated Desktop

### 1. Launch Termux:X11 Display
In Android Termux:
```bash
termux-x11 :2 &
am start -n com.termux.x11/com.termux.x11.MainActivity
```

### 2. Start Desktop Inside Debian Chroot
Inside Debian chroot:
```bash
# Launch GNOME Shell 43
bash start-desktop.sh gnome

# Or launch XFCE4
bash start-desktop.sh xfce
```

### Critical Environment Variables for Stability:
```bash
export VK_ICD_FILENAMES=/opt/mesa-kgsl/share/vulkan/icd.d/turnip_icd.json
export LD_LIBRARY_PATH=/opt/mesa-zink/lib:$LD_LIBRARY_PATH
export LIBGL_DRIVERS_PATH=/opt/mesa-zink/lib/dri
export MESA_LOADER_DRIVER_OVERRIDE=zink
export GALLIUM_DRIVER=zink

# COMPOSITOR STABILITY WORKAROUND:
# Prevents multithreaded queue race conditions in tu_CmdPipelineBarrier2
export GALLIUM_THREAD=0
export LIBGL_KOPPER_DRI2=1
export GSK_RENDERER=cairo
export GTK_A11Y=none
export NO_AT_BRIDGE=1
```

---

## Verification & Diagnostics

To verify that hardware acceleration is active (and not falling back to software llvmpipe), run:
```bash
bash test-gpu.sh
```

### Expected Output:

1. **Vulkan Physical Device (`vulkaninfo`):**
   ```text
   deviceName     = Turnip Adreno (TM) 612
   driverName     = freedreno
   apiVersion     = 1.3.318
   ```

2. **Vulkan Render Test (`vkcube`):**
   ```text
   Selected GPU 0: Turnip Adreno (TM) 612, type: IntegratedGpu
   FRAME_TEST_EXIT=0 (120 frames rendered)
   ```

3. **OpenGL Zink Check (`glxinfo -B`):**
   ```text
   OpenGL vendor string: Mesa
   OpenGL renderer string: zink Vulkan 1.0(Turnip Adreno (TM) 612 (MESA_TURNIP))
   OpenGL core profile version string: 4.0 (Core Profile) Mesa 25.2.6
   OpenGL ES profile version string: OpenGL ES 3.2 Mesa 25.2.6
   Accelerated: yes
   ```

4. **OpenGL Framerate (`glxgears`):**
   ```text
   Running synchronized to the vertical refresh.
   432 frames in 5.0 seconds = 86.400 FPS (VSync locked)
   ```

---

## Hardware Tuning (`tune-hardware.sh`)

To mitigate CPU and storage bottlenecks, run `tune-hardware.sh` as root on Android:
- **CPU:** Brings all CPU cores online and configures cpufreq governors to `schedutil` with balanced baseline frequencies.
- **GPU:** Sets Adreno devfreq clock rate to maximum permitted levels without triggering SurfaceFlinger lockups.
- **Storage:** Sets UFS storage I/O queue scheduler to `deadline` with `read_ahead_kb=2048`.
- **IPC Sockets:** Expands Unix network socket buffers (`net.core.wmem_default=8388608`) to minimize X11 communication delays.

---

## License
MIT License. Open-source and free for the community.
