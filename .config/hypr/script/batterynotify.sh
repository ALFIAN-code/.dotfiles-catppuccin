#!/bin/bash

# Pastikan upower sudah terinstal
BATTERY_PATH=$(upower -e | grep battery_BAT)
LOW_THRESHOLDS=(20 15 10)
SUSPEND_THRESHOLD=7

prev_state=""
notified_levels=()

# Fungsi untuk mengirim notifikasi sekali per level
send_once() {
    level=$1
    message=$2
    urgency=$3

    if [[ ! " ${notified_levels[@]} " =~ " ${level} " ]]; then
        notify-send -u "$urgency" "Peringatan Baterai" "$message"
        notified_levels+=("$level")
    fi
}

# Monitoring upower secara real-time
upower --monitor-detail "$BATTERY_PATH" | while read -r line; do
    if echo "$line" | grep -q "state:"; then
        state=$(echo "$line" | awk '{print $2}')
        if [ "$state" != "$prev_state" ]; then
            if [ "$state" = "charging" ]; then
                notify-send "Charger Connected" "Charger telah dicolok."
                notified_levels=()  # Reset daftar level yang sudah dinotifikasi
            elif [ "$state" = "discharging" ]; then
                notify-send "Charger Disconnected" "Charger telah dicabut."
            fi
            prev_state="$state"
        fi
    fi

    if echo "$line" | grep -q "percentage:"; then
        percentage=$(echo "$line" | awk '{print $2}' | sed 's/%//')

        if [ "$prev_state" = "charging" ]; then
            if [ "$percentage" -eq 100 ]; then
                notify-send "Baterai Penuh" "Baterai Anda telah penuh."
            fi
        elif [ "$prev_state" = "discharging" ]; then
            if [ "$percentage" -le "$SUSPEND_THRESHOLD" ]; then
                notify-send -u critical "Baterai Sangat Lemah" "Baterai Anda $percentage%. Sistem akan ditangguhkan dalam 20 detik!"
                sleep 20
                systemctl suspend
            else
                for threshold in "${LOW_THRESHOLDS[@]}"; do
                    if [ "$percentage" -le "$threshold" ]; then
                        send_once "$threshold" "Baterai tinggal $percentage%. Harap segera isi daya." "critical"
                        break  # hanya kirim satu notifikasi terdekat
                    fi
                done
            fi
        fi
    fi
done
