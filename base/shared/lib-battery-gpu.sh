#!/usr/bin/env bash
# ==============================================================================
# lib-battery-gpu.sh — Helpers para parsear/reescrever KWIN_DRM_DEVICES
# Formato: entradas separadas por ':' não-escapado; ':' dentro de uma entrada
# (parte do endereço PCI em /dev/dri/by-path/pci-0000:01:00.0-card) vem como
# '\:' literal na variável de ambiente. Precisa de parsing com placeholder
# para não quebrar no ':' escapado.
# Sourced por diagnose-battery.sh e configure-battery.sh — não executável sozinho.
# ==============================================================================

_KWIN_GPU_SENTINEL=$'\x01'

# echo, uma por linha, das entradas des-escapadas de um valor KWIN_DRM_DEVICES bruto
kwin_drm_split() {
    local raw="$1"
    echo "$raw" | sed "s/\\\\:/${_KWIN_GPU_SENTINEL}/g" | tr ':' '\n' | sed "s/${_KWIN_GPU_SENTINEL}/:/g"
}

# recebe entradas des-escapadas via stdin (uma por linha) e reconstrói o valor
# bruto (':' interno de cada entrada volta a virar '\:', entradas separadas por ':')
kwin_drm_join() {
    local out="" first=1 line
    while IFS= read -r line; do
        local escaped="${line//:/\\:}"
        if [ "$first" = 1 ]; then
            out="$escaped"
            first=0
        else
            out="${out}:${escaped}"
        fi
    done
    printf '%s' "$out"
}

# localiza o arquivo de ~/.config/plasma-workspace/env/*.sh que exporta KWIN_DRM_DEVICES
# preenche as globais KWIN_ENV_FILE e KWIN_DRM_VALUE (vazio se não encontrado)
kwin_drm_locate() {
    KWIN_ENV_FILE=""
    KWIN_DRM_VALUE=""
    local env_dir="$HOME/.config/plasma-workspace/env"
    [ -d "$env_dir" ] || return 0
    local f
    for f in "$env_dir"/*.sh; do
        [ -f "$f" ] || continue
        if grep -q "KWIN_DRM_DEVICES" "$f" 2>/dev/null; then
            KWIN_ENV_FILE="$f"
            KWIN_DRM_VALUE="$(grep "KWIN_DRM_DEVICES" "$f" | tail -1 | sed -E 's/^[^=]*=//; s/^"//; s/"$//')"
            return 0
        fi
    done
    return 0
}

# echo "<card> <pci>" da GPU que atende a saída eDP conectada, ou nada se não achar
find_edp_card_pci() {
    local st card pci
    for st in /sys/class/drm/card*-eDP-*/status; do
        [ -f "$st" ] || continue
        if [ "$(cat "$st" 2>/dev/null)" = "connected" ]; then
            card="$(basename "$(dirname "$st")" | cut -d- -f1)"
            pci="$(readlink -f "/sys/class/drm/$card/device" 2>/dev/null | xargs -r basename)"
            [ -n "$pci" ] && echo "$card $pci"
            return 0
        fi
    done
}

# echo do endereço PCI de um device path tipo /dev/dri/by-path/pci-XXXX-card ou /dev/dri/cardN
pci_for_device_path() {
    local dev="$1"
    local real card
    real="$(readlink -f "$dev" 2>/dev/null || echo "$dev")"
    card="$(basename "$real")"
    readlink -f "/sys/class/drm/$card/device" 2>/dev/null | xargs -r basename
}

# -----------------------------------------------------------------------------
# Helpers para Taxa de Atualização da Tela Interna (eDP) via kscreen-doctor
# -----------------------------------------------------------------------------

# echo "<NAME> <CURRENT_HZ> <CURRENT_MODE_ID> <60HZ_MODE_ID> <HIGH_HZ_MODE_ID>"
find_edp_refresh_modes() {
    if ! command -v kscreen-doctor >/dev/null 2>&1; then
        return 0
    fi
    python3 -c '
import subprocess, re
try:
    out = subprocess.check_output(["kscreen-doctor", "-o"], text=True)
except Exception:
    out = ""
clean = re.sub(r"\x1b\[[0-9;]*m", "", out)
edp_match = re.search(r"Output:\s+\d+\s+(eDP[^\s]*)", clean)
if edp_match:
    name = edp_match.group(1)
    modes_match = re.search(r"Modes:\s+(.*)", clean)
    if modes_match:
        modes_str = modes_match.group(1).strip()
        modes = modes_str.split()
        cur_hz = None
        cur_id = None
        cur_res = None
        parsed = []
        for m in modes:
            parts = m.split(":")
            if len(parts) < 2:
                continue
            m_id = parts[0]
            rest = parts[1]
            is_active = "*" in rest
            clean_m = rest.replace("*", "").replace("!", "")
            if "@" not in clean_m:
                continue
            res, hz_str = clean_m.split("@")
            try:
                hz = float(hz_str)
                int_hz = int(round(hz))
            except ValueError:
                continue
            parsed.append((m_id, res, int_hz, is_active))
            if is_active:
                cur_hz = int_hz
                cur_id = m_id
                cur_res = res
        mode_60 = None
        mode_high = None
        max_hz = 60
        # Prefer modes with same resolution as current
        for m_id, res, int_hz, _ in parsed:
            if res == cur_res:
                if int_hz in (59, 60) and not mode_60:
                    mode_60 = m_id
                if int_hz > 60 and int_hz >= max_hz:
                    max_hz = int_hz
                    mode_high = m_id
        # Fallback if no matching resolution for 60Hz
        if not mode_60:
            for m_id, res, int_hz, _ in parsed:
                if int_hz in (59, 60):
                    mode_60 = m_id
                    break
        ch = cur_hz if cur_hz is not None else "unknown"
        ci = cur_id if cur_id is not None else "none"
        m6 = mode_60 if mode_60 is not None else "none"
        mh = mode_high if mode_high is not None else "none"
        print(f"{name} {ch} {ci} {m6} {mh}")
' 2>/dev/null || true
}

set_edp_mode() {
    local edp_name="$1"
    local mode_id="$2"
    if ! command -v kscreen-doctor >/dev/null 2>&1; then
        echo -e "${RED}Erro: kscreen-doctor não disponível para alternar modo de tela.${NC}"
        return 1
    fi
    local res
    res="$(kscreen-doctor "output.${edp_name}.mode.${mode_id}" 2>&1 || true)"
    if echo "$res" | grep -qiE "failed|rejected|error"; then
        return 1
    fi
    return 0
}
