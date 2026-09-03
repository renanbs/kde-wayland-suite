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
