#!/usr/bin/env bash
set -uo pipefail

# ==============================================================================
# report.sh — Relatório da última execução + tendência histórica.
#
# Lê os runs gravados por lib-runlog.sh (eventos estruturados, não o texto
# colorido) e monta um relatório legível com ações recomendadas para resolver
# pontos não conformes (avisos e falhas).
# ==============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

RUNLOG_ROOT="${KDE_SUITE_RUNLOG_ROOT:-$HOME/.local/state/kde-wayland-suite/runs}"

if [ ! -d "$RUNLOG_ROOT" ] || [ -z "$(find "$RUNLOG_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)" ]; then
    echo -e "${YELLOW}Nenhuma execução registrada ainda em $RUNLOG_ROOT.${NC}"
    echo "Rode qualquer comando da suíte (ex: './bin/kde-config status') e tente de novo."
    exit 0
fi

# Traduz o status do evento para um marcador visual, alinhado ao contrato de
# saída padronizado da suíte (ver shared/OUTPUT-CONTRACT.md).
marker_for() {
    case "$1" in
        ok)     printf '%b' "${GREEN}✅${NC}" ;;
        fail)   printf '%b' "${RED}❌${NC}" ;;
        warn)   printf '%b' "${YELLOW}⚠️${NC}" ;;
        skip)   printf '%b' "${BLUE}⏭️${NC}" ;;
        *)      printf '%b' "${BLUE}•${NC}" ;;
    esac
}

human_time() {
    date -d "@$1" '+%d/%m/%Y às %H:%M:%S' 2>/dev/null || echo "$1"
}

show_run() {
    local dir="$1"
    local meta="$dir/meta.env"
    local events="$dir/events.tsv"

    local command_name="?" exit_code="?" started="" duration="?"
    if [ -f "$meta" ]; then
        # shellcheck disable=SC1090
        command_name="$(grep -oP '(?<=^COMMAND=).*' "$meta" 2>/dev/null || echo '?')"
        exit_code="$(grep -oP '(?<=^EXIT_CODE=).*' "$meta" 2>/dev/null || echo '?')"
        started="$(grep -oP '(?<=^STARTED_AT=).*' "$meta" 2>/dev/null || echo '')"
        duration="$(grep -oP '(?<=^DURATION_SECONDS=).*' "$meta" 2>/dev/null || echo '?')"
    fi

    echo -e "${BOLD}Comando:${NC} $command_name"
    [ -n "$started" ] && echo -e "${BOLD}Quando:${NC}  $(human_time "$started")  (${duration}s)"
    if [ "$exit_code" = "0" ]; then
        echo -e "${BOLD}Saída:${NC}   ${GREEN}sucesso (código 0)${NC}"
    else
        echo -e "${BOLD}Saída:${NC}   ${RED}falha (código $exit_code)${NC}"
    fi
    echo ""

    if [ ! -s "$events" ]; then
        echo -e "  ${BLUE}[INFO]${NC} Este comando não registrou eventos estruturados."
        [ -f "$dir/output.log" ] && echo -e "  Saída bruta preservada em: $dir/output.log"
        return 0
    fi

    # Contadores por status e lista de recomendações
    local n_ok=0 n_fail=0 n_warn=0 n_skip=0
    local recommendations=()

    while IFS=$'\t' read -r _ status id detail; do
        [ "$status" = "metric" ] && continue
        case "$status" in
            ok) n_ok=$((n_ok + 1)) ;;
            fail) n_fail=$((n_fail + 1)) ;;
            warn) n_warn=$((n_warn + 1)) ;;
            skip) n_skip=$((n_skip + 1)) ;;
        esac
        printf '  %b %s' "$(marker_for "$status")" "$id"
        [ -n "$detail" ] && printf ' — %s' "$detail"
        printf '\n'

        if [ "$status" = "warn" ] || [ "$status" = "fail" ]; then
            case "$id" in
                keyboard_power_auto_no_rule|serio_power_missing)
                    recommendations+=("${YELLOW}Energia do Teclado (anti-latch):${NC} execute '${BOLD}./bin/kde-config smart-keyboard-power --apply${NC}'")
                    ;;
                tongfang_kernel_params_missing|tongfang_ctrl_lock_risk)
                    recommendations+=("${YELLOW}Teclado Tongfang/Avell:${NC} execute '${BOLD}./bin/kde-config fix-tongfang${NC}'")
                    ;;
                im_conf_present|im_env_forced|im_systemd_env_forced|fcitx5_running|fcitx5_system_autostart_unmasked|cedilla_conf_invalid|cedilla_conf_missing|lc_ctype_process_missing|kxkbrc_layout_empty|kxkbrc_layout_collapsed)
                    recommendations+=("${YELLOW}Teclado e Atalhos (Ctrl+C / Cedilha):${NC} execute '${BOLD}./bin/kde-config fix-keyboard${NC}'")
                    ;;
                xsel_hung)
                    recommendations+=("${YELLOW}Clipboard travado:${NC} execute '${BOLD}./bin/kde-config fix-keyboard${NC}'")
                    ;;
                *)
                    [ -n "$detail" ] && recommendations+=("${id}: ${detail}")
                    ;;
            esac
        fi
    done < "$events"

    echo ""
    echo -e "  ${BOLD}Balanço:${NC} ${GREEN}${n_ok} ok${NC} · ${RED}${n_fail} falha(s)${NC} · ${YELLOW}${n_warn} aviso(s)${NC} · ${BLUE}${n_skip} pulado(s)${NC}"

    if [ "${#recommendations[@]}" -gt 0 ]; then
        echo ""
        echo -e "  ${BOLD}${YELLOW}Como resolver pontos não conformes (Ações Recomendadas):${NC}"
        local rec
        for rec in "${recommendations[@]}"; do
            echo -e "  👉 ${rec}"
        done
    fi

    [ -f "$dir/output.log" ] && echo -e "\n  Saída bruta: $dir/output.log"
}

show_history() {
    echo -e "${BOLD}${BLUE}======================================================${NC}"
    echo -e "${BOLD}${BLUE}   Tendência histórica (métricas)                     ${NC}"
    echo -e "${BOLD}${BLUE}======================================================${NC}"

    local all_metrics
    all_metrics="$(find "$RUNLOG_ROOT" -mindepth 2 -maxdepth 2 -name events.tsv 2>/dev/null \
        | sort \
        | xargs -r grep -h -P '^\d+\tmetric\t' 2>/dev/null || true)"

    if [ -z "$all_metrics" ]; then
        echo -e "  ${BLUE}[INFO]${NC} Nenhuma métrica registrada ainda."
        echo "  Métricas são gravadas pelos comandos de diagnóstico (status, battery-status)."
        return 0
    fi

    local ids
    ids="$(echo "$all_metrics" | cut -f3 | sort -u)"

    local id
    for id in $ids; do
        local series first last n
        series="$(echo "$all_metrics" | awk -F'\t' -v k="$id" '$3==k {print $1"\t"$4}')"
        n="$(echo "$series" | wc -l)"
        first="$(echo "$series" | head -1)"
        last="$(echo "$series" | tail -1)"

        local first_val last_val first_epoch last_epoch
        first_val="$(echo "$first" | cut -f2)"; first_epoch="$(echo "$first" | cut -f1)"
        last_val="$(echo "$last" | cut -f2)";   last_epoch="$(echo "$last" | cut -f1)"

        printf '\n  %b%s%b  (%s amostra(s))\n' "$BOLD" "$id" "$NC" "$n"
        printf '    primeiro: %s  em %s\n' "$first_val" "$(human_time "$first_epoch")"
        printf '    último:   %s  em %s\n' "$last_val" "$(human_time "$last_epoch")"

        if [ "$n" -gt 1 ] \
           && echo "$first_val" | grep -qE '^-?[0-9]+([.,][0-9]+)?$' \
           && echo "$last_val" | grep -qE '^-?[0-9]+([.,][0-9]+)?$'; then
            local delta
            delta="$(awk -v a="${first_val//,/.}" -v b="${last_val//,/.}" 'BEGIN{printf "%+.2f", b-a}')"
            if [ "${delta%%.*}" = "+0" ] || [ "$delta" = "+0.00" ]; then
                printf '    variação: %bsem mudança%b\n' "$BLUE" "$NC"
            else
                printf '    variação: %b%s%b\n' "$YELLOW" "$delta" "$NC"
            fi
        fi
    done
}

list_runs() {
    local limit="$1"
    echo -e "${BOLD}${BLUE}======================================================${NC}"
    echo -e "${BOLD}${BLUE}   Últimas $limit execuções                           ${NC}"
    echo -e "${BOLD}${BLUE}======================================================${NC}"
    echo ""
    find "$RUNLOG_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -r | head -n "$limit" \
    | while IFS= read -r dir; do
        local meta="$dir/meta.env" cmd="?" code="?" started=""
        if [ -f "$meta" ]; then
            cmd="$(grep -oP '(?<=^COMMAND=).*' "$meta" 2>/dev/null || echo '?')"
            code="$(grep -oP '(?<=^EXIT_CODE=).*' "$meta" 2>/dev/null || echo '?')"
            started="$(grep -oP '(?<=^STARTED_AT=).*' "$meta" 2>/dev/null || echo '')"
        fi
        local n_fail=0
        [ -s "$dir/events.tsv" ] && n_fail="$(awk -F'\t' '$2=="fail"' "$dir/events.tsv" 2>/dev/null | wc -l)"

        local mark="${GREEN}✅${NC}"
        [ "$code" != "0" ] && mark="${RED}❌${NC}"
        [ "$n_fail" -gt 0 ] && mark="${RED}❌${NC}"

        printf '  %b %-16s %s' "$mark" "$cmd" "$( [ -n "$started" ] && human_time "$started" )"
        [ "$n_fail" -gt 0 ] && printf '  (%s falha(s))' "$n_fail"
        printf '\n'
    done
}

case "${1:-}" in
    --history|-h)
        show_history
        ;;
    ''|--last)
        LATEST="$(find "$RUNLOG_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1)"
        echo -e "${BOLD}${BLUE}======================================================${NC}"
        echo -e "${BOLD}${BLUE}   Última execução                                    ${NC}"
        echo -e "${BOLD}${BLUE}======================================================${NC}"
        echo ""
        show_run "$LATEST"
        echo ""
        show_history
        ;;
    *[0-9]*)
        list_runs "$1"
        ;;
    *)
        echo "Uso: report.sh [<n> | --history]"
        exit 1
        ;;
esac
