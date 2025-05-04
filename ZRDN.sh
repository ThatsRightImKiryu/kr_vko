#!/bin/bash
NAME="ZRDN_$1"
ZRDN_X=$2
ZRDN_Y=$3
ZRDN_RADIUS=$4
TmpDir=/tmp/GenTargets
TDir="${TmpDir}/Targets"
DDir="${TmpDir}/Destroy"
TARGETS_SIZE=50
MISSILES=2
RELOAD_TIME=5
MISS_TIMEOUT=5
EMPTY_MISSILE_TIME=''

SLEEP_TIME=0.5
PING_DIR=ping/
PING_LOG="${PING_DIR}/ping.log"
MESSAGES_DIR=messages
SHOT_DIR=${MESSAGES_DIR}/shot
DETECT_DIR=${MESSAGES_DIR}/detect
MISSILE_DIR=${MESSAGES_DIR}/missile
LOGS_DIR=logs/
LOGS_FILE="${LOGS_DIR}/${NAME}.log"

rm -rf ${MESSAGES_DIR}/*/* ${LOGS_DIR}/*
mkdir -p ${PING_DIR} ${SHOT_DIR} ${DETECT_DIR} ${MISSILE_DIR}
DETECTED_TARGETS='temp/ZRDN_detected_targets.txt'
> "${DETECTED_TARGETS}"

password="KR_VKO"

declare -A targets
declare -A shot_targets

ping_kp() {
  if [[ -f "${PING_DIR}/PING_${NAME}" ]]; then
    touch "${PING_DIR}/PONG_${NAME}"
  fi
}

encrypt_message() {
  dir=$1
  data=$2
  message=$(echo -n "${data}" | openssl enc -aes-256-cbc \
    -salt -pbkdf2 -iter 100000 \
    -pass "pass:${password}" | base64 -w 0)
  echo $(create_random_file ${dir} ${message})
}

decrypt_message() {
  encrypted_data="$1"
  echo -n "${encrypted_data}" | base64 -d | openssl enc -d -aes-256-cbc \
    -salt -pbkdf2 -iter 100000 \
    -pass "pass:${password}"
}

create_random_file() {
  dir=$1
  data=$2
  file="${dir}/$(mktemp -u ${NAME}_XXXXX)"
  echo "${data}" > "${file}"
  # echo "${file}"
}

print_all() {
  dir=$1
  logfile=${LOGS_FILE}
  data=$2
  echo "${data}" | tee -a ${logfile}
  encrypt_message ${dir} "${data}"
}


decode_target_filename() {
  filename="$1"
  filepath="${TDir}/${filename}"

  if [[ ! -f "${filepath}" ]]; then
    echo "Ошибка: файл ${filename} не найден в ${TDir}" >&2
    return 1
  fi

  trimmed=${filename:0:-2}
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
	speed=$1
	if (($(echo "${speed} >= 8000" | bc -l))); then
		echo "Бал.блок"
	elif (($(echo "${speed} >= 250" | bc -l))); then
		echo "Ракета"
	else
		echo "Самолет"
	fi
}

calculate_distance() {
  x1=$1
  y1=$2
  x2=$3
  y2=$4

  dx=$(echo "$x2 - $x1" | bc -l)
  dy=$(echo "$y2 - $y1" | bc -l)
  distance=$(echo "scale=5; sqrt(${dx}^2 + ${dy}^2)" | bc -l)

  echo ${distance}
}

while true; do
  ping_kp

  if ((MISSILES == 0)); then
    current_time=$(date +%s)
    if ((current_time - EMPTY_MISSILE_TIME >= RELOAD_TIME)); then
      MISSILES=20
      print_all "${MISSILE_DIR}" "$(date '+%H:%M:%S.%3N') ${NAME} 1"
      echo "$(date '+%H:%M:%S.%3N') ${NAME} Боекомплект восполнен до ${MISSILES} противоракет"
    fi
  fi

  print_all "${MISSILE_DIR}" "$(date '+%H:%M:%S.%3N') ${NAME} 2 ${MISSILES}"

  > "${DETECTED_TARGETS}"

  last_targets=$(ls ${TDir} -t | head -n ${TARGETS_SIZE} | tr ' ' '\n')
  
  for target in ${last_targets}; do
    if [[ ${#target} -le 2 ]]; then
      echo "$target" >>"${DETECTED_TARGETS}"
      continue
    fi

    decoded_target_filename=$(decode_target_filename "${target}")
    target_id=$(echo "${decoded_target_filename}" | cut -d' ' -f1)
    x=$(echo "${decoded_target_filename}" | cut -d' ' -f2)
    y=$(echo "${decoded_target_filename}" | cut -d' ' -f3)
    distance_to_target=$(calculate_distance "$x" "$y" "${ZRDN_X}" "${ZRDN_Y}")

    grep -q "${target_id}" "${DETECTED_TARGETS}" && continue
    echo "${target_id}" >>"${DETECTED_TARGETS}"

    if (( $(echo "${distance_to_target} <= ${ZRDN_RADIUS}" | bc -l) )); then
      if [[ -n ${targets["${target_id}"]} ]]; then
        prev_x=$(echo "${targets[${target_id}]}" | cut -d' ' -f1)
        prev_y=$(echo "${targets[${target_id}]}" | cut -d' ' -f2)

        speed=$(calculate_distance "${prev_x}" "${prev_y}" "$x" "$y")
        type=$(fix_target_type ${speed})
        if [[ ${type} == "Ракета" ]] || [[ ${type} == "Самолет" ]]; then
          if [ -n "${shot_targets[${target_id}]}" ]; then
            is_missed=$(( $(date "+%s") - "${shot_targets[${target_id}]}" >= "${MISS_TIMEOUT}" ))
            if [[ -n "${is_missed}" ]]; then
              print_all "${SHOT_DIR}" "$(date '+%H:%M:%S.%3N') ${NAME} 1 ${target_id}"
              unset shot_targets["${target_id}"]}
            fi
          else
            print_all "${DETECT_DIR}" "$(date '+%H:%M:%S.%3N') ${NAME} 0 ${target_id} $x $y ${speed} ${type}"
          fi
          if ((MISSILES > 0)); then
            if [[ -z "${shot_targets["${target_id}"]}" ]] || [[ -n "${is_missed}" ]]; then
              ((MISSILES--))
              print_all "${SHOT_DIR}" "$(date '+%H:%M:%S.%3N') ${NAME} 0 ${target_id}"
              echo "${NAME}" > "${DDir}/${target_id}"

              shot_targets["${target_id}"]=$(date +%s)
              if ((MISSILES == 0)); then
                EMPTY_MISSILE_TIME=$(date +%s)
                echo "$(date '+%H:%M:%S.%3N') ${NAME} Боекомплект закончился. Нет противоракет для перехвата цели ID: ${target_id}"
                print_all "${MISSILE_DIR}" "$(date '+%H:%M:%S.%3N') ${NAME} 0"
              fi
            fi
          fi

        fi
      fi

      targets["${target_id}"]="$x $y"
    fi
  done

  for target_id in ${!targets[@]}; do
    if ! grep -q "${target_id}" "${DETECTED_TARGETS}" && [ -n "${shot_targets[${target_id}]}" ]; then
      print_all "${SHOT_DIR}" "$(date '+%H:%M:%S.%3N') ${NAME} 2 ${target_id}"
      unset shot_targets["${target_id}"]
    fi
  done

  sleep ${SLEEP_TIME}

done

# DETECT 0 - обнаружена, 1 - движется в сторону ПРО
# SHOT 0 - выстрел, 1 - промах, 2 - уничтожена
# MISSILE 0 - боезопас кончился, 1 - боезопас восставнолен, 2 - текущий боезапас
