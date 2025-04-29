#!/bin/bash
NAME="KP"
TmpDir=/tmp/GenTargets
TDir="${TmpDir}/Targets"
MDir="messages/"
TARGETS_SIZE="50"
SLEEP_TIME=0.5
RETRY_NUM=5
PING_DIR=/tmp/ping
PING_LOG="${PING_DIR}/ping.log"
MESSAGES_DIR=messages/
DETECTED_TARGETS='temp/detected_targets.txt'
DB="db/vko.db"

declare -A targets

password="KR_VKO"

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
  echo "${encrypted_data}" | base64 -d | openssl enc -d -aes-256-cbc \
    -salt -pbkdf2 -iter 100000 \
    -pass "pass:${password}"
}

init_db() {
  rm -f "$D"
	sqlite3 "$DB" < db/init.sql
}

ping_vko() {
  vko_list="ZRDN_1 ZRDN_2 ZRDN_3 RLS_1 RLS_2 RLS_3 SPRO"
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
        echo "${NAME}:  Ping... ${object}(${retry})" >> "${PING_LOG}"
        echo $((retry + 1)) > "${ping_file}"
      fi
    fi
  done
}


while true; do

  last_messages=$(ls ${MDir} -t | head -n ${TARGETS_SIZE} | tr ' ' '\n')
  
  for message_file in ${last_messages}; do
    message_file="${MESSAGES_DIR}/${message_file}"
    system_element=$(echo ${message_file} | cut -d'_' -f2)
    message=$(cat ${message_file})
    decrypted_message=$(decrypt_message "${message}")
    if [[ decrypted_message =~ 'Обнаружена цель' ]]; then
      local decrypted_content="$1"
      local file="$2"

      timestamp=$(echo "$decrypted_content" | cut -d' ' -f1)
      system_id=$(echo "$decrypted_content" | cut -d' ' -f2)
      target_id=$(echo "$decrypted_content" | cut -d' ' -f3)
      x=$(echo "$decrypted_content" | cut -d' ' -f5 | cut -d':' -f2)
      y=$(echo "$decrypted_content" | cut -d' ' -f6 | cut -d':' -f2)
      speed=$(echo "$decrypted_content" | cut -d' ' -f7)
      target_type=$(echo "$decrypted_content" | cut -d' ' -f8-)

      echo "$timestamp $system_id $target_id $x $y $speed $target_type"

      if [[ "$target_type" == "Бал.Блок" ]]; then
        target_type="Бал.Блок"
        echo "$timestamp $system_id Обнаружена цель ID:$target_id с координатами X:$x Y:$y, скорость: $speed м/с $target_type" >>"$KP_LOG"
        echo "$timestamp $system_id Цель ID:$target_id движется в сторону СПРО" >>"$KP_LOG"
        else
          echo "$timestamp $system_id Обнаружена цель ID:$target_id с координатами X:$x Y:$y, скорость: $speed м/с $target_type" >>"$KP_LOG"
        fi

        sqlite3 "$DB" "INSERT OR IGNORE INTO targets (id, speed, target_type) VALUES ('$target_id', $speed, '$target_type', $direction);"

        sys_id=$(get_system_id "$system_id")

        sqlite3 "$DB" "INSERT INTO detections (target_id, system_id, x, y, timestamp) VALUES ('$target_id', $sys_id, $x, $y, '$timestamp');"

        rm -f "$file"
      fi
  done

  sleep ${SLEEP_TIME}

done
