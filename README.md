# marble-device-support

Distribution-agnostic hardware support layer for the **Xiaomi Poco F5 / Redmi Note 12 Turbo** (`xiaomi-marble`, Qualcomm Snapdragon 7+ Gen 2 / SM7475).

Provides userland configuration, ALSA UCM2 audio profiles, udev rules, performance tuning services, and hardware initialization scripts for running mainline Linux distributions (postmarketOS, ALT Mobile, Void Linux, Arch Linux, Debian, etc.).

---

## Contents

* **ALSA UCM2**: Stereo speakers, WCD9385 3.5 mm headphones, and internal/headset microphone capture.
* **udev rules**:
  * `60-marble-storage.rules`: UFS storage scheduler tuning.
  * `61-marble-gpu.rules`: Adreno 725 runtime autosuspend delay and devfreq floor.
  * `81-libssc-xiaomi-marble.rules`: accelerometer mount matrix for the SSC sensors.
  * `90-iio-sensor-proxy-ssc-accel-proximity.rules`: asks `iio-sensor-proxy` for the accelerometer and the proximity sensor (upstream only enables light and compass).
* **Services & Daemons**:
  * `marble-touchboost`: Low-overhead C daemon monitoring `/dev/input` to boost CPU frequency floor during active touch interaction, ensuring stable 120 Hz compositor response.
  * `marble-compositor-boost`: Applies `uclamp.min` (512) to wayland compositors (`phoc`, `kwin_wayland`, `gnome-shell`).
  * `marble-hardware-tuning`: Initial boot-time sysfs knobs (interconnect, GPU devfreq).
  * `marble-panel-on`: Framebuffer refresh cycling for direct boots without initramfs.
* **Drop-in configurations**:
  * `hexagonrpcd-sdsp.service.d/60-marble-registry.conf`: Redirects sensor registry path to `/usr/share/qcom`.
  * `iio-sensor-proxy.service.d/60-marble-sensors.conf`: Binds sensor proxy to SSC sensor devices.
* **System Environment**:
  * `90-xiaomi-marble.conf`: GTK4 / Wayland rendering optimizations.
  * `99-marble-vm.conf`: Virtual memory dirty page thresholds for zram.

---

## Building and Installation

### Build

```bash
make
```

### Installation

```bash
sudo make install PREFIX=/usr
```

### Wired audio requirements

The UCM profile requires a matching kernel device tree and AudioReach topology:

* `WCD Playback` DAI link on `RX_CODEC_DMA_RX_0`, plus the WCD headphone DAPM routes.
* An RX0 playback graph in `SM8475-Xiaomi-Marble-tplg.bin`, alongside the existing
  TDM speaker and TX3 capture graphs.
* An MBHC headset threshold matched to MICBIAS2. The tested 2.75 V bias uses a
  2.6 V headset threshold; retaining the 1.7 V reference threshold misclassifies
  the tested microphone headset as line-out.

Install these dependencies together with this profile. The earlier
speaker-only topology lacks controls used by the new UCM verb.

`Headphones` and `Headset` use ALSA jack controls to switch output and input
when plugged in, with `Speaker` and `Mic` as the unplugged paths. Playback uses
PCM 1 for headphones and PCM 0 for speakers; capture uses PCM 2. Capture needs
two PCM channels even though the tested headset microphone supplies a mono
signal on channel 0. The verified headphone path is S16_LE, 48 kHz, stereo.
Codec capabilities alone do not establish 24-bit / 192 kHz support end to end.

Validated on the existing `7.2.8-sm8475-ged12055` kernel with the matching DTB
and topology: stereo headphone listening, external microphone quiet/tap/speech
recording, physical jack switching, and single-button `KEY_MEDIA` input events.
Speaker output after unplugging was also confirmed by listening. The profile
starts with conservative headphone and speaker gains.

### Enabling Services (systemd)

```bash
sudo systemctl enable marble-panel-on.service
sudo systemctl enable marble-hardware-tuning.service
sudo systemctl enable marble-touchboost.service
sudo systemctl enable marble-compositor-boost.service
```

`marble-panel-on.service` is required on any system that boots without an
initramfs: the msm DRM driver lights the panel only after a disable/enable
cycle, so without it the screen stays black even though the system is up.
It has to run before the display manager, which the unit orders itself.

---

## License

GPL-2.0-or-later / MIT (see individual file headers).
