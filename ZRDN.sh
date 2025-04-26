#!/bin/bash
PING_DIR=/tmp/ping
PING_LOG="${PING_DIR}/ping.log"
TARGETS_SIZE="500"
SLEEP_TIME=0.5
TmpDir=/tmp/GenTargets/Targets

NAME=ZRDN_1
r=600
x0=2900
y0=4300

while true; do
  targets=$(cat detected_targets_2.txt | tr ' ' '\n')
  if [[ -f "${PING_DIR}/PING_${NAME}" ]]; then
    echo "${NAME}: Recieved ping from KP! Send pong" >> "${PING_LOG}"
    touch "$PING_DIR/PONG_${NAME}"
    rm "$PING_DIR/PING_${NAME}"
  fi
  sleep "${SLEEP_TIME}"
  for target in $targets; do
    target_file="${TmpDir}/${target}"
    x1=$(cat "${target_file}" | awk '{print $2}')
    y1=$(cat "${target_file}" | awk '{print $4}')
    dx=$((x1 - x0))
    dy=$((y1 - y0))
    distance_squared=$((dx*dx + dy*dy))
    if (( distance_squared <= radius*radius )); then
        echo "${NAME} detects aim (${x1}, ${y1})"
    fi
  done
done
