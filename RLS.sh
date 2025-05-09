#!/bin/bash
NAME="RLS_$1"
RLS_X=$2
RLS_Y=$3
RLS_RADIUS=$4
RLS_ALPHA=$5
RLS_ANGLE=$6
TmpDir=/tmp/GenTargets
TDir="${TmpDir}/Targets"
TARGETS_SIZE="50"
SLEEP_TIME=0.5
RETRY_NUM=5
PING_DIR=/tmp/ping
PING_LOG="${PING_DIR}/ping.log"
DETECTED_TARGETS='temp/detected_targets.txt'

SPRO_X=2500000
SPRO_Y=3500000
SPRO_RADIUS=1700000

declare -A targets
declare -A detected_first_targets

> "${DETECTED_TARGETS}"

SLEEP_TIME=0.5
PING_DIR=ping/
mkdir -p ${PING_DIR}
PING_LOG="${PING_DIR}/ping.log"
MESSAGES_DIR=messages
SHOT_DIR=${MESSAGES_DIR}/shot
DETECT_DIR=${MESSAGES_DIR}/detect
MISSILE_DIR=${MESSAGES_DIR}/missile
LOGS_DIR=logs/
LOGS_FILE="${LOGS_DIR}/${NAME}.log"

rm -rf ${MESSAGES_DIR}/*/* ${LOGS_DIR}/*
mkdir -p ${PING_DIR} ${SHOT_DIR} ${DETECT_DIR} ${MISSILE_DIR}
DETECTED_TARGETS="temp/${NAME}_detected_targets.txt"
> "${DETECTED_TARGETS}"

password="KR_VKO"

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
		echo "Ракета"
	else
		echo "Самолет"
	fi
}

is_in_radar_beam() {
  x="$1"
  y="$2"

  dx=$((x - RLS_X))
  dy=$((y - RLS_Y))

  angle_to_target=$(echo "a(${dy}/${dx})" | bc -l)

  angle_to_target=$(echo "${angle_to_target} * 180 / 3.1415926535" | bc -l)

  if (( $(echo "${angle_to_target} < 0" | bc -l) )); then
    angle_to_target=$(echo "${angle_to_target} + 360" | bc -l)
  fi

  relative_angle=$(echo "${angle_to_target} - ${RLS_ALPHA}" | bc -l)

  if (( $(echo "${relative_angle} > 180" | bc -l) )); then
    relative_angle=$(echo "${relative_angle} - 360" | bc -l)
  elif (( $(echo "${relative_angle} < -180" | bc -l) )); then
    relative_angle=$(echo "${relative_angle} + 360" | bc -l)
  fi

  if (( $(echo "${relative_angle} >= -(${RLS_ANGLE} / 2)" | bc -l) )) && (( $(echo "${relative_angle} <= (${RLS_ANGLE} / 2)" | bc -l) )); then
    echo true
  else
    echo false
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

is_moving_to_spro() {
  x1=$1 y1=$2 x2=$3 y2=$4

  dx=$((x2 - x1))
  dy=$((y2 - y1))

  # numerator=$(( (dy * (SPRO_X - x1)) - (dx * (SPRO_Y - y1)) ))
  numerator=$(( (dy * SPRO_X) - (dx * SPRO_Y) + (x2 * y1) - (y2 * x1) ))
  numerator=${numerator#-}  # Берем модуль

  denominator=$(echo "scale=10; sqrt($dx * $dx + $dy * $dy)" | bc)

  distance_to_line=$(echo "scale=10; ${numerator} / ${denominator}" | bc)

  distance1=$(calculate_distance "$x1" "$y1" "${SPRO_X}" "${SPRO_Y}")
  distance2=$(calculate_distance "$x2" "$y2" "${SPRO_X}" "${SPRO_Y}")

  if  (( $(echo "${distance_to_line} <= ${SPRO_RADIUS}" | bc -l) )) && (( $(echo "${distance2} < ${distance1}" | bc -l) )); then
      echo true
  else
      echo false
  fi
}

while true; do
	ping_kp
  last_targets=$(ls ${TDir} -t | head -n ${TARGETS_SIZE} | tr ' ' '\n')
  
  for target in ${last_targets}; do
    grep -q "${target}" "${DETECTED_TARGETS}" && continue
    echo "${target}" >>"${DETECTED_TARGETS}"

    decoded_target_filename=$(decode_target_filename "${target}")
    target_id=$(echo "${decoded_target_filename}" | cut -d' ' -f1)
    x=$(echo "${decoded_target_filename}" | cut -d' ' -f2)
    y=$(echo "${decoded_target_filename}" | cut -d' ' -f3)
    distance_to_target=$(calculate_distance "$x" "$y" "${RLS_X}" "${RLS_Y}")

    if (( $(echo "${distance_to_target} <= ${RLS_RADIUS}" | bc -l) )); then
      is_in_radar_beam=$(is_in_radar_beam "$x" "$y" "$RLS_ALPHA" "$RLS_ANGLE")
      if "${is_in_radar_beam}"; then
        if [[ -n "${targets[${target_id}]}" ]]; then
          prev_x=$(echo "${targets[${target_id}]}" | cut -d' ' -f1)
          prev_y=$(echo "${targets[${target_id}]}" | cut -d' ' -f2)

          speed=$(calculate_distance "${prev_x}" "${prev_y}" "$x" "$y") # Count as for 1s == distance
          type=$(fix_target_type ${speed})
          # set -x
          if [[ $type == "Бал.блок" ]] && [[ -z "${detected_first_targets[${target_id}]}" ]]; then
            if $(is_moving_to_spro "${prev_x}" "${prev_y}" "$x" "$y"); then
              print_all "${DETECT_DIR}" "$(date '+%H:%M:%S.%3N') ${NAME} 1 ${target_id} $x $y ${speed} ${type}"
            else
              print_all "${DETECT_DIR}" "$(date '+%H:%M:%S.%3N') ${NAME} 0 ${target_id} $x $y ${speed} ${type}"

            fi
            detected_first_targets["${target_id}"]="$x $y"
          fi
          set +x
        fi
      fi

      targets["${target_id}"]="$x $y"
    fi
  done
  sleep ${SLEEP_TIME}
  done

