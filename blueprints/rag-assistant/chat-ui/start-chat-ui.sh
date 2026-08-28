#!/bin/sh
set -eu

uvicorn main:app --host 127.0.0.1 --port 8000 &
app_pid=$!

nginx -g 'daemon off;' &
nginx_pid=$!

shutdown() {
    trap - EXIT TERM INT
    kill -TERM "$nginx_pid" "$app_pid" 2>/dev/null || true
    wait "$nginx_pid" 2>/dev/null || true
    wait "$app_pid" 2>/dev/null || true
}

trap shutdown EXIT TERM INT

while kill -0 "$app_pid" 2>/dev/null && kill -0 "$nginx_pid" 2>/dev/null; do
    sleep 1
done

exit 1
