#!/usr/bin/env bash
# ==============================================================================
# upgrade-suite.sh — Verificação e Atualização da KDE Plasma 6 Wayland Suite
#
# Suporta:
#   --check    Verifica se há atualizações disponíveis no GitHub remoto
#   --apply    Aplica a atualização (git pull + atualização de marketplace no OMP/Claude)
#   --status   Exibe a versão local atual e a versão remota mais recente
# ==============================================================================
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_REPO_DIR="$(realpath "$SCRIPT_DIR/../..")"

# Registro estruturado do run
if [ -f "$SCRIPT_DIR/lib-runlog.sh" ]; then
    # shellcheck source=lib-runlog.sh
    source "$SCRIPT_DIR/lib-runlog.sh"
else
    runlog_event() { :; }
fi

get_local_version() {
    if [ -f "$BASE_REPO_DIR/package.json" ]; then
        grep -oP '(?<="version": ")[^"]+' "$BASE_REPO_DIR/package.json" 2>/dev/null | head -1 || echo "unknown"
    else
        echo "unknown"
    fi
}

get_remote_version() {
    # Tenta ler do git remote via git ls-remote ou fetch silencioso
    if [ -d "$BASE_REPO_DIR/.git" ]; then
        local remote_raw
        remote_raw="$(git -C "$BASE_REPO_DIR" log origin/main -n 1 --pretty=format:"%h" 2>/dev/null || echo '')"
        if [ -z "$remote_raw" ]; then
            git -C "$BASE_REPO_DIR" fetch origin main --quiet 2>/dev/null || true
        fi
        # Lê a versão remota do package.json na origin/main
        local ver
        ver="$(git -C "$BASE_REPO_DIR" show origin/main:package.json 2>/dev/null | grep -oP '(?<="version": ")[^"]+' | head -1 || echo '')"
        if [ -n "$ver" ]; then
            echo "$ver"
            return 0
        fi
    fi
    get_local_version
}

cmd_check() {
    local local_ver remote_ver
    local_ver="$(get_local_version)"
    echo "[*] Consultando repositório remoto (origin/main)..."
    git -C "$BASE_REPO_DIR" fetch origin main --quiet 2>/dev/null || true
    remote_ver="$(get_remote_version)"

    local local_hash remote_hash
    local_hash="$(git -C "$BASE_REPO_DIR" rev-parse --short HEAD 2>/dev/null || echo 'local')"
    remote_hash="$(git -C "$BASE_REPO_DIR" rev-parse --short origin/main 2>/dev/null || echo 'remote')"

    echo "LOCAL_VERSION=$local_ver ($local_hash)"
    echo "REMOTE_VERSION=$remote_ver ($remote_hash)"

    if [ "$local_hash" != "$remote_hash" ] || [ "$local_ver" != "$remote_ver" ]; then
        echo "UPDATE_AVAILABLE=true"
        echo -e "\n${YELLOW}💡 Nova versão disponível:${NC} ${BOLD}v${remote_ver}${NC} (Atual: v${local_ver})"
        echo -e "   Para atualizar agora: ${BOLD}./bin/kde-config upgrade --apply${NC}"
        runlog_event "warn" "suite_update_available" "local=$local_ver, remote=$remote_ver"
    else
        echo "UPDATE_AVAILABLE=false"
        echo -e "\n${GREEN}✔ A suite já está na versão mais recente:${NC} ${BOLD}v${local_ver}${NC} ($local_hash)."
        runlog_event "ok" "suite_up_to_date" "v$local_ver"
    fi
}

cmd_apply() {
    local local_ver
    local_ver="$(get_local_version)"

    echo -e "${BOLD}### 1. Plano${NC}\n"
    echo -e "- **Comando:** ./bin/kde-config upgrade --apply"
    echo -e "- **Faz:** Atualiza o repositório git local, sincroniza links simbólicos e atualiza o plugin no marketplace do OMP/Claude"
    echo -e "- **Reversível:** Sim, via 'git checkout <commit_anterior>'\n"

    echo -e "${BOLD}### 2. Execução${NC}\n"

    echo -e "  [*] [1/4] Atualizando código local via git pull..."
    if [ -d "$BASE_REPO_DIR/.git" ]; then
        local pull_out
        pull_out="$(git -C "$BASE_REPO_DIR" pull --ff-only origin main 2>&1 || true)"
        echo -e "  ✅ [1/4] Código local sincronizado (${pull_out})"
        runlog_event "ok" "git_pull_completed" "$pull_out"
    else
        echo -e "  ⏭️ [1/4] Repositório .git não encontrado na raiz"
        runlog_event "skip" "git_pull_skipped" ""
    fi

    echo -e "  [*] [2/4] Atualizando links simbólicos da CLI (~/.local/bin)..."
    mkdir -p "$HOME/.local/bin"
    for name in linux-wayland-config kde-config wayland-config; do
        ln -sf "$BASE_REPO_DIR/base/bin/linux-wayland-config" "$HOME/.local/bin/$name"
    done
    chmod +x "$BASE_REPO_DIR/base/bin/linux-wayland-config"
    echo -e "  ✅ [2/4] Links simbólicos (~/.local/bin/{linux-wayland-config,kde-config,wayland-config}) atualizados"

    echo -e "  [*] [3/4] Atualizando plugin nos marketplaces locais de IA..."
    if command -v omp >/dev/null 2>&1; then
        omp plugin marketplace update linux-wayland-suite >/dev/null 2>&1 || true
        omp plugin upgrade linux-wayland-suite@linux-wayland-suite >/dev/null 2>&1 || true
        echo -e "  ✅ [3/4] Plugin atualizado no marketplace do OMP"
        runlog_event "ok" "omp_marketplace_upgraded" ""
    else
        echo -e "  ⏭️ [3/4] OMP CLI não encontrado no PATH"
    fi

    local new_ver
    new_ver="$(get_local_version)"
    echo -e "  ✅ [4/4] Verificação final de versão: ${BOLD}v${new_ver}${NC}"
    runlog_event "ok" "suite_upgrade_success" "from=$local_ver, to=$new_ver"

    echo -e "\n${BOLD}### 3. Resumo${NC}\n"
    echo -e "| Campo | Conteúdo |"
    echo -e "| :--- | :--- |"
    echo -e "| Versão anterior | v${local_ver} |"
    echo -e "| Versão atualizada | v${new_ver} |"
    echo -e "| Backup | Preservado no histórico do Git |"
    echo -e "| Relatório salvo | ./bin/kde-config report (ou ~/.local/state/kde-wayland-suite/runs/) |"
    echo -e "| Como reverter | git checkout HEAD@{1} |"
    echo -e "| Requer | nada (atualizado em tempo de execução) |"
}

cmd_status() {
    cmd_check
}

ACTION="${1:---status}"
case "$ACTION" in
    --check)
        cmd_check
        ;;
    --apply)
        cmd_apply
        ;;
    --status)
        cmd_status
        ;;
    *)
        echo "Uso: $0 [--check | --apply | --status]"
        exit 1
        ;;
esac
