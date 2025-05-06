#!/bin/bash
NAME="KP"
TmpDir=/tmp/GenTargets
TDir="${TmpDir}/Targets"
TARGETS_SIZE="50"
SLEEP_TIME=0.5
RETRY_NUM=5
PING_DIR=ping/
LOGS_DIR=logs/
PING_LOG="${LOGS_DIR}/ping.log"
MESSAGES_DIR=messages
SHOT_DIR=${MESSAGES_DIR}/shot
DETECT_DIR=${MESSAGES_DIR}/detect
MISSILE_DIR=${MESSAGES_DIR}/missile
DETECTED_TARGETS='temp/detected_targets.txt'
DB="db/vko.db"
LOG_FILE=logs/KP.log

mkdir -p ${PING_DIR}
rm -rf ${LOGS_DIR}/* ${PING_DIR}/*

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

rm -f ${DB}
sqlite3 -init db/init.sql ${DB} .quit
if [ $? -ne 0 ]; then
  echo "Ошибка при инициализации базы данных!" >&2
  exit 1
fi

ping_vko() {
  vko_list="ZRDN_1 ZRDN_2 ZRDN_3 RLS_1 RLS_2 RLS_3 SPRO_1 "
  > ${PING_LOG}
  for object in ${vko_list}; do
    ping_file="${PING_DIR}/PING_${object}"
    pong_file="${PING_DIR}/PONG_${object}"

    if [[ -f "${pong_file}" ]]; then
      echo "$(date '+%H:%M:%S.%3N')  ${NAME}: Pong! ${object} is alive" >> "${PING_LOG}"
      rm "${pong_file}"
      rm "${ping_file}"
    else
      [[ -f "${ping_file}" ]] && retry=$(cat "${ping_file}") || retry=1
      if (( retry > RETRY_NUM )); then
        echo "$(date '+%H:%M:%S.%3N')  ${NAME}: ${object} is DEAD" >> "${PING_LOG}"
        rm "${ping_file}"
      else
        echo "$(date '+%H:%M:%S.%3N')  ${NAME}:  Ping... ${object}(${retry})" >> "${PING_LOG}"
        echo $((retry + 1)) > "${ping_file}"
      fi
    fi
  done
}


while true; do
  set +x
  ping_vko &
  last_messages=$(find ${MESSAGES_DIR}/ -type f -printf "%T@ %p\n" | sort -n | cut -d' ' -f2-)
  
  for message_file in ${last_messages[@]}; do
    message=$(cat "${message_file}")
    decrypted_message=$(decrypt_message "${message}")
    timestamp=$(echo "${decrypted_message}" | cut -d' ' -f1)
    system_element=$(echo "$decrypted_message" | cut -d' ' -f2)
    message_type=$(echo "$decrypted_message" | cut -d' ' -f3)
    target_id=$(echo "$decrypted_message" | cut -d' ' -f4)

    # Получаем ID system_element из БД

    if [[ "${message_file}" == "${MISSILE_DIR}/"* ]]; then
      if [[ "${message_type}" -eq 0 ]]; then
        echo "${timestamp} ${system_element} Закончился боезапас" >> "${LOG_FILE}"
        # Обновляем боезапас в БД
        sqlite3 "${DB}" "UPDATE unified_system SET ammo = 0 WHERE id = ${system_element}" &
      elif [[ "${message_type}" -eq 1 ]]; then
        missiles=$(echo "$decrypted_message" | cut -d' ' -f4)
        echo "${timestamp} ${system_element} Восполнен боезапас до ${missiles} ракет" >> "${LOG_FILE}"
        # Обновляем боезапас в БД
        sqlite3 "${DB}" "UPDATE unified_system SET ammo = ${missiles} WHERE id = '${system_element}'" &
      fi
    fi

    if [[ "${message_file}" == "${SHOT_DIR}/"* ]]; then
      # Получаем ID цели из БД
      
      if [[ "${message_type}" -eq 0 ]]; then
        echo "${timestamp} ${system_element} Выстрел по цели ID: '${target_id}'" >> "${LOG_FILE}"
        # Вставляем запись о выстреле
        sqlite3 "${DB}" "INSERT INTO unified_system (entity_type, timestamp, system_ref, target_ref) VALUES ('shoot', '${timestamp}', '${system_element}', '${target_id}')" &
      elif [[ "${message_type}" -eq 1 ]]; then
        echo "${timestamp} ${system_element} Промах по цели ID: '${target_id}'" >> "${LOG_FILE}"
        # Вставляем запись о промахе
        sqlite3 "${DB}" "INSERT INTO unified_system (entity_type, timestamp, system_ref, target_ref, is_hit) VALUES ('shoot', '${timestamp}', '${system_element}', '${target_id}', 0)" &
      else
        echo "${timestamp} ${system_element} Цель ID: '${target_id}' уничтожена" >> "${LOG_FILE}"
        # Вставляем запись о попадании
        sqlite3 "${DB}" "INSERT INTO unified_system (entity_type, timestamp, system_ref, target_ref, is_hit) VALUES ('shoot', '${timestamp}', '${system_element}', '${target_id}', 1)" &
      fi
    fi

    if [[ "${message_file}" == "${DETECT_DIR}/"* ]]; then
      x=$(echo "$decrypted_message" | cut -d' ' -f5)
      y=$(echo "$decrypted_message" | cut -d' ' -f6)
      speed=$(echo "$decrypted_message" | cut -d' ' -f7)
      target_type=$(echo "$decrypted_message" | cut -d' ' -f8)

      if [[ "${message_type}" -eq 1 ]]; then
        echo "${timestamp} ${system_element} Цель ID: ${target_id} движется в сторону СПРО" >> "${LOG_FILE}"
        
        # Проверяем, существует ли уже цель
        existing_target=$(sqlite3 "${DB}" "SELECT id FROM unified_system WHERE original_id = '${target_id}' AND entity_type = 'target'") &
        
        if [[ -z "$existing_target" ]]; then
          # Вставляем новую цель
          sqlite3 "${DB}" "INSERT INTO unified_system (entity_type, original_id, timestamp, speed, target_type, x, y) VALUES ('target', '${target_id}', '${timestamp}', ${speed}, '${target_type}', ${x}, ${y})" &
        else
          # Обновляем существующую цель
          sqlite3 "${DB}" "UPDATE unified_system SET timestamp = '${timestamp}', speed = ${speed}, x = ${x}, y = ${y} WHERE id = ${existing_target}" &
        fi
        
        # Вставляем запись о детекции
        sqlite3 "${DB}" "INSERT INTO unified_system (entity_type, timestamp, system_ref, target_ref, x, y) VALUES ('detection', '${timestamp}', '${system_element}', '${existing_target:-NULL}', ${x}, ${y})" &
      fi
    fi

    rm -f "${message_file}"
  done

  sleep ${SLEEP_TIME}
done


# https://docs.google.com/document/d/1BwKeHFfpaDEza1Emyik6kv2X0vijvGyxFSpjyBHYw-U/edit?usp=sharing