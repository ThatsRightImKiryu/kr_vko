#!/bin/bash
NAME="SPRO_$1"
SPRO_X=$2
SPRO_Y=$3
SPRO_RADIUS=$4
TmpDir=/tmp/GenTargets
TDir="${TmpDir}/Targets"
DDir="${TmpDir}/Destroy"
TARGETS_SIZE=50
MISSILES=10
RELOAD_TIME=5 #sec
EMPTY_AMMO_TIME=''

SLEEP_TIME=0.5
RETRY_NUM=5
PING_DIR=/tmp/ping
PING_LOG="${PING_DIR}/ping.log"
DETECTED_TARGETS='temp/spro_detected_targets.txt'
> "${DETECTED_TARGETS}"

declare -A targets
declare -A shot_targets

decode_target_filename() {
  filename="$1"
  filepath="${TDir}/${filename}"

  if [[ ! -f "${filepath}" ]]; then
    echo "Ошибка: файл ${filename} не найден в ${TDir}" >&2
    return 1
  fi

  trimmed=${filename:0:-2}  # Without r
  hex_h=""

  for ((i=2; i<${#trimmed}; i+=4)); do
    hex_h+=${trimmed:${i}:2}
  done
  decoded_h=$(echo -n "${hex_h}" | xxd -r -p)

  coords=($(grep -oP 'X:\s*\K\d+|Y:\s*\K\d+' "${filepath}"))
  x="${coords[0]:-0}"
  y="${coords[1]:-0}"

  echo "${decoded_h} $x $y"
}

fix_target_type() {
	yspeed=$1
	if (($(echo "${speed} >= 8000" | bc -l))); then
		echo "Бал.блок"
	elif (($(echo "${speed} >= 250" | bc -l))); then
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
  distance=$(echo "scale=5; sqrt(${dx}^2 + ${dy}^2)" | bc -l)

  echo ${distance}
}

while true; do
  if ((MISSILES == 0)); then
    current_time=$(date +%s)
    if ((current_time - EMPTY_AMMO_TIME >= RELOAD_TIME)); then
      MISSILES=20
      echo "$(date +%X) ${NAME} Боекомплект восполнен до ${MISSILES} противоракет"
    fi
  fi
  # ping_vko &
  > "${DETECTED_TARGETS}"

  last_targets=$(ls ${TDir} -t | head -n ${TARGETS_SIZE} | tr ' ' '\n')
  
  for target in ${last_targets}; do
    if [[ ${#target} -le 2 ]]; then # Не обрабатываем поломанные файлы
      echo "$target" >>"${DETECTED_TARGETS}"
      continue
    fi

    decoded_target_filename=$(decode_target_filename "${target}")
    target_id=$(echo "${decoded_target_filename}" | cut -d' ' -f1)
    x=$(echo "${decoded_target_filename}" | cut -d' ' -f2)
    y=$(echo "${decoded_target_filename}" | cut -d' ' -f3)
    distance_to_target=$(calculate_distance "$x" "$y" "${SPRO_X}" "${SPRO_Y}")

    grep -q "${target_id}" "${DETECTED_TARGETS}" && continue
    echo "${target_id}" >>"${DETECTED_TARGETS}"

    if (( $(echo "${distance_to_target} <= ${SPRO_RADIUS}" | bc -l) )); then
      if [[ -n ${targets["${target_id}"]} ]]; then
        prev_x=$(echo "${targets[${target_id}]}" | cut -d' ' -f1)
        prev_y=$(echo "${targets[${target_id}]}" | cut -d' ' -f2)

        speed=$(calculate_distance "${prev_x}" "${prev_y}" "$x" "$y") # Считаем, что за 1с == дистанция
        type=$(fix_target_type ${speed})
        if [[ ${type} == "Бал.блок" ]]; then
          echo "$(date +%X) ${NAME} Обнаружена цель ID:${target_id} с координатами X:$x Y:$y, скорость: ${speed} м/с (${type})"
          if [ -n "${shot_targets[${target_id}]}" ]; then
            echo "$(date +%X) ${NAME} Промах по цели ID:${target_id}"
          fi
          if ((MISSILES > 0)); then
            ((MISSILES--))
              echo "$(date +%X) ${NAME} Выстрел по цели ID:${target_id}. Противоракет осталось ${MISSILES}"
              echo "${NAME}" > "${DDir}/${target_id}"
              # set -x
              shot_targets["${target_id}"]=1
              set +x
            ((MISSILES == 0)) && EMPTY_AMMO_TIME=$(date +%s)
          else
            echo "$(date +%X) ${NAME} Боекомплект закончился. Нет противоракет для перехвата цели ID:${target_id}"
          fi
        fi
      fi

      targets["${target_id}"]="$x $y"
    fi
  done
  # set -x
  for target_id in ${!targets[@]}; do
    if ! grep -q "${target_id}" "${DETECTED_TARGETS}" && [ -n "${shot_targets[${target_id}]}" ]; then
      echo "$(date +%X) ${NAME} Цель ID:${target_id} уничтожена"
      unset shot_targets["${target_id}"]
    fi
  done
  set +x

  sleep ${SLEEP_TIME}
  # break
done
