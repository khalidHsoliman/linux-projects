#!/usr/bin/env bash
#
# health_check.sh — a simple system health report for Linux.
#
# Prints CPU load, memory usage, disk usage, and the top resource-hungry
# processes. Flags anything that crosses a configurable threshold.
#
# Usage:
#   ./health_check.sh
#
# Author: Khalid Soliman
# Course: Mastering Linux — The Comprehensive Guide

# --- Safety settings -------------------------------------------------------
# -e  : exit immediately if any command fails
# -u  : treat use of an unset variable as an error
# -o pipefail : a pipeline fails if ANY command in it fails, not just the last
set -euo pipefail

# --- Configurable thresholds (percent) -------------------------------------
# Anything at or above these values gets flagged with a [WARN] marker.
DISK_THRESHOLD=80
MEM_THRESHOLD=80
LOAD_THRESHOLD=2.0   # load average per core; >1.0 per core means fully busy

# --- Small helpers ---------------------------------------------------------
# Print a section header so the output is easy to scan.
print_header() {
    echo
    echo "=============================================="
    echo "  $1"
    echo "=============================================="
}

# --- Report header ---------------------------------------------------------
echo "System Health Report"
echo "Host: $(hostname)"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Uptime:$(uptime -p | sed 's/up//')"   # -p = pretty format ("2 hours, 5 minutes")

# --- CPU load --------------------------------------------------------------
print_header "CPU LOAD"
# The load averages (1, 5, 15 min) live in /proc/loadavg.
# We compare the 1-minute average against our threshold.
read -r load1 _ _ _ _ < /proc/loadavg
cores=$(nproc)
echo "Cores: ${cores}"
echo "Load average (1 min): ${load1}"

# bc handles the floating-point comparison; awk would work too.
if (( $(echo "${load1} > ${LOAD_THRESHOLD}" | bc -l) )); then
    echo "[WARN] Load is high (> ${LOAD_THRESHOLD})"
else
    echo "[OK]   Load is normal"
fi

# --- Memory usage ----------------------------------------------------------
print_header "MEMORY USAGE"
# `free` reports memory; we pull the "Mem:" line and compute used%.
# Fields from `free`: total=2, used=3.
mem_total=$(free -m | awk '/^Mem:/ {print $2}')
mem_used=$(free -m | awk '/^Mem:/ {print $3}')
mem_pct=$(( mem_used * 100 / mem_total ))

echo "Used: ${mem_used} MB / ${mem_total} MB (${mem_pct}%)"
if (( mem_pct >= MEM_THRESHOLD )); then
    echo "[WARN] Memory usage above ${MEM_THRESHOLD}%"
else
    echo "[OK]   Memory usage normal"
fi

# --- Disk usage ------------------------------------------------------------
print_header "DISK USAGE"
# `df -hP` gives human-readable sizes in a stable (POSIX) column layout.
# We skip the header (NR>1) and skip pseudo-filesystems (tmpfs, udev, loop).
printf "%-25s %-8s %-8s\n" "MOUNT" "USED%" "STATUS"
df -hP | awk 'NR>1' | while read -r fs _ _ _ pct mount; do
    # Skip virtual / snap filesystems that aren't interesting here.
    case "$fs" in
        tmpfs|udev|/dev/loop*) continue ;;
    esac

    pct_num=${pct%\%}   # strip the trailing "%" so we can compare numerically
    if (( pct_num >= DISK_THRESHOLD )); then
        status="[WARN]"
    else
        status="[OK]"
    fi
    printf "%-25s %-8s %-8s\n" "$mount" "$pct" "$status"
done

# --- Top processes ---------------------------------------------------------
print_header "TOP 5 PROCESSES (by CPU)"
# ps sorted by CPU descending; show PID, user, %CPU, %MEM, command.
ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | head -n 6

print_header "TOP 5 PROCESSES (by MEMORY)"
ps -eo pid,user,%cpu,%mem,comm --sort=-%mem | head -n 6

echo
echo "Report complete."
