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

- [ ] boots on a device
- [ ] data decryption (not started in this tree: no crypto flags, no vendor files)

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
