#!/usr/bin/env bash
# ==============================================================================
# configure-harness.sh — Configuração e Alinhamento do Perfil de Harness e Modelos
#
# Gerencia o mapeamento de papéis de modelos (reasoning, code, review, security)
# para o harness ativo e audita a sincronização com o perfil gravado.
# ==============================================================================
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-harness.sh
source "$SCRIPT_DIR/lib-harness.sh"

# Registro estruturado do run
if [ -f "$SCRIPT_DIR/lib-runlog.sh" ]; then
    # shellcheck source=lib-runlog.sh
    source "$SCRIPT_DIR/lib-runlog.sh"
else
    runlog_event() { :; }
fi

cmd_detect() {
    local active saved alignment
    active="$(detect_active_harness)"
    saved="$(get_saved_harness)"
    alignment="$(check_harness_alignment)"

    echo "ACTIVE_HARNESS=$active"
    echo "ACTIVE_HARNESS_NAME=$(get_harness_friendly_name "$active")"
    echo "SAVED_HARNESS=$saved"
    echo "SAVED_HARNESS_NAME=$(get_harness_friendly_name "$saved")"
    echo "ALIGNMENT=$alignment"
}

cmd_status() {
    local active saved alignment
    active="$(detect_active_harness)"
    saved="$(get_saved_harness)"
    alignment="$(check_harness_alignment)"

    echo -e "${BOLD}=== PERFIL DO HARNESS E MAPA DE MODELOS DE IA ===${NC}"
    echo -e "  • Harness Ativo Detectado: ${BOLD}$(get_harness_friendly_name "$active")${NC} (${active})"
    echo -e "  • Perfil Salvo no Sistema: ${BOLD}$(get_harness_friendly_name "$saved")${NC} (${saved})"

    if [ "$alignment" = "aligned" ]; then
        echo -e "  • Alinhamento: ${GREEN}[SINCRONIZADO]${NC} (O ambiente atual corresponde ao perfil gravado)."
        runlog_event "ok" "harness_aligned" "active=$active, saved=$saved"
    elif [ "$alignment" = "unconfigured" ]; then
        echo -e "  • Alinhamento: ${YELLOW}[NÃO CONFIGURADO]${NC} (Execute './bin/kde-config configure-harness' ou 'init')."
        runlog_event "warn" "harness_unconfigured" ""
    else
        echo -e "  • Alinhamento: ${YELLOW}[DESALINHADO]${NC} (Você está rodando em ${BOLD}$active${NC}, mas o perfil foi salvo para ${BOLD}$saved${NC})."
        echo -e "    Sugestão: Execute '${BOLD}./bin/kde-config configure-harness --sync${NC}' para atualizar."
        runlog_event "warn" "harness_mismatch" "active=$active, saved=$saved"
    fi

    if [ -f "$HARNESS_PROFILE_FILE" ]; then
        echo -e "\n  ${BOLD}Modelos configurados por papel:${NC}"
        echo -e "    • Raciocínio/Arquitetura (reasoning): ${BOLD}$(get_saved_model_role "reasoning")${NC}"
        echo -e "    • Código/Engenharia (code):           ${BOLD}$(get_saved_model_role "code")${NC}"
        echo -e "    • Revisão/Qualidade (review):         ${BOLD}$(get_saved_model_role "review")${NC}"
        echo -e "    • Segurança/Defesa (security):        ${BOLD}$(get_saved_model_role "security")${NC}"
    fi
}

cmd_set() {
    local harness="${1:-$(detect_active_harness)}"
    local reasoning="${2:-claude-3-7-sonnet}"
    local code="${3:-claude-3-7-sonnet}"
    local review="${4:-gemini-2-5-flash}"
    local security="${5:-claude-3-7-sonnet}"

    echo -e "${BOLD}### 1. Plano${NC}\n"
    echo -e "- **Comando:** ./bin/kde-config configure-harness --set $harness ..."
    echo -e "- **Faz:** Salva o perfil do harness ($harness) e mapeamento de modelos em ${HARNESS_PROFILE_FILE}"
    echo -e "- **Reversível:** Sim, reconfigurando a qualquer momento\n"

    echo -e "${BOLD}### 2. Execução${NC}\n"

    save_harness_profile "$harness" "$reasoning" "$code" "$review" "$security"
    echo -e "  ✅ [1/2] Perfil gravado em ${BOLD}${HARNESS_PROFILE_FILE}${NC}"
    runlog_event "ok" "harness_profile_saved" "harness=$harness"

    echo -e "  ✅ [2/2] Papéis de modelos associados com sucesso"
    runlog_event "ok" "harness_models_configured" "r=$reasoning, c=$code, rev=$review, sec=$security"

    echo -e "\n${BOLD}### 3. Resumo${NC}\n"
    echo -e "| Campo | Conteúdo |"
    echo -e "| :--- | :--- |"
    echo -e "| O que mudou | Perfil de harness salvo para $(get_harness_friendly_name "$harness") |"
    echo -e "| Raciocínio (reasoning) | $reasoning |"
    echo -e "| Implementação (code) | $code |"
    echo -e "| Revisão (review) | $review |"
    echo -e "| Segurança (security) | $security |"
    echo -e "| Arquivo de Perfil | ${HARNESS_PROFILE_FILE} |"
    echo -e "| Relatório salvo | ./bin/kde-config report (ou ~/.local/state/kde-wayland-suite/runs/) |"
    echo -e "| Como reverter | ./bin/kde-config configure-harness |"
    echo -e "| Requer | nada |"
}

cmd_sync() {
    local active
    active="$(detect_active_harness)"
    local r c rev sec
    r="$(get_saved_model_role "reasoning")"
    c="$(get_saved_model_role "code")"
    rev="$(get_saved_model_role "review")"
    sec="$(get_saved_model_role "security")"

    [ "$r" = "default" ] && r="claude-3-7-sonnet"
    [ "$c" = "default" ] && c="claude-3-7-sonnet"
    [ "$rev" = "default" ] && rev="gemini-2-5-flash"
    [ "$sec" = "default" ] && sec="claude-3-7-sonnet"

    cmd_set "$active" "$r" "$c" "$rev" "$sec"
}

ACTION="${1:---status}"
case "$ACTION" in
    --detect)
        cmd_detect
        ;;
    --status)
        cmd_status
        ;;
    --set)
        shift
        cmd_set "$@"
        ;;
    --sync)
        cmd_sync
        ;;
    *)
        echo "Uso: $0 [--detect | --status | --set <harness> <reasoning> <code> <review> <security> | --sync]"
        exit 1
        ;;
esac
