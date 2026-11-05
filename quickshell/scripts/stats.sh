#!/bin/sh
# System stats for the bar: prints one JSON object per line, every
# $1 seconds (default 2). Started once by Quickshell and kept running, so the
# only per-tick cost is one `sleep` (plus nvidia-smi while an NVIDIA GPU is
# awake).
#
# GPU selection ($ARCHMINIMAL_GPU: auto | amd | intel | nvidia | none):
#   auto -> an awake NVIDIA GPU if present, otherwise the AMD/Intel GPU.
#   A runtime-suspended NVIDIA dGPU is never queried (that would wake it).

interval=${1:-2}
mode=${ARCHMINIMAL_GPU:-auto}

# ---- CPU temperature sensor ----
cpu_temp=""
for h in /sys/class/hwmon/hwmon*; do
    [ -r "$h/name" ] || continue
    case "$(cat "$h/name")" in
        k10temp|zenpower|coretemp|cpu_thermal|x86_pkg_temp)
            [ -r "$h/temp1_input" ] && cpu_temp="$h/temp1_input" && break ;;
    esac
done
if [ -z "$cpu_temp" ] && [ -r /sys/class/thermal/thermal_zone0/temp ]; then
    cpu_temp=/sys/class/thermal/thermal_zone0/temp
fi

# ---- GPUs ----
igpu="" igpu_vendor="" ngpu=""
for c in /sys/class/drm/card[0-9]*; do
    case "$c" in *-*) continue ;; esac            # skip connectors like card1-DP-1
    [ -r "$c/device/vendor" ] || continue
    case "$(cat "$c/device/vendor")" in
        0x1002) [ -z "$igpu" ] && igpu=$c && igpu_vendor=amd ;;
        0x8086) [ -z "$igpu" ] && igpu=$c && igpu_vendor=intel ;;
        0x10de) [ -z "$ngpu" ] && ngpu=$c ;;
    esac
done
case "$mode" in
    none) igpu="" ngpu="" ;;
    nvidia) igpu="" ;;
    amd|intel) [ "$igpu_vendor" = "$mode" ] || igpu=""; ngpu="" ;;
esac
command -v nvidia-smi >/dev/null 2>&1 || ngpu=""

gpu_hwmon=""
if [ -n "$igpu" ]; then
    for h in "$igpu"/device/hwmon/hwmon*; do [ -d "$h" ] && gpu_hwmon=$h && break; done
fi
intel_cur="" intel_max=""
if [ "$igpu_vendor" = intel ] && [ -n "$igpu" ]; then
    if [ -r "$igpu/gt_cur_freq_mhz" ]; then                     # i915
        intel_cur="$igpu/gt_cur_freq_mhz"; intel_max="$igpu/gt_max_freq_mhz"
    else                                                        # xe
        f="$igpu/device/tile0/gt0/freq0"
        if [ -r "$f/cur_freq" ]; then intel_cur="$f/cur_freq"; intel_max="$f/max_freq"; fi
    fi
fi

exec awk -v interval="$interval" -v cpu_temp="$cpu_temp" \
    -v igpu="$igpu" -v igpu_vendor="$igpu_vendor" -v gpu_hwmon="$gpu_hwmon" \
    -v intel_cur="$intel_cur" -v intel_max="$intel_max" -v ngpu="$ngpu" \
    -f "$(dirname "$0")/stats.awk"
