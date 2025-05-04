#!/bin/bash

SCRIPTS=(
    "./SPRO.sh 1 2500000 3500000 1700000"
    "./RLS.sh 1 3200000 3700000 3000000 270 120"
    "./RLS.sh 2 8000000 6000000 60000000 45 90"
    "./RLS.sh 3 8000000 3500000 4000000 270 200"
    "./ZRDN.sh 1 2900000 4600000 600000"
    "./ZRDN.sh 2 4300000 4100000 400000"
    "./ZRDN.sh 3 5400000 3350000 550000"
    "./KP.sh"
)

declare -a PIDS

start_scripts() {
    echo "Запуск скриптов..."
    for script in "${SCRIPTS[@]}"; do
        eval "$script" &
        PIDS+=($!)
        echo "  Запущен: $script (PID: $!)"
        sleep 0.1  
    done
    echo "Все скрипты запущены"
}

stop_scripts() {
    echo "Остановка скриптов..."
    for pid in "${PIDS[@]}"; do
        if ps -p "$pid" > /dev/null; then
            kill -TERM "$pid" 2>/dev/null && \
            echo "  Остановлен процесс $pid" || \
            echo "  Не удалось остановить процесс $pid"
        fi
    done
    wait
    echo "Все скрипты остановлены"
    exit 0
}

trap stop_scripts SIGINT SIGTERM

case "$1" in
    start)
        start_scripts
        
        wait
        ;;
    stop)
        stop_scripts
        ;;
    *)
        echo "Использование: $0 {start|stop}"
        exit 1
        ;;
esac

echo "Работа завершена"
