#!/bin/bash
PING_DIR=/tmp/ping
PING_LOG="${PING_DIR}/ping.log"
NAME=RLS_1
SLEEP_TIME=0.5

while true; do
  if [[ -f "${PING_DIR}/PING_${NAME}" ]]; then
    echo "${NAME}: Recieved ping from KP! Send pong" >> "${PING_LOG}"
    touch "$PING_DIR/PONG_${NAME}"
    rm "$PING_DIR/PING_${NAME}"
  fi
  sleep ${SLEEP_TIME}
done
