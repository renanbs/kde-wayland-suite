#!/usr/bin/env bash
# ==============================================================================
# lib-harness.sh — Detecção de Harness (Host de IA) e Perfil de Modelos
#
# Suporta detecção precisa de:
#   - OMP (Oh My Pi / Orca + Antigravity)
#   - Claude Code
#   - Cursor (IDE / Agent)
#   - Antigravity
#   - OpenCode
#   - Terminal / Shell Genérico
#
# Armazena o perfil em:
#   - ~/.config/kde-wayland-suite/harness-profile.json
# ==============================================================================

HARNESS_PROFILE_DIR="${HOME}/.config/kde-wayland-suite"
HARNESS_PROFILE_FILE="${HARNESS_PROFILE_DIR}/harness-profile.json"

detect_active_harness() {
    # 1. OMP (Oh My Pi / Orca Agent) — prioridade máxima por variáveis de processo direto
    if [ -n "${OMPCODE:-}" ] || [ -n "${ORCA_OMP_SOURCE_AGENT_DIR:-}" ] || [ -n "${OMP_SESSION_ID:-}" ] || [ -n "${OMP_VERSION:-}" ] || [ -n "${OMP_AGENT:-}" ]; then
        echo "omp"
        return 0
    fi

    # 2. Antigravity nativo
    if [ -n "${ANTIGRAVITY:-}" ] || [ -n "${ANTIGRAVITY_SESSION:-}" ]; then
        echo "antigravity"
        return 0
    fi

    # 3. Cursor
    if [ -n "${CURSOR_PROJECT_DIR:-}" ] || [ -n "${CURSOR_TRACE:-}" ] || [ -n "${CURSOR_AGENT:-}" ]; then
        echo "cursor"
        return 0
    fi

    # 4. OpenCode
    if [ -n "${OPENCODE:-}" ] || [ -n "${OPENCODE_SESSION:-}" ]; then
        echo "opencode"
        return 0
    fi

    # 5. Claude Code
    if [ -n "${CLAUDE_CONVERSATION_ID:-}" ]; then
        echo "claude-code"
        return 0
    fi

    # 6. Varredura da árvore de processos (ancestrais diretos via PPID)
    local cur_pid=$$
    while [ "$cur_pid" -gt 1 ]; do
        local p_name
        p_name="$(ps -o comm= -p "$cur_pid" 2>/dev/null || echo '')"
        if echo "$p_name" | grep -qiE "^omp"; then
            echo "omp"
            return 0
        elif echo "$p_name" | grep -qiE "^claude"; then
            echo "claude-code"
            return 0
        elif echo "$p_name" | grep -qiE "^cursor"; then
            echo "cursor"
            return 0
        elif echo "$p_name" | grep -qiE "^opencode"; then
            echo "opencode"
            return 0
        fi
        cur_pid="$(ps -o ppid= -p "$cur_pid" 2>/dev/null | tr -d ' ' || echo '1')"
    done

    echo "generic-shell"
}

get_harness_friendly_name() {
    case "$1" in
        omp) echo "Oh My Pi (OMP) + Antigravity" ;;
        claude-code) echo "Claude Code (CLI)" ;;
        cursor) echo "Cursor (IDE / Agent)" ;;
        antigravity) echo "Google Antigravity" ;;
        opencode) echo "OpenCode" ;;
        *) echo "Terminal / Shell Genérico" ;;
    esac
}

get_saved_harness() {
    if [ -f "$HARNESS_PROFILE_FILE" ]; then
        grep -oP '(?<="harness": ")[^"]+' "$HARNESS_PROFILE_FILE" 2>/dev/null || echo "unknown"
    else
        echo "none"
    fi
}

get_saved_model_role() {
    local role="$1"
    if [ -f "$HARNESS_PROFILE_FILE" ]; then
        grep -oP "(?<=\"${role}\": \")[^\"]+" "$HARNESS_PROFILE_FILE" 2>/dev/null || echo "default"
    else
        echo "default"
    fi
}

save_harness_profile() {
    local harness="$1"
    local reasoning_model="${2:-google-antigravity/gemini-3.7-flash}"
    local code_model="${3:-google-antigravity/gemini-3.7-flash}"
    local review_model="${4:-google-antigravity/gemini-3.7-flash}"
    local security_model="${5:-anthropic/claude-3.7-sonnet}"

    mkdir -p "$HARNESS_PROFILE_DIR"
    cat << EOF > "$HARNESS_PROFILE_FILE"
{
  "harness": "$harness",
  "harness_name": "$(get_harness_friendly_name "$harness")",
  "configured_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "models": {
    "reasoning": "$reasoning_model",
    "code": "$code_model",
    "review": "$review_model",
    "security": "$security_model"
  }
}
EOF
}

check_harness_alignment() {
    local active saved
    active="$(detect_active_harness)"
    saved="$(get_saved_harness)"

    if [ "$saved" = "none" ]; then
        echo "unconfigured"
    elif [ "$active" != "$saved" ] && [ "$active" != "generic-shell" ] && [ "$saved" != "generic-shell" ]; then
        echo "mismatch"
    else
        echo "aligned"
    fi
}
