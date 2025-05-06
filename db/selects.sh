#!/bin/bash

DB="$1"
COMMAND="$2"
shift 2

case "$COMMAND" in
    hits)
        sqlite3 -header -column "$DB" "
        SELECT 
            system_ref AS 'Станция',
            SUM(CASE WHEN is_hit = 1 THEN 1 ELSE 0 END) AS 'Попадания',
            SUM(CASE WHEN is_hit = 0 THEN 1 ELSE 0 END) AS 'Промахи',
            COUNT(*) AS 'Всего выстрелов'
        FROM unified_system
        WHERE entity_type = 'shoot' AND is_hit IS NOT NULL
        GROUP BY system_ref
        ORDER BY system_ref;"
        ;;

    kills)
        sqlite3 -header -column "$DB" "
        SELECT 
            system_ref AS 'Станция',
            COUNT(*) AS 'Уничтожения'
        FROM unified_system
        WHERE entity_type = 'shoot' AND is_hit = 1
        GROUP BY system_ref
        ORDER BY COUNT(*) DESC;"
        ;;

    accuracy)
        sqlite3 -header -column "$DB" "
        SELECT
            system_ref AS 'Станция',
            ROUND(100.0 * SUM(CASE WHEN is_hit = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS 'Меткость (%)',
            COUNT(*) AS 'Всего выстрелов'
        FROM unified_system
        WHERE entity_type = 'shoot' AND is_hit IS NOT NULL
        GROUP BY system_ref
        HAVING COUNT(*) > 0
        ORDER BY 'Меткость (%)' DESC;"
        ;;


    kills_interval)
        if [[ $# -ne 2 ]]; then
            echo "Для команды kills_interval укажите два параметра: start_time end_time"
            echo "Пример: $0 $DB kills_interval '02:28:00' '02:29:00'"
            exit 1
        fi
        START_TIME="$1"
        END_TIME="$2"
        sqlite3 -header -column "$DB" "
        SELECT 
            system_ref AS 'Станция',
            COUNT(*) AS 'Сбито целей'
        FROM unified_system
        WHERE entity_type = 'shoot' 
          AND is_hit = 1
          AND timestamp BETWEEN '$START_TIME' AND '$END_TIME'
        GROUP BY system_ref
        ORDER BY COUNT(*) DESC;"
        ;;

    *)
        echo "Неизвестная команда: $COMMAND"
        exit 1
        ;;
esac
