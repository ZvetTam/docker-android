FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
    HOME=/home/android \
    DISPLAY=:1

RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-17-jdk \
    ca-certificates curl unzip wget \
    bash coreutils procps util-linux \
    xvfb x11vnc \
    novnc websockify \
    scrcpy \
    libstdc++6 libpulse0 libnss3 libx11-6 libxcb1 \
    libxcomposite1 libxcursor1 libxi6 libxtst6 \
    libxrandr2 libxrender1 libxdamage1 libxfixes3 \
    libxkbcommon0 libasound2 libgl1 libegl1 \
    libfontconfig1 libdbus-1-3 \
    python3 \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid 109 kvm \
    && groupadd --gid 1000 android \
    && useradd --uid 1000 --gid 1000 --create-home android \
    && usermod -aG kvm android \
    && mkdir -p /opt/android-sdk/cmdline-tools \
    && mkdir -p /home/android/.android \
    && chown -R android:android /home/android

RUN cd /tmp \
    && wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O tools.zip \
    && mkdir -p /opt/android-sdk/cmdline-tools/latest \
    && unzip -q tools.zip -d /tmp/android-tools \
    && mv /tmp/android-tools/cmdline-tools/* /opt/android-sdk/cmdline-tools/latest/ \
    && rm -rf tools.zip /tmp/android-tools \
    && yes | /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager --sdk_root=/opt/android-sdk --licenses >/dev/null \
    && /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager --sdk_root=/opt/android-sdk \
       "platform-tools" \
       "platforms;android-30" \
       "emulator" \
       "system-images;android-30;google_apis_playstore;x86_64" \
    && mv /opt/android-sdk/emulator /opt/android-sdk/emulator_original \
    && wget -q https://dl.google.com/android/repository/emulator-linux_x64-13823996.zip -O /tmp/emulator.zip \
    && unzip -q /tmp/emulator.zip -d /opt/android-sdk \
    && cp /opt/android-sdk/emulator_original/package.xml /opt/android-sdk/emulator/package.xml \
    && python3 -c 'import re; p="/opt/android-sdk/emulator/package.xml"; s=open(p).read(); s,n=re.subn(r"<revision>\s*<major>\d+</major>\s*<minor>\d+</minor>\s*<micro>\d+</micro>\s*</revision>", "<revision><major>36</major><minor>1</minor><micro>9</micro></revision>", s, count=1, flags=re.S); assert n == 1, "Could not pin emulator revision"; open(p,"w").write(s)' \
    && /opt/android-sdk/emulator/emulator -version 2>&1 | grep -F '36.1.9.0 (build_id 13823996)' \
    && rm -rf /opt/android-sdk/emulator_original /tmp/emulator.zip \
    && chown -R android:android /opt/android-sdk

COPY emulator/start-android.sh /usr/local/bin/start-android.sh

RUN chmod +x /usr/local/bin/start-android.sh

EXPOSE 6080 5900

CMD ["/usr/local/bin/start-android.sh"]
