#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$0")/.."

IMAGE="kudesnike/android11-googleplay:stable-36.1.9"
CONTAINER="android11-playstore"

case "${1:-}" in
  build)
    docker build -t "$IMAGE" -f emulator/Dockerfile .
    ;;

  run|start)
    if docker container inspect "$CONTAINER" >/dev/null 2>&1; then
      if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER")" = "true" ]; then
        echo "Контейнер уже запущен."
      else
        echo "Запускаю существующий контейнер..."
        docker start "$CONTAINER"
      fi
    else
      docker run -d \
        --name "$CONTAINER" \
        --device /dev/kvm:/dev/kvm \
        --group-add 109 \
        --shm-size=2g \
        -p 6080:6080 \
        "$IMAGE"
    fi
    ;;

  stop)
    docker stop "$CONTAINER"
    ;;

  restart)
    docker restart "$CONTAINER"
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
    echo "Использование: ./emulator/manage-android.sh {build|run|start|stop|restart|status|logs|follow|remove}"
    exit 1
    ;;
esac
