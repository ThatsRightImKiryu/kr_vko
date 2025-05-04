#!/bin/bash

# usage: ./stats.sh <db_file> <command> [args...]
# Команды:
#   hits            - Количество попаданий и промахов по каждой станции
#   kills           - Топ станций по количеству уничтожений
#   accuracy        - Топ станций по меткости (процент попаданий)
#   ammo            - Количество боеприпасов у каждой станции
#   kills_interval  - Количество сбитых целей за интервал времени (требует два аргумента: start_time end_time)
#   targets_spro    - Количество целей, направляющихся в сторону СПРО

DB="$1"
COMMAND="$2"
shift 2

if [[ -z "$DB" || -z "$COMMAND" ]]; then
  echo "Использование: $0 <db_file> <command> [args...]"
  echo "Команды:"
  echo "  hits            - Количество попаданий и промахов по каждой станции"
  echo "  kills           - Топ станций по количеству уничтожений"
  echo "  accuracy        - Топ станций по меткости (процент попаданий)"
  echo "  ammo            - Количество боеприпасов у каждой станции"
  echo "  kills_interval  - Количество сбитых целей за интервал времени (требует два аргумента: start_time end_time)"
  echo "  targets_spro    - Цели, направляющиеся в сторону СПРО"
  exit 1
fi

case "$COMMAND" in

  hits)
    sqlite3 -header -column "$DB" "
SELECT 
    s.name AS 'Станция',
    SUM(CASE WHEN sh.is_hit = 1 THEN 1 ELSE 0 END) AS 'Попадания',
    SUM(CASE WHEN sh.is_hit = 0 THEN 1 ELSE 0 END) AS 'Промахи'
FROM unified_system sh
JOIN unified_system s ON sh.system_ref = s.id
WHERE sh.entity_type = 'shoot'
GROUP BY sh.system_ref
HAVING COUNT(*) > 0
ORDER BY s.name;
"
    ;;

  kills)
    sqlite3 -header -column "$DB" "
SELECT 
    s.name AS 'Станция',
    SUM(CASE WHEN sh.is_hit = 1 THEN 1 ELSE 0 END) AS 'Уничтожения'
FROM unified_system sh
JOIN unified_system s ON sh.system_ref = s.id
WHERE sh.entity_type = 'shoot'
GROUP BY sh.system_ref
ORDER BY 'Уничтожения' DESC
LIMIT 10;
"
    ;;

  accuracy)
    sqlite3 -header -column "$DB" "
SELECT
    s.name AS 'Станция',
    ROUND(100.0 * SUM(CASE WHEN sh.is_hit = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS 'Меткость (%)'
FROM unified_system sh
JOIN unified_system s ON sh.system_ref = s.id
WHERE sh.entity_type = 'shoot'
GROUP BY sh.system_ref
HAVING COUNT(*) > 0
ORDER BY 'Меткость (%)' DESC
LIMIT 10;
"
    ;;

  ammo)
    sqlite3 -header -column "$DB" "
SELECT 
    s.name AS 'Станция',
    SUM(m.ammo) AS 'Боеприпасы'
FROM unified_system m
JOIN unified_system s ON m.system_ref = s.id
WHERE m.entity_type = 'missile'
GROUP BY m.system_ref
ORDER BY s.name;
"
    ;;

  kills_interval)
    START_TIME="$1"
    END_TIME="$2"
    if [[ -z "$START_TIME" || -z "$END_TIME" ]]; then
      echo "Для команды kills_interval укажите два параметра: start_time end_time"
      echo "Пример: $0 $DB kills_interval '2024-01-01 00:00' '2024-01-31 23:59'"
      exit 1
    fi
    sqlite3 -header -column "$DB" "
SELECT 
    s.name AS 'Станция',
    COUNT(*) AS 'Сбито целей'
FROM unified_system sh
JOIN unified_system s ON sh.system_ref = s.id
WHERE sh.entity_type = 'shoot' 
  AND sh.is_hit = 1
  AND sh.timestamp BETWEEN '$START_TIME' AND '$END_TIME'
GROUP BY sh.system_ref
ORDER BY 'Сбито целей' DESC;
"
    ;;

  targets_spro)
    sqlite3 -header -column "$DB" "
SELECT 
    original_id AS 'ID цели',
    target_type AS 'Тип цели',
    timestamp AS 'Время обнаружения'
FROM unified_system 
WHERE entity_type = 'target'
  AND target_type LIKE '%СПРО%'
ORDER BY timestamp;
"
    ;;

  *)
    echo "Неизвестная команда: $COMMAND"
    exit 1
    ;;

esac
