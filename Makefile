PREFIX ?= /usr
DESTDIR ?=

CC ?= gcc
PKG_CONFIG ?= pkg-config
CFLAGS ?= -O2 -Wall -Wextra
LDFLAGS ?=
# IMS needs newer libqmi APIs; the base support layer builds without them.
WITH_IMS ?= 0
IMS_PACKAGES = qmi-glib qrtr-glib gio-2.0 glib-2.0

BIN = marble-touchboost
ifeq ($(WITH_IMS),1)
BIN += marble-imsctl
endif

.PHONY: all clean install install-debian

all: $(BIN)

marble-touchboost: src/marble-touchboost.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -o $@ $<

marble-imsctl: src/marble-imsctl.c
	$(PKG_CONFIG) --atleast-version=1.39.1 qmi-glib
	$(PKG_CONFIG) --exists $(IMS_PACKAGES)
	$(CC) $(CPPFLAGS) -DQMI_DISABLE_DEPRECATED $(CFLAGS) $$($(PKG_CONFIG) --cflags $(IMS_PACKAGES)) \
		$(LDFLAGS) -o $@ $< $$($(PKG_CONFIG) --libs $(IMS_PACKAGES))

clean:
	rm -f marble-touchboost marble-imsctl

install: all
	# Binary and helper scripts
	install -d $(DESTDIR)$(PREFIX)/libexec
	install -m 755 $(BIN) $(DESTDIR)$(PREFIX)/libexec/
	install -m 755 scripts/marble-hardware-tuning.sh $(DESTDIR)$(PREFIX)/libexec/marble-hardware-tuning.sh
	install -m 755 scripts/marble-panel-on.sh $(DESTDIR)$(PREFIX)/libexec/marble-panel-on
	install -m 755 scripts/marble-compositor-boost.sh $(DESTDIR)$(PREFIX)/libexec/marble-compositor-boost
	install -m 755 scripts/marble-helper $(DESTDIR)$(PREFIX)/libexec/marble-helper

	# ALSA UCM2 profiles
	install -d $(DESTDIR)$(PREFIX)/share/alsa/ucm2/conf.d/sm8450
	install -m 644 alsa/ucm2/conf.d/sm8450/SM8475-Xiaomi-Marble.conf $(DESTDIR)$(PREFIX)/share/alsa/ucm2/conf.d/sm8450/
	install -d $(DESTDIR)$(PREFIX)/share/alsa/ucm2/Qualcomm/sm8450/xiaomi-marble
	install -m 644 alsa/ucm2/Qualcomm/sm8450/xiaomi-marble/HiFi.conf $(DESTDIR)$(PREFIX)/share/alsa/ucm2/Qualcomm/sm8450/xiaomi-marble/

	# udev rules
	install -d $(DESTDIR)$(PREFIX)/lib/udev/rules.d
	install -m 644 udev/60-marble-storage.rules $(DESTDIR)$(PREFIX)/lib/udev/rules.d/
	install -m 644 udev/61-marble-gpu.rules $(DESTDIR)$(PREFIX)/lib/udev/rules.d/
	install -m 644 udev/81-libssc-xiaomi-marble.rules $(DESTDIR)$(PREFIX)/lib/udev/rules.d/
	install -m 644 udev/90-iio-sensor-proxy-ssc-accel-proximity.rules $(DESTDIR)$(PREFIX)/lib/udev/rules.d/

	# systemd units
	install -d $(DESTDIR)$(PREFIX)/lib/systemd/system
	install -m 644 systemd/marble-hardware-tuning.service $(DESTDIR)$(PREFIX)/lib/systemd/system/
	install -m 644 systemd/marble-touchboost.service $(DESTDIR)$(PREFIX)/lib/systemd/system/
	install -m 644 systemd/marble-panel-on.service $(DESTDIR)$(PREFIX)/lib/systemd/system/
	install -m 644 systemd/marble-compositor-boost.service $(DESTDIR)$(PREFIX)/lib/systemd/system/
ifeq ($(WITH_IMS),1)
	install -m 644 systemd/marble-ims-enable.service $(DESTDIR)$(PREFIX)/lib/systemd/system/
endif

	# systemd drop-ins
	install -d $(DESTDIR)$(PREFIX)/lib/systemd/system/hexagonrpcd-sdsp.service.d
	install -m 644 systemd/drop-ins/hexagonrpcd-sdsp.service.d/60-marble-registry.conf $(DESTDIR)$(PREFIX)/lib/systemd/system/hexagonrpcd-sdsp.service.d/
	install -d $(DESTDIR)$(PREFIX)/lib/systemd/system/iio-sensor-proxy.service.d
	install -m 644 systemd/drop-ins/iio-sensor-proxy.service.d/60-marble-sensors.conf $(DESTDIR)$(PREFIX)/lib/systemd/system/iio-sensor-proxy.service.d/

	# sysctl and environment
	install -d $(DESTDIR)$(PREFIX)/lib/sysctl.d
	install -m 644 sysctl/99-marble-vm.conf $(DESTDIR)$(PREFIX)/lib/sysctl.d/
	install -d $(DESTDIR)$(PREFIX)/lib/environment.d
	install -m 644 environment/90-xiaomi-marble.conf $(DESTDIR)$(PREFIX)/lib/environment.d/

# Debian runs a wrapper unit rather than the per-DSP hexagonrpcd unit.
# Keep these assets here, so packaging only selects the installation flavor.
install-debian: install
	install -m 644 systemd/marble-mac-restore.service $(DESTDIR)$(PREFIX)/lib/systemd/system/
	# This watcher restarts Debian's hexagonrpcd wrapper by name.
	install -m 644 systemd/marble-sensors-watch.service $(DESTDIR)$(PREFIX)/lib/systemd/system/
	install -m 644 systemd/marble-modem-recover.service systemd/marble-modem-recover.timer $(DESTDIR)$(PREFIX)/lib/systemd/system/
	install -m 644 udev/82-libssc-marble-sensors.rules $(DESTDIR)$(PREFIX)/lib/udev/rules.d/
	install -d $(DESTDIR)$(PREFIX)/lib/systemd/system/qbootctl.service.d
	install -m 644 systemd/drop-ins/qbootctl.service.d/wait-for-partitions.conf $(DESTDIR)$(PREFIX)/lib/systemd/system/qbootctl.service.d/
	install -d $(DESTDIR)$(PREFIX)/lib/systemd/system/qcom-modem-setup.service.d
	install -m 644 systemd/drop-ins/qcom-modem-setup.service.d/10-marble-sim-wait.conf $(DESTDIR)$(PREFIX)/lib/systemd/system/qcom-modem-setup.service.d/
	# NetworkManager requires keyfiles to be private, even with no credentials.
	install -d $(DESTDIR)$(PREFIX)/lib/modprobe.d
	install -m 644 modprobe/marble-wlan.conf $(DESTDIR)$(PREFIX)/lib/modprobe.d/
	install -d $(DESTDIR)$(PREFIX)/lib/NetworkManager/system-connections
	install -m 600 network-manager/ct-data.nmconnection $(DESTDIR)$(PREFIX)/lib/NetworkManager/system-connections/
	install -d $(DESTDIR)$(PREFIX)/share/libcamera/ipa/simple
	install -m 644 camera/imx355.yaml $(DESTDIR)$(PREFIX)/share/libcamera/ipa/simple/
	install -d $(DESTDIR)$(PREFIX)/lib/systemd/system/hexagonrpcd.service.d
	install -m 644 systemd/debian/hexagonrpcd.service.d/60-marble.conf $(DESTDIR)$(PREFIX)/lib/systemd/system/hexagonrpcd.service.d/
	rm -rf $(DESTDIR)$(PREFIX)/lib/systemd/system/hexagonrpcd-sdsp.service.d
	sed -i \
		-e 's|^Wants=hexagonrpcd-sdsp\.service$$|Wants=hexagonrpcd.service|' \
		-e 's|^After=hexagonrpcd-sdsp\.service$$|After=hexagonrpcd.service|' \
		$(DESTDIR)$(PREFIX)/lib/systemd/system/iio-sensor-proxy.service.d/60-marble-sensors.conf
	install -m 644 systemd/debian/iio-sensor-proxy.service.d/70-marble-restart.conf $(DESTDIR)$(PREFIX)/lib/systemd/system/iio-sensor-proxy.service.d/
	# Persist-derived Bluetooth addressing must not race bootmac's address.
	install -d $(DESTDIR)/etc/systemd/system
	ln -sfn /dev/null $(DESTDIR)/etc/systemd/system/bootmac-bluetooth.service
