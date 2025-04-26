#!/bin/bash
NAME="RLS_$1"
TmpDir=/tmp/GenTargets
TDir="$TmpDir/Targets"
TARGETS_SIZE="50"
SLEEP_TIME=0.5
RETRY_NUM=5
PING_DIR=/tmp/ping
PING_LOG="$PING_DIR/ping.log"

RLS_X=$2
RLS_Y=$3
RLS_RADIUS=$4
RLS_ALPHA=$5
RLS_ANGLE=$6

declare -A targets

# echo '' > detected_targets_1.txt
echo '' > detected_targets_2.txt


decode_target_filename() {
  filename="$1"
  filepath="${TDir}/$filename"

  if [[ ! -f "$filepath" ]]; then
      echo "Error: file $filename is not fiund $TDir" >&2
      return 1
  fi

  trimmed=${filename:0:-2}  # Without r
  hex_h=""

  for ((i=2; i<${#trimmed}; i+=4)); do
    hex_h+=${trimmed:$i:2}
  done
  decoded_h=$(echo -n "${hex_h}" | xxd -r -p)

  coords=($(grep -oP 'X:\s*\K\d+|Y:\s*\K\d+' "$filepath"))
  x="${coords[0]:-0}"
  y="${coords[1]:-0}"

  echo "${decoded_h} $x $y"
}

fix_target_type() {
	local speed=$1
	if (($(echo "$speed >= 8000" | bc -l))); then
		echo "ББ БР"
	elif (($(echo "$speed >= 250" | bc -l))); then
		echo "Крылатая ракета"
	else
		echo "Самолет"
	fi
}

calculate_distance() {
    x1=$1
    y1=$2
    x2=$3
    y2=$4

    # Вычисление разницы по x и y
    dx=$(echo "$x2 - $x1" | bc -l)
    dy=$(echo "$y2 - $y1" | bc -l)

    # Используем bc для вычисления расстояния
    distance=$(echo "scale=5; sqrt($dx^2 + $dy^2)" | bc -l)

    echo ${distance}
}

ping_vko() {
  # vko_list="ZRDN_1 ZRDN_2 ZRDN_3 RLS_1 RLS_2 RLS_3 SPRO"
  vko_list="RLS_1"
  for object in ${vko_list}; do
    ping_file="${PING_DIR}/PING_${object}"
    pong_file="${PING_DIR}/PONG_${object}"

    if [[ -f "${pong_file}" ]]; then
      echo "${NAME}: Pong! ${object} is alive" >> "${PING_LOG}"
      rm "${pong_file}"
    else
      [[ -f "${ping_file}" ]] && retry=$(cat "${ping_file}") || retry=1
      if (( retry > RETRY_NUM )); then
        echo "${NAME}: ${object} is DEAD" >> "${PING_LOG}"
        rm "${ping_file}"
      else
        echo "${NAME}:  Ping... ${object}($retry)" >> "${PING_LOG}"
        echo $((retry + 1)) > "${ping_file}"
      fi
    fi
  done
}

while true; do
  ping_vko

  mapfile -t last_targets < <(ls ${TDir} -t | head -n ${TARGETS_SIZE} | tr ' ' '\n')
  
  for target in ${last_targets}; do
    decoded_target_filename=$(decode_target_filename "${target}")
    target_id=$(echo "${decoded_target_filename}" | cut -d' ' -f1)
    x=$(echo "${decoded_target_filename}" | cut -d' ' -f2)
    y=$(echo "${decoded_target_filename}" | cut -d' ' -f3)

    if [[ -n ${targets[${target_id}]} ]]; then
      prev_x=$(echo "${targets[${target_id}]}" | cut -d' ' -f1)
      prev_y=$(echo "${targets[${target_id}]}" | cut -d' ' -f2)
      speed=$(calculate_distance "$prev_x" "$prev_y" "$x" "$y")
      type=$(fix_target_type ${speed})
      echo ${type} $x $y ${speed}
    fi
    targets["${target_id}"]="$x $y"
  done
  sleep ${SLEEP_TIME}
  # break
done
