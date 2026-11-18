# TWRP device tree for the Samsung Galaxy M30s (m30s), twrp-12.1

Work in progress. **Not tested on a device yet.**

The official TWRP for the M30s (3.7.0_9-0) is built from the android-9.0
tree and has no data decryption support. This tree moves the device to the
twrp-12.1 source branch as a first step towards decrypting the stock One UI
data partition from recovery.

| | |
| ---: | :--- |
| Chipset | Exynos 9611 |
| Shipped OS | Android 9 (system-as-root, no dynamic partitions) |
| Display | 1080 x 2340 |
| Storage | UFS, /data is f2fs |

## State

Branch `twrp-12.1`: the plain port, no decryption.
Branch `twrp-12.1-decrypt`: the same plus the decryption attempt described below.

- [ ] boots on a device
- [ ] data decryption (written, builds, **never run on a device**)

## Decryption (branch `twrp-12.1-decrypt`)

Stock One UI on this phone uses file based encryption (`fileencryption=ice`,
policy v1) with a keymaster 4.0 and a gatekeeper 1.0 HIDL HAL on top of
Samsung's secure world (TEEGRIS). TWRP 12.1 can use exactly these two HALs,
so its own decryption code is used unchanged.

What is special here:

- **No Samsung file is in the image.** At boot `m30s_tee.sh` mounts the
  phone's vendor and system partitions read-only, copies `tzdaemon`, the
  keymaster and gatekeeper services, the libraries they load and the trusted
  apps (`/vendor/tee`) into the ramdisk, and unmounts again. The files always
  match the installed firmware.
- The daemons run as the same user and groups as in the stock firmware, and
  `efs` is mounted at `/mnt/vendor/efs` like in a normal boot, because the
  secure storage of the trusted apps lives in `/mnt/vendor/efs/tee`.
- `patches/0001-*.patch` (applied to `bootable/recovery` by the workflow)
  makes TWRP wait up to 60 seconds for `m30s.tee.ready` before it decrypts,
  and skip decryption if the services did not come up. Without it TWRP would
  hang on the splash screen forever in that case.
- The image header must report the **same Android version and security patch
  level as the installed firmware**, see the comment in `BoardConfig.mk`.
  The default (2021-01-01) is deliberately too old: such a build cannot
  decrypt and cannot change anything. Build with the phone's real values:
  **Actions > Build TWRP for m30s > Run workflow**, branch
  `twrp-12.1-decrypt`, inputs `os_version` and `security_patch`.

Before testing it on a phone:

- Copy everything important off the phone. This is experimental and touches
  the same keys the system uses.
- Make a backup of the EFS partition with the current TWRP first. This build
  mounts efs read-write, as the system does.

If decryption does not work, these files say why (pull them with adb or copy
them to the SD card):

- `/tmp/m30s_tee.log` : the bring-up of Samsung's services
- `/tmp/recovery.log` : TWRP's own log
- `logcat -d` : messages from tzdaemon, keymaster, gatekeeper, keystore2

## Sources

- Layout, makefiles, init scripts and `ueventd.rc`: adapted from
  [TeamWin/android_device_samsung_a50](https://github.com/TeamWin/android_device_samsung_a50)
  (android-12.1), a sibling device with the Exynos 9610.
- `prebuilt/Image` and `prebuilt/dtbo.img`: unchanged copies of
  `prebuilt/zImage` and `prebuilt/recovery_dtbo` from
  [TeamWin/android_device_samsung_m30s](https://github.com/TeamWin/android_device_samsung_m30s)
  (android-9.0, commit `2f62939eaf31`). Kernel version 4.14.62.
- Partition list and boot image header values: from the same official m30s tree.

The partition sizes in `BoardConfig.mk` are the A50's and are not confirmed
for the M30s.

## Build

GitHub Actions builds it (`.github/workflows/build.yml`) and uploads
`recovery.img` plus an Odin `.tar` as an artifact.

The workflow also prints what the bootloader will read from the image header
(`header.txt` in the artifact).

By hand, with the
[minimal TWRP manifest](https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp)
(branch twrp-12.1):

```bash
git clone <this repo> -b twrp-12.1 device/samsung/m30s
export ALLOW_MISSING_DEPENDENCIES=true
. build/envsetup.sh
lunch twrp_m30s-eng
mka recoveryimage
```

## Copyright

```
#
# Copyright (C) 2024 The TWRP Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
```
