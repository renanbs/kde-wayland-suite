#!/usr/bin/env bash
# ==============================================================================
# lib-runlog.sh — Registro estruturado de cada execução da suíte.
#
# Por que existe: até a v1.6.3 a saída dos comandos vivia só no scrollback do
# terminal. Não dava para responder "o que mudou na última vez?" nem "a saúde
# da bateria está caindo?". Capturar o texto colorido e parsear depois seria
# frágil (cores ANSI, prosa em português que muda a cada ajuste de redação),
# então os scripts emitem EVENTOS estruturados e o relatório é montado a partir
# dos dados — o texto bruto fica só como forense.
#
# Layout de um run em $RUNLOG_ROOT/<timestamp>-<comando>/:
#   events.tsv  epoch \t status \t id \t detalhe      (uma linha por checagem)
#   output.log  saída bruta sem códigos ANSI
#   meta.env    comando, código de saída, duração, versão
#
# status ∈ ok | warn | fail | skip | info | metric
#   'metric' carrega valor numérico em <detalhe> e alimenta a tendência
#   histórica do 'report' (ex.: metric battery_health 65.9).
#
# Sourced por bin/kde-config e pelos scripts de shared/ — não roda sozinho.
# ==============================================================================

RUNLOG_ROOT="${KDE_SUITE_RUNLOG_ROOT:-$HOME/.local/state/kde-wayland-suite/runs}"
RUNLOG_KEEP="${KDE_SUITE_RUNLOG_KEEP:-50}"
RUNLOG_DIR="${RUNLOG_DIR:-}"

# Inicia um run. $1 = nome do comando. Exporta RUNLOG_DIR para os subprocessos,
# de modo que os scripts de shared/ escrevam no mesmo run.
runlog_init() {
    local command_name="${1:-desconhecido}"
    [ "${KDE_SUITE_RUNLOG:-1}" = "0" ] && return 0

    local stamp
    stamp="$(date +%Y%m%d_%H%M%S)"
    RUNLOG_DIR="$RUNLOG_ROOT/${stamp}-${command_name}"
    mkdir -p "$RUNLOG_DIR" 2>/dev/null || { RUNLOG_DIR=""; return 0; }

    export RUNLOG_DIR
    : > "$RUNLOG_DIR/events.tsv"
    RUNLOG_STARTED_AT="$(date +%s)"
    export RUNLOG_STARTED_AT
    return 0
}

# Registra um evento: runlog_event <status> <id> [detalhe]
# Silencioso e à prova de falha: log nunca pode quebrar o comando principal.
runlog_event() {
    [ -z "${RUNLOG_DIR:-}" ] && return 0
    [ -d "$RUNLOG_DIR" ] || return 0
    local status="${1:-info}" id="${2:-sem_id}" detail="${3:-}"
    printf '%s\t%s\t%s\t%s\n' "$(date +%s)" "$status" "$id" "$detail" \
        >> "$RUNLOG_DIR/events.tsv" 2>/dev/null || true
    return 0
}

# Atalho para métricas numéricas (tendência histórica).
runlog_metric() {
    runlog_event "metric" "${1:-sem_id}" "${2:-}"
}

# Fecha o run: grava meta.env e poda runs antigos. $1 = código de saída.
runlog_finish() {
    [ -z "${RUNLOG_DIR:-}" ] && return 0
    [ -d "$RUNLOG_DIR" ] || return 0
    local exit_code="${1:-0}"
    local now duration
    now="$(date +%s)"
    duration=$(( now - ${RUNLOG_STARTED_AT:-$now} ))

    {
        printf 'COMMAND=%s\n' "${RUNLOG_COMMAND:-desconhecido}"
        printf 'EXIT_CODE=%s\n' "$exit_code"
        printf 'STARTED_AT=%s\n' "${RUNLOG_STARTED_AT:-$now}"
        printf 'FINISHED_AT=%s\n' "$now"
        printf 'DURATION_SECONDS=%s\n' "$duration"
        printf 'SUITE_VERSION=%s\n' "${RUNLOG_SUITE_VERSION:-desconhecida}"
        printf 'HOSTNAME=%s\n' "$(hostname 2>/dev/null || echo '?')"
    } > "$RUNLOG_DIR/meta.env" 2>/dev/null || true

    runlog_prune
    return 0
}

# Mantém apenas os RUNLOG_KEEP runs mais recentes, para o diretório não crescer
# indefinidamente. Usa ordenação por nome, que é cronológica pelo timestamp.
runlog_prune() {
    [ -d "$RUNLOG_ROOT" ] || return 0
    local count
    count="$(find "$RUNLOG_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)"
    [ "$count" -le "$RUNLOG_KEEP" ] && return 0

    local excess=$(( count - RUNLOG_KEEP ))
    find "$RUNLOG_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
        | sort | head -n "$excess" \
        | while IFS= read -r old; do
            case "$old" in
                "$RUNLOG_ROOT"/*) rm -rf "$old" 2>/dev/null || true ;;
            esac
        done
    return 0
}
