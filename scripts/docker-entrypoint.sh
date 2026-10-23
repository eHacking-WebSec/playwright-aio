#!/bin/bash
set -euo pipefail

: "${DISPLAY:=:99}"
: "${RESOLUTION:=1920x1080x24}"
: "${VNC_PORT:=5900}"
: "${NOVNC_PORT:=6080}"

declare -a PIDS=()

log() { echo "[entrypoint] $*"; }

cleanup() {
    log "shutting down..."
    for pid in "${PIDS[@]:-}"; do
        kill -TERM "$pid" 2>/dev/null || true
    done
    sleep 1
    for pid in "${PIDS[@]:-}"; do
        kill -KILL "$pid" 2>/dev/null || true
    done
    exit 0
}
trap cleanup SIGTERM SIGINT

start_service() {
    local name="$1"; shift
    log "starting $name"
    "$@" > >(sed -u "s/^/[$name] /") 2>&1 &
    PIDS+=($!)
}

wait_for_display() {
    for _ in $(seq 1 50); do
        xdpyinfo -display "$DISPLAY" >/dev/null 2>&1 && return 0
        sleep 0.1
    done
    log "ERROR: Xvfb did not become ready on $DISPLAY"
    exit 1
}

wait_for_port() {
    local port="$1"
    for _ in $(seq 1 50); do
        (exec 3<>/dev/tcp/127.0.0.1/"$port") 2>/dev/null && { exec 3<&- 3>&-; return 0; }
        sleep 0.1
    done
    log "ERROR: port $port not listening"
    exit 1
}

start_service xvfb \
    Xvfb "$DISPLAY" -screen 0 "$RESOLUTION" -ac -nolisten tcp -noreset
wait_for_display

start_service fluxbox fluxbox

start_service x11vnc \
    x11vnc -display "$DISPLAY" -nopw -listen 0.0.0.0 -xkb -forever -shared \
        -rfbport "$VNC_PORT" -repeat -nowcr -nowf -noxdamage
wait_for_port "$VNC_PORT"

start_service novnc \
    /opt/novnc/utils/novnc_proxy --vnc "0.0.0.0:$VNC_PORT" --listen "$NOVNC_PORT"
wait_for_port "$NOVNC_PORT"

log "starting Flask web app"
cd /app
python3 app.py > >(sed -u 's/^/[flask] /') 2>&1 &
FLASK_PID=$!
PIDS+=($FLASK_PID)

wait $FLASK_PID
