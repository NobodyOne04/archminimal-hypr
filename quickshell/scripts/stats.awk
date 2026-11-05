# Companion of stats.sh. Loops forever; all state lives in awk variables.

function readline(path,    line) {
    if (path == "") return ""
    line = ""
    if ((getline line < path) <= 0) line = ""
    close(path)
    return line
}

function num(v) { return v == "" ? "null" : v + 0 }

function jstr(s) { gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s); return "\"" s "\"" }

function cpu_sample(    line, f, i, n, total, idle, out) {
    n = 0; out = ""
    while ((getline line < "/proc/stat") > 0) {
        if (line !~ /^cpu/) break
        split(line, f, " ")
        total = 0
        for (i = 2; i <= 11 && (i in f); i++) total += f[i]
        idle = f[5] + f[6]                        # idle + iowait
        key = f[1]
        dt = total - ptotal[key]; di = idle - pidle[key]
        usage[key] = (ptotal[key] == "" || dt <= 0) ? 0 : (dt - di) * 100 / dt
        ptotal[key] = total; pidle[key] = idle
        if (key != "cpu") { core[n++] = usage[key] }
    }
    close("/proc/stat")
    ncores = n
}

function mem_sample(    line, f) {
    while ((getline line < "/proc/meminfo") > 0) {
        split(line, f, /[: ]+/)
        mi[f[1]] = f[2]
    }
    close("/proc/meminfo")
}

function net_sample(    line, f, iface, rx, tx, now) {
    iface = ""
    while ((getline line < "/proc/net/route") > 0) {
        split(line, f, "\t")
        if (f[2] == "00000000" && iface == "") iface = f[1]
    }
    close("/proc/net/route")
    net_if = iface; rx_rate = 0; tx_rate = 0
    while ((getline line < "/proc/net/dev") > 0) {
        if (line !~ ":") continue
        sub(/^ +/, "", line)
        split(line, f, /[: ]+/)
        if (f[1] != iface) continue
        rx = f[2]; tx = f[10]
        if (prx != "" && pif == iface) { rx_rate = (rx - prx) / interval; tx_rate = (tx - ptx) / interval }
        prx = rx; ptx = tx; pif = iface
    }
    close("/proc/net/dev")
    wifi_quality = ""
    while ((getline line < "/proc/net/wireless") > 0) {
        sub(/^ +/, "", line)
        split(line, f, /[: ]+/)
        if (f[1] == iface) { wifi_quality = f[3]; sub(/\.$/, "", wifi_quality) }
    }
    close("/proc/net/wireless")
    # SSID changes rarely: refresh every 10 ticks, only for wireless links.
    if (wifi_quality != "" && (tick % 10 == 0 || ssid_if != iface)) {
        ssid = ""; ssid_if = iface
        cmd = "iw dev " iface " link 2>/dev/null"
        while ((cmd | getline line) > 0) if (line ~ /SSID:/) { sub(/.*SSID: /, "", line); ssid = line }
        close(cmd)
    }
    if (wifi_quality == "") ssid = ""
}

function gpu_json(    busy, temp, vu, vt, pw, state, line, f, cmd, cur, max) {
    # NVIDIA dGPU: only when awake.
    if (ngpu != "") {
        state = readline(ngpu "/device/power/runtime_status")
        if (state == "" || state == "active") {
            cmd = "nvidia-smi --query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw --format=csv,noheader,nounits 2>/dev/null"
            line = ""; cmd | getline line; close(cmd)
            if (line != "") {
                split(line, f, /, */)
                return "{\"vendor\":\"nvidia\",\"name\":" jstr(f[1]) ",\"busy\":" num(f[2]) ",\"temp\":" num(f[3]) \
                       ",\"vram_used\":" num(f[4] * 1048576) ",\"vram_total\":" num(f[5] * 1048576) \
                       ",\"power\":" num(f[6]) ",\"dgpu\":\"on\"}"
            }
        }
    }
    dg = ngpu == "" ? "null" : "\"off\""
    if (igpu_vendor == "amd") {
        busy = readline(igpu "/device/gpu_busy_percent")
        vu = readline(igpu "/device/mem_info_vram_used"); vt = readline(igpu "/device/mem_info_vram_total")
        temp = readline(gpu_hwmon "/temp1_input"); if (temp != "") temp = temp / 1000
        pw = readline(gpu_hwmon "/power1_average"); if (pw == "") pw = readline(gpu_hwmon "/power1_input")
        if (pw != "") pw = pw / 1000000
        return "{\"vendor\":\"amd\",\"busy\":" num(busy) ",\"temp\":" num(temp) ",\"vram_used\":" num(vu) \
               ",\"vram_total\":" num(vt) ",\"power\":" num(pw) ",\"dgpu\":" dg "}"
    }
    if (igpu_vendor == "intel") {
        cur = readline(intel_cur); max = readline(intel_max)
        busy = (cur != "" && max > 0) ? int(cur * 100 / max) : ""
        return "{\"vendor\":\"intel\",\"busy\":" num(busy) ",\"freq\":" num(cur) ",\"temp\":null,\"dgpu\":" dg "}"
    }
    return "null"
}

BEGIN {
    tick = 0
    for (;;) {
        cpu_sample(); mem_sample(); net_sample()
        cores_json = ""
        for (i = 0; i < ncores; i++) cores_json = cores_json (i ? "," : "") sprintf("%.0f", core[i])
        t = readline(cpu_temp); if (t != "") t = t / 1000
        split(readline("/proc/loadavg"), la, " ")
        printf "{\"cpu\":%.1f,\"cores\":[%s],\"cpu_temp\":%s,\"load\":%s,", usage["cpu"], cores_json, num(t), jstr(la[1] " " la[2] " " la[3])
        printf "\"mem_total\":%d,\"mem_used\":%d,\"mem_cache\":%d,\"swap_total\":%d,\"swap_used\":%d,", \
            mi["MemTotal"] * 1024, (mi["MemTotal"] - mi["MemAvailable"]) * 1024, (mi["Cached"] + mi["Buffers"]) * 1024, \
            mi["SwapTotal"] * 1024, (mi["SwapTotal"] - mi["SwapFree"]) * 1024
        printf "\"net\":{\"iface\":%s,\"rx\":%.0f,\"tx\":%.0f,\"wifi\":%s,\"ssid\":%s},", jstr(net_if), rx_rate, tx_rate, num(wifi_quality), jstr(ssid)
        printf "\"gpu\":%s}\n", gpu_json()
        fflush()
        tick++
        system("sleep " interval)
    }
}
