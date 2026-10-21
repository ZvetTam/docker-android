#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$0")/.."

IMAGE="kudesnike/android11-googleplay:stable-36.1.9"
CONTAINER="android11-playstore"

show_logs() {
    echo "[INFO] Recent container logs:"
    docker logs --tail 80 "$CONTAINER" 2>&1 || true
}

wait_for_android() {
    echo "[INFO] Waiting for Android and noVNC..."

    for _ in $(seq 1 370); do
        if ! docker container inspect "$CONTAINER" >/dev/null 2>&1; then
            echo "[ERROR] Android container no longer exists."
            return 1
        fi

        if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER")" != "true" ]; then
            echo "[ERROR] Android container stopped during startup."
            show_logs
            return 1
        fi

        BOOT_STATE="$(
            docker exec "$CONTAINER" \
                /opt/android-sdk/platform-tools/adb shell getprop sys.boot_completed \
                2>/dev/null | tr -d '\r' || true
        )"

        if [ "$BOOT_STATE" = "1" ] &&
           curl -fsS --max-time 2 http://127.0.0.1:6080/ >/dev/null 2>&1; then
            echo "[OK] Android has booted."
            echo "[OK] noVNC responds on port 6080."
            echo "[INFO] Open forwarded port 6080 in Codespaces."
            return 0
        fi

        sleep 1
    done

    echo "[ERROR] Android or noVNC did not become ready in time."
    show_logs
    return 1
}

start_container() {
    if docker container inspect "$CONTAINER" >/dev/null 2>&1; then
        if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER")" != "true" ]; then
            echo "[INFO] Starting existing Android container..."
            docker start "$CONTAINER" >/dev/null
        else
            echo "[INFO] Android container is already running."
        fi
    else
        echo "[INFO] Creating Android container from pinned image..."

        docker run -d \
            --name "$CONTAINER" \
            --device /dev/kvm:/dev/kvm \
            --group-add 109 \
            --shm-size=2g \
            -p 6080:6080 \
            "$IMAGE"
    fi

    wait_for_android
}

case "${1:-}" in
    build)
        docker build -t "$IMAGE" -f emulator/Dockerfile .
        ;;

    run|start)
        start_container
        ;;

    stop)
        docker stop "$CONTAINER"
        ;;

    restart)
        if docker container inspect "$CONTAINER" >/dev/null 2>&1; then
            docker restart "$CONTAINER" >/dev/null
            wait_for_android
        else
            start_container
        fi
        ;;

    status)
        docker ps -a --filter "name=^/${CONTAINER}$"
        ;;

    logs)
        docker logs --tail 80 "$CONTAINER"
        ;;

    follow)
        docker logs -f "$CONTAINER"
        ;;

    remove)
        docker rm "$CONTAINER"
        ;;

    *)
        echo "Usage: ./emulator/manage-android.sh {build|run|start|stop|restart|status|logs|follow|remove}"
        exit 1
        ;;
esac
