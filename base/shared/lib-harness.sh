#!/usr/bin/env bash
# ==============================================================================
# lib-harness.sh — Detecção de Harness (Host de IA) e Perfil de Modelos
#
# Suporta detecção de:
#   - OMP (Oh My Pi)
#   - Claude Code
#   - Cursor (IDE / CLI)
#   - Antigravity
#   - OpenCode
#   - Terminal / Shell Genérico
#
# Armazena o perfil em:
#   - ~/.config/kde-wayland-suite/harness-profile.json (escopo de usuário)
# ==============================================================================

HARNESS_PROFILE_DIR="${HOME}/.config/kde-wayland-suite"
HARNESS_PROFILE_FILE="${HARNESS_PROFILE_DIR}/harness-profile.json"

detect_active_harness() {
    # 1. Variáveis de ambiente explícitas
    if [ -n "${OMP_SESSION_ID:-}" ] || [ -n "${OMP_VERSION:-}" ] || [ -n "${OMP_AGENT:-}" ]; then
        echo "omp"
        return 0
    fi
    if [ -n "${CLAUDE_CODE:-}" ] || [ -n "${CLAUDE_CONVERSATION_ID:-}" ]; then
        echo "claude-code"
        return 0
    fi
    if [ -n "${CURSOR_PROJECT_DIR:-}" ] || [ -n "${CURSOR_TRACE:-}" ] || [ -n "${CURSOR_AGENT:-}" ]; then
        echo "cursor"
        return 0
    fi
    if [ -n "${ANTIGRAVITY:-}" ] || [ -n "${ANTIGRAVITY_SESSION:-}" ]; then
        echo "antigravity"
        return 0
    fi
    if [ -n "${OPENCODE:-}" ] || [ -n "${OPENCODE_SESSION:-}" ]; then
        echo "opencode"
        return 0
    fi

    # 2. Varredura da árvore de processos (ancestrais)
    local parent_tree
    parent_tree="$(ps -o comm= -p "$PPID" 2>/dev/null || echo '')"
    if [ -n "$parent_tree" ]; then
        if echo "$parent_tree" | grep -qi "omp"; then
            echo "omp"
            return 0
        elif echo "$parent_tree" | grep -qi "claude"; then
            echo "claude-code"
            return 0
        elif echo "$parent_tree" | grep -qi "cursor"; then
            echo "cursor"
            return 0
        elif echo "$parent_tree" | grep -qi "opencode"; then
            echo "opencode"
            return 0
        fi
    fi

    # 3. Varredura mais ampla de processos do usuário
    if pgrep -u "$USER" -f "/bin/omp" >/dev/null 2>&1 || pgrep -u "$USER" -f "omp-agent" >/dev/null 2>&1; then
        echo "omp"
        return 0
    elif pgrep -u "$USER" -f "claude" >/dev/null 2>&1; then
        echo "claude-code"
        return 0
    elif pgrep -u "$USER" -f "cursor" >/dev/null 2>&1; then
        echo "cursor"
        return 0
    fi

    echo "generic-shell"
}

get_harness_friendly_name() {
    case "$1" in
        omp) echo "Oh My Pi (OMP)" ;;
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
    local reasoning_model="${2:-claude-3-7-sonnet}"
    local code_model="${3:-claude-3-7-sonnet}"
    local review_model="${4:-gemini-2-5-flash}"
    local security_model="${5:-claude-3-7-sonnet}"

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
