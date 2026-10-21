#!/usr/bin/env bash
set -Eeuo pipefail

export ANDROID_HOME=/opt/android-sdk
export ANDROID_SDK_ROOT=/opt/android-sdk
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export DISPLAY=:1

SDKMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
AVDMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager"
EMULATOR="$ANDROID_HOME/emulator/emulator"
ADB="$ANDROID_HOME/platform-tools/adb"

AVD_NAME="Android11Play"
LOG_DIR="/home/android/android-logs"
AVD_DIR="/home/android/.android/avd/${AVD_NAME}.avd"

mkdir -p "$LOG_DIR" /home/android/.android/avd
chown -R android:android /home/android

echo "[1/4] Checking Android 11 Google Play system image..."

if [ ! -x "$EMULATOR" ] || [ ! -x "$AVDMANAGER" ] || [ ! -x "$ADB" ]; then
    echo "[ERROR] Android SDK components are missing."
    exit 1
fi

if [ ! -d "$ANDROID_HOME/system-images/android-30/google_apis_playstore/x86_64" ]; then
    echo "[ERROR] Android 11 Google Play system image was not found."
    exit 1
fi

if [ ! -d "$AVD_DIR" ]; then
    echo "[INFO] Creating AVD: $AVD_NAME"
    echo "no" | runuser -u android -- env \
        HOME=/home/android \
        ANDROID_HOME="$ANDROID_HOME" \
        ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT" \
        "$AVDMANAGER" create avd \
        --force \
        --name "$AVD_NAME" \
        --package "system-images;android-30;google_apis_playstore;x86_64" \
        --device "pixel_2"
fi

CONFIG_INI="$AVD_DIR/config.ini"
if [ -f "$CONFIG_INI" ]; then
    if grep -q '^disk.dataPartition.size=' "$CONFIG_INI"; then
        sed -i 's/^disk.dataPartition.size=.*/disk.dataPartition.size=4096M/' "$CONFIG_INI"
    else
        printf '\ndisk.dataPartition.size=4096M\n' >> "$CONFIG_INI"
    fi

    if grep -q '^hw.keyboard=' "$CONFIG_INI"; then
        sed -i 's/^hw.keyboard=.*/hw.keyboard = yes/' "$CONFIG_INI"
    else
        printf '\nhw.keyboard = yes\n' >> "$CONFIG_INI"
    fi

    if grep -q '^hw.keyboard.charmap=' "$CONFIG_INI"; then
        sed -i 's/^hw.keyboard.charmap=.*/hw.keyboard.charmap = qwerty2/' "$CONFIG_INI"
    else
        printf 'hw.keyboard.charmap = qwerty2\n' >> "$CONFIG_INI"
    fi
fi

echo "[2/4] Starting virtual display..."

Xvfb :1 -screen 0 1080x1920x24 -ac \
    >"$LOG_DIR/xvfb.log" 2>&1 &
XVFB_PID=$!

EMULATOR_PID=""
VNC_PID=""
NOVNC_PID=""

cleanup() {
    [ -z "$NOVNC_PID" ] || kill "$NOVNC_PID" 2>/dev/null || true
    [ -z "$VNC_PID" ] || kill "$VNC_PID" 2>/dev/null || true
    [ -z "$EMULATOR_PID" ] || kill "$EMULATOR_PID" 2>/dev/null || true
    kill "$XVFB_PID" 2>/dev/null || true
}
trap cleanup EXIT

sleep 2

echo "[3/4] Starting noVNC services..."

x11vnc \
    -display :1 \
    -forever \
    -shared \
    -nopw \
    -listen 0.0.0.0 \
    -rfbport 5900 \
    >"$LOG_DIR/x11vnc.log" 2>&1 &
VNC_PID=$!

websockify --web=/usr/share/novnc \
    0.0.0.0:6080 127.0.0.1:5900 \
    >"$LOG_DIR/novnc.log" 2>&1 &
NOVNC_PID=$!

sleep 2

echo "[4/4] Starting Android emulator with KVM..."
rm -f "$AVD_DIR/multiinstance.lock" "$AVD_DIR/hardware-qemu.ini.lock"

"$ADB" start-server

runuser -u android -- env \
    HOME=/home/android \
    DISPLAY=:1 \
    ANDROID_HOME="$ANDROID_HOME" \
    ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT" \
    "$EMULATOR" \
    -avd "$AVD_NAME" \
    -gpu swiftshader_indirect \
    -accel on \
    -no-audio \
    -no-boot-anim \
    -no-metrics \
    >"$LOG_DIR/emulator.log" 2>&1 &
EMULATOR_PID=$!

echo "[INFO] Waiting for Android to boot..."

BOOT_OK=0
for _ in $(seq 1 360); do
    if ! kill -0 "$EMULATOR_PID" 2>/dev/null; then
        echo "[ERROR] Emulator process exited. Recent log:"
        tail -n 60 "$LOG_DIR/emulator.log"
        exit 1
    fi

    if [ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; then
        BOOT_OK=1
        break
    fi

    sleep 1
done

if [ "$BOOT_OK" -ne 1 ]; then
    echo "[ERROR] Android did not boot within 360 seconds."
    tail -n 60 "$LOG_DIR/emulator.log"
    exit 1
fi

echo "[OK] Android boot completed."
echo "[OK] noVNC is listening on port 6080."
echo "[INFO] Open the forwarded port 6080 in Codespaces."

wait "$EMULATOR_PID"
