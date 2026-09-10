#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# manage-chromium-cedilla.sh — Correção Nativa de Cedilha (' + c -> ç) no Wayland
#
# Aplica o patch de bytes no módulo ui::CharacterComposer do Chromium/Electron,
# eliminando a geração indevida de 'ć' no Wayland nativo sem depender de IMEs.
# Gerencia a descoberta dinâmica de apps e o gancho do pacman para autocura.
# ==============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_PATCHER="$SCRIPT_DIR/chromium-cedilla-patch.py"
PACMAN_HOOK_FILE="/etc/pacman.d/hooks/99-cedilla-wayland.hook"
SYSTEM_WRAPPER="/usr/local/bin/linux-wayland-patch-cedilla"

# Integração com lib-runlog.sh
if [ -f "$SCRIPT_DIR/lib-runlog.sh" ]; then
    source "$SCRIPT_DIR/lib-runlog.sh"
else
    runlog_event() { :; }
    runlog_metric() { :; }
fi

if [ ! -f "$PYTHON_PATCHER" ]; then
    echo -e "${RED}[ERRO] Patcher Python não encontrado em: $PYTHON_PATCHER${NC}" >&2
    exit 1
fi

# Descoberta dinâmica de binários Chromium e Electron instalados
discover_binaries() {
    python3 -c "
import glob, os, sys

search_globs = [
    '/opt/*/*',
    '/opt/*/*/*',
    '/usr/lib/electron*/electron',
    '/usr/lib/chromium/chromium',
    '/usr/share/code/code',
    '/usr/share/code-insiders/code-insiders',
    '/usr/share/vscodium*/codium*',
    os.path.expanduser('~/.config/discord/app-*/Discord'),
    '/usr/lib/discord/Discord',
    '/opt/discord/Discord',
]

found = set()
for pat in search_globs:
    for p in glob.glob(pat):
        if os.path.isfile(p) and os.access(p, os.X_OK):
            if p.endswith('.orig') or '.bak-' in p or '.tmp-' in p or p.endswith('.bak'):
                continue
            try:
                rp = os.path.realpath(p)
                # Filtra executáveis ELF com tamanho > 25MB (típico de navegadores/Electron)
                if os.path.getsize(rp) > 25 * 1024 * 1024:
                    with open(rp, 'rb') as f:
                        if f.read(4) == b'\x7fELF':
                            found.add(rp)
            except (OSError, PermissionError):
                continue

for item in sorted(found):
    print(item)
"
}

# Identifica o nome amigável do app pelo caminho do binário
app_display_name() {
    local path="$1"
    case "$path" in
        *chrome/chrome*) echo "Google Chrome" ;;
        *chromium/chromium*) echo "Chromium" ;;
        *brave-bin/brave*|*brave/brave*) echo "Brave Browser" ;;
        *msedge/msedge*) echo "Microsoft Edge" ;;
        *electron43/electron*) echo "Orca IDE (Electron 43)" ;;
        *electron*/electron*) 
            local ver
            ver="$(echo "$path" | grep -oP 'electron[0-9]+' || echo 'Electron')"
            echo "Electron Runtime ($ver)"
            ;;
        *code/code*|*code-insiders/code-insiders*) echo "Visual Studio Code" ;;
        *vscodium*) echo "VSCodium" ;;
        *discord*/Discord*) echo "Discord" ;;
        *antigravity-ide*) echo "Antigravity IDE" ;;
        *Antigravity/antigravity*) echo "Antigravity Platform" ;;
        *) basename "$path" ;;
    esac
}

# Checa o estado do binário em relação ao patch
check_binary_status() {
    local bin="$1"
    python3 -c "
import sys, os
bin_path = sys.argv[1]
if not os.path.isfile(bin_path):
    print('NOT_FOUND')
    sys.exit(0)

try:
    with open(bin_path, 'rb') as f:
        data = f.read()
    needs = data.count(b'\x63\x00\x07\x01')
    patched = data.count(b'\x63\x00\xe7\x00')
    if needs > 0:
        print(f'VULNERABLE:{needs}')
    elif patched > 0:
        print(f'PATCHED:{patched}')
    else:
        print('INELIGIBLE')
except Exception as e:
    print(f'ERROR:{e}')
" "$bin"
}

cmd_status() {
    echo -e "${BOLD}${BLUE}======================================================${NC}"
    echo -e "${BOLD}${BLUE}   Auditoria da Cedilha Wayland (Chromium / Electron)  ${NC}"
    echo -e "${BOLD}${BLUE}======================================================${NC}"
    echo -e "  ${BLUE}• Baseado na solução de Leandro Cassa (lcassa/chromium-wayland-cedilla-fix)${NC}\n"
    echo -e "${BOLD}1. Binários Detectados e Estado da Cedilha (' + c):${NC}\n"
    printf "  %-30s %-10s %-25s %-12s\n" "APLICATIVO" "TAMANHO" "ESTADO DO PATCH" "BACKUP .ORIG"
    printf "  %-30s %-10s %-25s %-12s\n" "------------------------------" "----------" "-------------------------" "------------"

    local total_found=0
    local total_patched=0
    local total_vulnerable=0

    while IFS= read -r bin; do
        [ -z "$bin" ] && continue
        total_found=$((total_found + 1))
        local name size_mb status_raw status_desc status_color backup_desc backup_color
        name="$(app_display_name "$bin")"
        size_mb="$(python3 -c "import os; print(f'{os.path.getsize(\"$bin\")/(1024*1024):.1f} MB')" 2>/dev/null || echo "N/A")"
        status_raw="$(check_binary_status "$bin")"

        if [[ "$status_raw" == PATCHED:* ]]; then
            status_desc="✔ CORRIGIDO ('+c->ç)"
            status_color="$GREEN"
            total_patched=$((total_patched + 1))
        elif [[ "$status_raw" == VULNERABLE:* ]]; then
            status_desc="✖ VULNERÁVEL ('+c->ć)"
            status_color="$RED"
            total_vulnerable=$((total_vulnerable + 1))
        else
            status_desc="Não aplicável"
            status_color="$YELLOW"
        fi

        if [ -f "${bin}.orig" ]; then
            backup_desc="Presente"
            backup_color="$GREEN"
        else
            backup_desc="Ausente"
            backup_color="$YELLOW"
        fi

        printf "  %-30s %-10s ${status_color}%-25s${NC} ${backup_color}%-12s${NC}\n" "$name" "$size_mb" "$status_desc" "$backup_desc"
    done <<< "$(discover_binaries)"

    if [ "$total_found" -eq 0 ]; then
        echo -e "  ${YELLOW}[AVISO] Nenhum binário Chromium ou Electron foi detectado.${NC}"
    fi

    echo -e "\n${BOLD}2. Automação e Autocura pós-atualização (Pacman Hook):${NC}"
    if [ -f "$PACMAN_HOOK_FILE" ]; then
        echo -e "  • Gancho do Pacman: ${GREEN}[OK] ATIVO${NC} ($PACMAN_HOOK_FILE)"
        runlog_event "ok" "cedilla_hook_active" "$PACMAN_HOOK_FILE"
    else
        echo -e "  • Gancho do Pacman: ${YELLOW}[AVISO] NÃO INSTALADO${NC} (atualizações do pacote vão sobrescrever o patch)"
        runlog_event "warn" "cedilla_hook_missing" ""
    fi

    if [ -f "$SYSTEM_WRAPPER" ] || [ -L "$SYSTEM_WRAPPER" ]; then
        echo -e "  • Wrapper do Sistema: ${GREEN}[OK] INSTALADO${NC} ($SYSTEM_WRAPPER)"
    else
        echo -e "  • Wrapper do Sistema: ${YELLOW}[AVISO] NÃO INSTALADO${NC}"
    fi

    echo ""
    runlog_metric "chromium_apps_total" "$total_found"
    runlog_metric "chromium_apps_patched" "$total_patched"
    runlog_metric "chromium_apps_vulnerable" "$total_vulnerable"

    if [ "$total_vulnerable" -gt 0 ]; then
        echo -e "${YELLOW}Existem $total_vulnerable aplicativo(s) necessitando de correção.${NC}"
        echo -e "Para aplicar o patch e ativar a autocura no pacman:"
        echo -e "  ${BOLD}./bin/linux-wayland-config patch-cedilla --apply${NC}\n"
        return 1
    else
        echo -e "${GREEN}✔ Todos os aplicativos detectados estão com a cedilha corrigida.${NC}\n"
        return 0
    fi
}

cmd_apply() {
    local auto_all=false
    local explicit_targets=()

    while [ $# -gt 0 ]; do
        case "$1" in
            --all|-y|--yes)
                auto_all=true
                shift
                ;;
            *)
                [ -f "$1" ] && explicit_targets+=("$1")
                shift
                ;;
        esac
    done

    echo -e "${BOLD}${BLUE}======================================================${NC}"
    echo -e "${BOLD}${BLUE}   Aplicação do Patch da Cedilha Wayland              ${NC}"
    echo -e "${BOLD}${BLUE}======================================================${NC}"
    echo -e "  ${BLUE}• Motor de patch original por Leandro Cassa (lcassa/chromium-wayland-cedilla-fix)${NC}\n"

    echo -e "${BOLD}==> [1/3] Detectando binários Chromium e Electron instalados...${NC}"
    local discovered=()

    if [ ${#explicit_targets[@]} -gt 0 ]; then
        discovered=("${explicit_targets[@]}")
    elif [ ! -t 0 ]; then
        # Recebeu lista via stdin (ex: pacman hook com NeedsTargets)
        while IFS= read -r line; do
            [ -f "/$line" ] && discovered+=("/$line")
            [ -f "$line" ] && discovered+=("$line")
        done
        auto_all=true
    else
        while IFS= read -r bin; do
            [ -n "$bin" ] && discovered+=("$bin")
        done <<< "$(discover_binaries)"
    fi

    if [ ${#discovered[@]} -eq 0 ]; then
        echo -e "    ${YELLOW}[AVISO] Nenhum binário encontrado para aplicar o patch.${NC}"
        return 0
    fi

    local targets=()

    # Se for execução interativa no terminal sem flag --all / -y, pergunta ao usuário
    if [ "$auto_all" = "false" ] && [ -t 0 ] && [ ${#explicit_targets[@]} -eq 0 ]; then
        echo -e "\nAplicativos encontrados no sistema:\n"
        local i=1
        local vuln_indices=()
        for bin in "${discovered[@]}"; do
            local name status_raw status_desc
            name="$(app_display_name "$bin")"
            status_raw="$(check_binary_status "$bin")"
            if [[ "$status_raw" == PATCHED:* ]]; then
                status_desc="${GREEN}[JÁ CORRIGIDO]${NC}"
            elif [[ "$status_raw" == VULNERABLE:* ]]; then
                status_desc="${RED}[NECESSITA PATCH]${NC}"
                vuln_indices+=("$i")
            else
                status_desc="${YELLOW}[INELIGÍVEL]${NC}"
            fi
            printf "  %2d) %-25s %-32b (%s)\n" "$i" "$name" "$status_desc" "$bin"
            i=$((i + 1))
        done

        echo ""
        echo -e "${BOLD}Escolha quais aplicativos deseja patchear:${NC}"
        echo -e "  • Digite os ${BOLD}números${NC} separados por espaço (ex: 1 2 6)"
        echo -e "  • ${CYAN}'V'${NC} = Aplicar apenas nos que necessitam de patch (${#vuln_indices[@]} apps) [Recomendado]"
        echo -e "  • ${CYAN}'A'${NC} = Aplicar em todos os detectados"
        echo -e "  • ${CYAN}'Q'${NC} = Cancelar sem modificar nada"
        echo ""
        read -r -p "Opção [Padrão: V]: " user_choice
        user_choice="${user_choice:-V}"

        case "$user_choice" in
            [qQ]*)
                echo -e "\n${YELLOW}Operação cancelada pelo usuário.${NC}"
                return 0
                ;;
            [aA]*)
                targets=("${discovered[@]}")
                ;;
            [vV]*)
                for idx in "${vuln_indices[@]}"; do
                    targets+=("${discovered[$((idx - 1))]}")
                done
                ;;
            *)
                for num in $user_choice; do
                    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#discovered[@]}" ]; then
                        targets+=("${discovered[$((num - 1))]}")
                    fi
                done
                ;;
        esac
    else
        targets=("${discovered[@]}")
    fi

    if [ ${#targets[@]} -eq 0 ]; then
        echo -e "    ${YELLOW}[INFO] Nenhum aplicativo selecionado para aplicação.${NC}"
        return 0
    fi

    echo -e "\n${BOLD}==> [2/3] Aplicando patch de bytes nos aplicativos selecionados (${#targets[@]})...${NC}"
    local applied_count=0

    for target in "${targets[@]}"; do
        local name
        name="$(app_display_name "$target")"
        echo -e "  • Processando: ${BOLD}${name}${NC} ($target)"

        if [ ! -w "$target" ] && [ "$EUID" -ne 0 ]; then
            echo -e "    ${YELLOW}[SUDO] O arquivo requer privilégios de root para modificação.${NC}"
            if sudo python3 "$PYTHON_PATCHER" "$target"; then
                applied_count=$((applied_count + 1))
                runlog_event "ok" "cedilla_patched" "$target"
            else
                echo -e "    ${RED}[FALHA] Não foi possível aplicar patch em $target.${NC}"
                runlog_event "fail" "cedilla_patch_failed" "$target"
            fi
        else
            if python3 "$PYTHON_PATCHER" "$target"; then
                applied_count=$((applied_count + 1))
                runlog_event "ok" "cedilla_patched" "$target"
            else
                echo -e "    ${RED}[FALHA] Não foi possível aplicar patch em $target.${NC}"
                runlog_event "fail" "cedilla_patch_failed" "$target"
            fi
        fi
    done

    echo -e "\n${BOLD}==> [3/3] Autocura pós-atualização via Pacman Hook${NC}"
    local want_hook=true

    if [ "$auto_all" = "false" ] && [ -t 0 ]; then
        echo -e "\n${BOLD}Como funciona o gancho do Pacman:${NC}"
        echo -e "  Quando o Google Chrome, Orca IDE ou VS Code forem atualizados via ${BOLD}pacman${NC} ou ${BOLD}paru${NC},"
        echo -e "  o gerenciador de pacotes baixa uma versão nova de fábrica que desfaz o patch da cedilha."
        echo -e "  O gancho em ${BOLD}/etc/pacman.d/hooks/99-cedilla-wayland.hook${NC} reaplica o patch automaticamente"
        echo -e "  apenas nos pacotes atualizados, sem você precisar executar nada manualmente.\n"
        read -r -p "Deseja instalar o gancho do Pacman para manter a autocura? [S/n]: " hook_choice
        hook_choice="${hook_choice:-S}"
        if [[ "$hook_choice" =~ ^[nN] ]]; then
            want_hook=false
            echo -e "  ${BLUE}[INFO] Gancho do Pacman ignorado conforme solicitado.${NC}"
        fi
    fi

    if [ "$want_hook" = "true" ] && [ -d "/etc/pacman.d" ]; then
        local hook_dir="/etc/pacman.d/hooks"
        install_hook() {
            mkdir -p "$hook_dir"
            mkdir -p "/usr/local/bin"

            cat << EOF > "$SYSTEM_WRAPPER"
#!/usr/bin/env bash
# Wrapper de autocura gerado pelo linux-wayland-suite
exec "$SCRIPT_DIR/manage-chromium-cedilla.sh" --apply --yes "\$@"
EOF
            chmod +x "$SYSTEM_WRAPPER"

            cat << 'EOF' > "$PACMAN_HOOK_FILE"
[Trigger]
Operation = Install
Operation = Upgrade
Type = Path
Target = opt/*/*
Target = opt/*/*/*
Target = usr/lib/electron*/electron
Target = usr/lib/chromium/chromium
Target = usr/share/code/code
Target = usr/share/code-insiders/code-insiders
Target = usr/share/vscodium*/codium*

[Action]
Description = [linux-wayland-suite] Autocura da cedilha Wayland em apps Chromium/Electron...
When = PostTransaction
Exec = /usr/local/bin/linux-wayland-patch-cedilla
NeedsTargets
EOF
        }

        if [ "$EUID" -ne 0 ]; then
            echo -e "  • Instalando gancho em $PACMAN_HOOK_FILE via sudo..."
            sudo bash -c "$(declare -f install_hook); SCRIPT_DIR='$SCRIPT_DIR'; SYSTEM_WRAPPER='$SYSTEM_WRAPPER'; PACMAN_HOOK_FILE='$PACMAN_HOOK_FILE'; hook_dir='$hook_dir'; install_hook"
        else
            install_hook
        fi
        echo -e "    ${GREEN}[OK]${NC} Gancho do pacman e wrapper /usr/local/bin instalados com sucesso."
        runlog_event "ok" "cedilla_hook_installed" "$PACMAN_HOOK_FILE"
    elif [ "$want_hook" = "true" ]; then
        echo -e "    ${BLUE}[INFO]${NC} Diretório /etc/pacman.d ausente (distro não-Arch? Hook do pacman ignorado)."
    fi

    echo -e "\n${GREEN}✔ Concluído!${NC}"
    echo -e "Reinicie os aplicativos modificados para que a cedilha (' + c -> ç) entre em vigor.\n"
}

cmd_revert() {
    echo -e "${BOLD}${BLUE}======================================================${NC}"
    echo -e "${BOLD}${BLUE}   Revertendo Patch da Cedilha nos Binários           ${NC}"
    echo -e "${BOLD}${BLUE}======================================================${NC}\n"

    local reverted_count=0
    while IFS= read -r bin; do
        [ -z "$bin" ] && continue
        if [ -f "${bin}.orig" ]; then
            local name
            name="$(app_display_name "$bin")"
            echo -e "  • Restaurando: ${BOLD}${name}${NC} ($bin)"

            restore_cmd="cp -p \"${bin}.orig\" \"$bin\" && rm -f \"${bin}.orig\" \"${bin}\".bak-*"
            if [ ! -w "$bin" ] && [ "$EUID" -ne 0 ]; then
                sudo bash -c "$restore_cmd"
            else
                bash -c "$restore_cmd"
            fi
            reverted_count=$((reverted_count + 1))
            runlog_event "ok" "cedilla_reverted" "$bin"
            echo -e "    ${GREEN}[OK]${NC} Binário original restaurado com sucesso."
        fi
    done <<< "$(discover_binaries)"

    if [ -f "$PACMAN_HOOK_FILE" ]; then
        echo -e "\n  • Removendo gancho do pacman ($PACMAN_HOOK_FILE)..."
        if [ "$EUID" -ne 0 ]; then
            sudo rm -f "$PACMAN_HOOK_FILE" "$SYSTEM_WRAPPER"
        else
            rm -f "$PACMAN_HOOK_FILE" "$SYSTEM_WRAPPER"
        fi
        echo -e "    ${GREEN}[OK]${NC} Gancho e wrapper removidos."
        runlog_event "ok" "cedilla_hook_removed" ""
    fi

    echo -e "\n${GREEN}✔ Reversão concluída ($reverted_count binários restaurados).${NC}\n"
}

case "${1:-status}" in
    --apply|-a|apply)
        shift 1 || true
        cmd_apply "$@"
        ;;
    --revert|-r|revert)
        shift 1 || true
        cmd_revert "$@"
        ;;
    --discover|discover)
        discover_binaries
        ;;
    --status|-s|status)
        cmd_status
        ;;
    --help|-h|help)
        echo "Uso: $0 [--status | --apply | --revert | --discover]"
        echo "  --status   Inspeciona e reporta o estado de todos os binários detectados"
        echo "  --apply    Aplica o patch de bytes e instala o hook do pacman (requer sudo)"
        echo "  --revert   Restaura os binários originais a partir do backup .orig e remove o hook"
        echo "  --discover Imprime os caminhos dos binários detectados (um por linha)"
        ;;
    *)
        cmd_status
        ;;
esac
