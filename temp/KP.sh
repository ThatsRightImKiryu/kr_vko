
for message_file in ${last_messages[@]}; do
    message_file="${MESSAGES_DIR}/${message_file}"
    system_element=$(echo ${message_file} | cut -d'_' -f2)
    message=$(cat ${message_file})
    decrypted_message=$(decrypt_message "${message}")
    if [[ "${decrypted_message}" =~ .*"Обнаружена цель".* ]]; then

      timestamp=$(echo "$decrypted_message" | cut -d' ' -f1)
      system_id=$(echo "$decrypted_message" | cut -d' ' -f2)
      target_id=$(echo "$decrypted_message" | cut -d' ' -f6)
      x=$(echo "$decrypted_message" | cut -d' ' -f10)
      y=$(echo "$decrypted_message" | cut -d' ' -f12)
      speed=$(echo "$decrypted_message" | cut -d' ' -f14)
      target_type=$(echo "$decrypted_message" | cut -d' ' -f15)

      echo "${timestamp} ${system_id} ${target_id} $x $y ${speed} ${target_type}"

      if [[ "${decrypted_message}" =~ .*"движется в сторону СПРО" ]]; then
          echo "${timestamp} ${system_id} Цель ID: ${target_id} движется в сторону СПРО" >>"${LOG_FILE}"
      else
          echo "${timestamp} ${system_id} Обнаружена цель ID: ${target_id} с координатами X: $x Y: $y, скорость: ${speed} ${target_type}" >>"${LOG_FILE}"
      fi

      sqlite3 "$DB" "INSERT OR IGNORE INTO unified_system 
          (entity_type, original_id, speed, target_type) 
          VALUES ('target', '${target_id}', ${speed}, '${target_type}');"

      target_ref=$(sqlite3 "$DB" "SELECT id FROM unified_system 
          WHERE entity_type='target' AND original_id='${target_id}' 
          LIMIT 1;")

      sqlite3 "$DB" "INSERT INTO unified_system 
          (entity_type, system_ref, target_ref, x, y, timestamp) 
          VALUES ('detection', '${system_id}', '${target_ref}', $x, $y, '${timestamp}');"

      rm -f ${message_file}
    fi
  done