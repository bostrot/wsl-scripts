#!/bin/bash
# Runs one service script and checks its container and ports.
set -u
name="$1"
dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$dir/scripts/$name/script.noshell"
[ -f "$script" ] || { echo "no such script: $name"; exit 1; }

container=$(grep -oE -- '--name +wslm-[a-z0-9-]+' "$script" | head -1 | awk '{print $2}')
ports=$(grep -oE -- '-p +[0-9]+:[0-9]+' "$script" | awk '{print $2}' | cut -d: -f1)
[ -n "$container" ] || { echo "$name is not a Docker service script"; exit 1; }

echo "== running $name (container $container, host ports: $(echo $ports | tr '\n' ' '))"
if ! sudo sh "$script"; then
    echo "script exited non-zero"
    exit 1
fi

sleep 10
if [ -z "$(sudo docker ps -q -f name="^${container}$" -f status=running)" ]; then
    echo "FAIL: container $container is not running"
    sudo docker logs "$container" 2>&1 | tail -40
    exit 1
fi

for port in $ports; do
    ok=""
    for _ in $(seq 1 45); do
        if (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
            exec 3>&- 3<&-
            ok=1
            break
        fi
        sleep 2
    done
    if [ -z "$ok" ]; then
        echo "FAIL: port $port never accepted a connection"
        sudo docker logs "$container" 2>&1 | tail -40
        exit 1
    fi
    echo "port $port: accepting connections"
done

echo "== $name works"
sudo docker rm -f "$container" >/dev/null 2>&1
exit 0
