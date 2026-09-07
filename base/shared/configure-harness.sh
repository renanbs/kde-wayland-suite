#!/usr/bin/env bash
# ==============================================================================
# configure-harness.sh — AI Host Harness, Language & Model Profile Alignment
#
# Manages the mapping of model roles (reasoning, code, review, security) and
# language preferences (en, pt-BR) for the active harness.
# ==============================================================================
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
    local active saved alignment lang
    active="$(detect_active_harness)"
    saved="$(get_saved_harness)"
    alignment="$(check_harness_alignment)"
    lang="$(get_saved_language)"

    echo -e "${BOLD}=== AI HOST HARNESS & MODEL ROLE PROFILE ===${NC}"
    echo -e "  • Active Detected Harness: ${BOLD}$(get_harness_friendly_name "$active")${NC} (${active})"
    echo -e "  • Saved System Profile:    ${BOLD}$(get_harness_friendly_name "$saved")${NC} (${saved})"
    echo -e "  • Configured Language:     ${BOLD}${lang}${NC}"

    if [ "$alignment" = "aligned" ]; then
        echo -e "  • Alignment: ${GREEN}[ALIGNED]${NC} (Current environment matches saved profile)."
        runlog_event "ok" "harness_aligned" "active=$active, saved=$saved, lang=$lang"
    elif [ "$alignment" = "unconfigured" ]; then
        echo -e "  • Alignment: ${YELLOW}[UNCONFIGURED]${NC} (Run './bin/kde-config configure-harness' or 'init')."
        runlog_event "warn" "harness_unconfigured" ""
    else
        echo -e "  • Alignment: ${YELLOW}[MISMATCH]${NC} (Running in ${BOLD}$active${NC}, but profile was saved for ${BOLD}$saved${NC})."
        echo -e "    Suggestion: Run '${BOLD}./bin/kde-config configure-harness --sync${NC}' to update."
        runlog_event "warn" "harness_mismatch" "active=$active, saved=$saved"
    fi

    if [ -f "$HARNESS_PROFILE_FILE" ]; then
        echo -e "\n  ${BOLD}Configured model roles:${NC}"
        echo -e "    • Reasoning / Architecture (reasoning): ${BOLD}$(get_saved_model_role "reasoning")${NC}"
        echo -e "    • Implementation / Code (code):         ${BOLD}$(get_saved_model_role "code")${NC}"
        echo -e "    • Review / Sanity (review):             ${BOLD}$(get_saved_model_role "review")${NC}"
        echo -e "    • Security / Defense (security):        ${BOLD}$(get_saved_model_role "security")${NC}"
    fi
}

cmd_set_lang() {
    local lang="${1:-en}"
    set_saved_language "$lang"
    local saved_lang
    saved_lang="$(get_saved_language)"
    echo -e "${GREEN}✔ Language preference saved: ${BOLD}${saved_lang}${NC} in ${HARNESS_PROFILE_FILE}"
    runlog_event "ok" "language_saved" "language=$saved_lang"
}

cmd_get_lang() {
    get_saved_language
}

cmd_set() {
    local harness="${1:-$(detect_active_harness)}"
    local reasoning="${2:-google-antigravity/gemini-3.7-flash}"
    local code="${3:-google-antigravity/gemini-3.7-flash}"
    local review="${4:-google-antigravity/gemini-3.7-flash}"
    local security="${5:-anthropic/claude-3.7-sonnet}"
    local language="${6:-$(get_saved_language)}"

    echo -e "${BOLD}### 1. Plan${NC}\n"
    echo -e "- **Command:** ./bin/kde-config configure-harness --set $harness $reasoning $code $review $security $language"
    echo -e "- **Action:** Saves harness profile ($harness), model mapping, and language preference in ${HARNESS_PROFILE_FILE}"
    echo -e "- **Reversible:** Yes, reconfigure anytime\n"

    echo -e "${BOLD}### 2. Execution${NC}\n"

    save_harness_profile "$harness" "$reasoning" "$code" "$review" "$security" "$language"
    echo -e "  ✅ [1/2] Profile and language saved to ${BOLD}${HARNESS_PROFILE_FILE}${NC}"
    runlog_event "ok" "harness_profile_saved" "harness=$harness, lang=$language"

    echo -e "  ✅ [2/2] Model roles configured successfully"
    runlog_event "ok" "harness_models_configured" "r=$reasoning, c=$code, rev=$review, sec=$security, lang=$language"

    echo -e "\n${BOLD}### 3. Summary${NC}\n"
    echo -e "| Field | Content |"
    echo -e "| :--- | :--- |"
    echo -e "| Changed | Saved harness profile for $(get_harness_friendly_name "$harness") |"
    echo -e "| Language (language) | $language |"
    echo -e "| Reasoning (reasoning) | $reasoning |"
    echo -e "| Implementation (code) | $code |"
    echo -e "| Review (review) | $review |"
    echo -e "| Security (security) | $security |"
    echo -e "| Profile File | ${HARNESS_PROFILE_FILE} |"
    echo -e "| Saved Report | ./bin/kde-config report (or ~/.local/state/kde-wayland-suite/runs/) |"
    echo -e "| How to Revert | ./bin/kde-config configure-harness |"
    echo -e "| Requires | nothing |"
}

cmd_sync() {
    local active
    active="$(detect_active_harness)"
    local r c rev sec lang
    r="$(get_saved_model_role "reasoning")"
    c="$(get_saved_model_role "code")"
    rev="$(get_saved_model_role "review")"
    sec="$(get_saved_model_role "security")"
    lang="$(get_saved_language)"

    [ "$r" = "default" ] && r="google-antigravity/gemini-3.7-flash"
    [ "$c" = "default" ] && c="google-antigravity/gemini-3.7-flash"
    [ "$rev" = "default" ] && rev="google-antigravity/gemini-3.7-flash"
    [ "$sec" = "default" ] && sec="anthropic/claude-3.7-sonnet"

    cmd_set "$active" "$r" "$c" "$rev" "$sec" "$lang"
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
    --set-lang)
        shift
        cmd_set_lang "${1:-en}"
        ;;
    --get-lang)
        cmd_get_lang
        ;;
    --sync)
        cmd_sync
        ;;
    *)
        echo "Usage: $0 [--detect | --status | --set <harness> <reasoning> <code> <review> <security> [language] | --set-lang <en|pt-BR> | --get-lang | --sync]"
        exit 1
        ;;
esac
