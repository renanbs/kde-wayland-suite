#!/usr/bin/env bash
# ==============================================================================
# terminal-fetch.sh — Gerenciador Cosmético de Identidade do Terminal (Fastfetch)
#
# Comportamento:
# - Detecta o ambiente do sistema (Garuda Linux / Arch Linux) e Fastfetch.
# - Identifica e audita os shells instalados no sistema (Fish, Zsh, Bash).
# - Permite alternar entre logos e imagens gráficas via Kitty graphics protocol:
#   * Águia low-poly neon Dr460nized (garuda-purple.png)
#   * Gato Mascote Mokka (mokka-fastfetch.png)
#   * Emblema 'G' Hexagonal Neon (garudalinux-logo.png)
#   * Dragão ASCII Dr460nized (GarudaDragon nativo)
#   * Garuda ASCII Clássico (Garuda nativo)
#   * Imagem customizada fornecida pelo usuário
# - Sincroniza opcionalmente múltiplos shells (Fish, Zsh, Bash) com a mesma identidade.
# - Suporta reversão atômica para os padrões da distribuição ou backups anteriores.
#
# Modos de Uso:
#   --status              Audita o estado atual da configuração do terminal e shells
#   --list-logos          Lista os logos e imagens disponíveis no sistema
#   --menu                Exibe menu interativo para seleção visual e de shells
#   --apply               Aplica configuração (padrão: eagle ou --logo <id|caminho>)
#   --logo <id|path>      Especifica o logo ao usar --apply
#   --shells <csv|all>    Especifica os shells para aplicar (ex: all ou fish,zsh,bash)
#   --all-shells          Aplica a todos os shells instalados detectados
#   --revert              Restaura a configuração padrão ou backups anteriores
# ==============================================================================
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FASTFETCH_USER_DIR="${HOME}/.config/fastfetch"
FASTFETCH_USER_CONFIG="${FASTFETCH_USER_DIR}/config.jsonc"
FASTFETCH_BACKUP_CONFIG="${FASTFETCH_USER_DIR}/config.jsonc.bak"

FISH_USER_DIR="${HOME}/.config/fish"
FISH_USER_CONFIG="${FISH_USER_DIR}/config.fish"
FISH_BACKUP_CONFIG="${FISH_USER_DIR}/config.fish.bak"

ZSH_USER_CONFIG="${HOME}/.zshrc"
ZSH_BACKUP_CONFIG="${HOME}/.zshrc.bak"

BASH_USER_CONFIG="${HOME}/.bashrc"
BASH_BACKUP_CONFIG="${HOME}/.bashrc.bak"

MOKKA_PRESET="/usr/share/fastfetch/presets/mokka.jsonc"
NEOFETCH_PRESET="/usr/share/fastfetch/presets/neofetch.jsonc"
GARUDA_FISH_SYS="/usr/share/garuda/garuda-fish-config/config.fish"

# Caminhos canônicos de imagens do Garuda
IMG_EAGLE="/usr/share/icons/garuda/garuda-purple.png"
IMG_CAT="/usr/share/icons/garuda/mokka-fastfetch.png"
IMG_EMBLEM="/usr/share/pixmaps/garudalinux-logo.png"

# Registro estruturado do run
if [ -f "$SCRIPT_DIR/lib-runlog.sh" ]; then
    # shellcheck source=lib-runlog.sh
    source "$SCRIPT_DIR/lib-runlog.sh"
else
    runlog_event() { :; }
    runlog_metric() { :; }
fi

detect_os() {
    local os_id=""
    local os_like=""
    if [ -f /etc/os-release ]; then
        os_id="$(grep -E '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"' || true)"
        os_like="$(grep -E '^ID_LIKE=' /etc/os-release | cut -d= -f2 | tr -d '"' || true)"
    fi

    if [[ "$os_id" == "garuda" ]]; then
        echo "garuda"
    elif [[ "$os_id" == "arch" || "$os_like" =~ arch ]]; then
        echo "arch"
    else
        echo "other"
    fi
}

detect_installed_shells() {
    local shells=()
    if command -v fish &>/dev/null && [ -f "$FISH_USER_CONFIG" ]; then
        shells+=("fish")
    fi
    if command -v zsh &>/dev/null && [ -f "$ZSH_USER_CONFIG" ]; then
        shells+=("zsh")
    fi
    if command -v bash &>/dev/null && [ -f "$BASH_USER_CONFIG" ]; then
        shells+=("bash")
    fi
    echo "${shells[*]}"
}

detect_active_logo() {
    if [ ! -f "$FASTFETCH_USER_CONFIG" ]; then
        if [ -f "$MOKKA_PRESET" ]; then
            echo "cat (sistema Mokka default)"
        else
            echo "dragon-ascii (sistema default)"
        fi
        return
    fi

    local src
    src="$(grep -E '"source":' "$FASTFETCH_USER_CONFIG" | head -n1 | sed -E 's/.*"source":[[:space:]]*"([^"]*)".*/\1/' || true)"

    if [[ "$src" == *garuda-purple.png* ]]; then
        echo "eagle (Águia Neon Dr460nized)"
    elif [[ "$src" == *mokka-fastfetch.png* ]]; then
        echo "cat (Gato Mokka)"
    elif [[ "$src" == *garudalinux-logo* ]]; then
        echo "emblem (Emblema 'G' Hexagonal)"
    elif [[ "$src" == "GarudaDragon" ]]; then
        echo "dragon-ascii (Dragão ASCII)"
    elif [[ "$src" == "Garuda" ]]; then
        echo "garuda-ascii (Garuda ASCII)"
    elif [ -n "$src" ]; then
        echo "custom ($src)"
    else
        echo "builtin-default"
    fi
}

generate_fastfetch_config() {
    local logo_type="$1"
    local logo_source="$2"
    local logo_width="$3"

    cat <<EOF
{
  "\$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "type": "${logo_type}",
    "source": "${logo_source}",
    "width": ${logo_width}
  },
  "display": {
    "separator": " "
  },
  "modules": [
    {
      "type": "title",
      "keyWidth": 10
    },
    {
      "type": "os",
      "key": " OS",
      "keyColor": "yellow"
    },
    {
      "type": "kernel",
      "key": "├ Kernel",
      "keyColor": "yellow"
    },
    {
      "type": "packages",
      "key": "├󰏖 Packages",
      "keyColor": "yellow"
    },
    {
      "type": "shell",
      "key": "├ Shell",
      "keyColor": "yellow"
    },
    {
      "type": "command",
      "key": "└ Age",
      "keyColor": "yellow",
      "text": "birth_install=\$(stat -c %W /); current=\$(date +%s); time_progression=\$((current - birth_install)); days_difference=\$((time_progression / 86400)); echo \$days_difference days"
    },
    "break",
    {
      "type": "de",
      "key": " DE",
      "keyColor": "blue"
    },
    {
      "type": "wm",
      "key": "├󰧨 Window Manager",
      "keyColor": "blue"
    },
    {
      "type": "lm",
      "key": "├󰧨 Login Manager",
      "keyColor": "blue"
    },
    {
      "type": "wmtheme",
      "key": "├󰉼 WM Theme",
      "keyColor": "blue"
    },
    {
      "type": "theme",
      "format": "{1}",
      "key": "├󰉼 Color Themes",
      "keyColor": "blue"
    },
    {
      "type": "icons",
      "format": "{1}",
      "key": "├󰀻 System Icons",
      "keyColor": "blue"
    },
    {
      "type": "font",
      "format": "{?1}{1} [Qt]{?}{/1}Unknown",
      "key": "├ System Fonts",
      "keyColor": "blue"
    },
    {
      "type": "terminal",
      "key": "└ Terminal",
      "keyColor": "blue"
    },
    "break",
    {
      "type": "chassis",
      "key": "󰌢 PC",
      "keyColor": "green"
    },
    {
      "type": "cpu",
      "key": "├󰻠 CPU",
      "keyColor": "green"
    },
    {
      "type": "gpu",
      "key": "├󰍛 GPU",
      "keyColor": "green"
    },
    {
      "type": "opengl",
      "key": "├󰍛 OpenGL",
      "keyColor": "green"
    },
    {
      "type": "vulkan",
      "key": "├󰍛 Vulkan",
      "keyColor": "green"
    },
    {
      "type": "display",
      "key": "└󰍹 Display(s)",
      "keyColor": "green"
    }
  ]
}
EOF
}

cmd_status() {
    local os_detected
    os_detected="$(detect_os)"

    echo -e "${BOLD}=== Diagnóstico Cosmético do Terminal (Fastfetch) ===${NC}"
    echo -e "Sistema Operacional: ${CYAN}${os_detected}${NC}"

    if ! command -v fastfetch &>/dev/null; then
        echo -e "Fastfetch: ${RED}Não instalado${NC}"
        runlog_event "warn" "terminal_fetch_status" "fastfetch_missing"
        return 1
    fi

    local ff_version
    ff_version="$(fastfetch --version 2>/dev/null | head -n1 || echo 'instalado')"
    echo -e "Fastfetch: ${GREEN}${ff_version}${NC}"

    local active_logo
    active_logo="$(detect_active_logo)"
    echo -e "Logo Ativo: ${GREEN}${active_logo}${NC}"

    echo -e "\n${BOLD}Arquivos de Configuração:${NC}"
    if [ -f "$FASTFETCH_USER_CONFIG" ]; then
        echo -e "  [OK] Usuário Fastfetch: ${CYAN}${FASTFETCH_USER_CONFIG}${NC}"
    else
        echo -e "  [--] Usuário Fastfetch: ${YELLOW}Não criado (usando padrão do sistema)${NC}"
    fi

    if [ -f "$FASTFETCH_BACKUP_CONFIG" ]; then
        echo -e "  [OK] Backup Fastfetch:  ${GREEN}${FASTFETCH_BACKUP_CONFIG}${NC}"
    fi

    echo -e "\n${BOLD}Status dos Shells Instalados:${NC}"
    # Fish
    if command -v fish &>/dev/null && [ -f "$FISH_USER_CONFIG" ]; then
        if grep -q "function __garuda_fastfetch" "$FISH_USER_CONFIG"; then
            echo -e "  • ${GREEN}[OK] Fish:${NC} ${FISH_USER_CONFIG} (override ativo para fastfetch de usuário)"
        else
            echo -e "  • ${YELLOW}[--] Fish:${NC} ${FISH_USER_CONFIG} (usando hook padrão do sistema / mokka)"
        fi
    fi

    # Zsh
    if command -v zsh &>/dev/null && [ -f "$ZSH_USER_CONFIG" ]; then
        if grep -q "fastfetch --config mokka" "$ZSH_USER_CONFIG"; then
            echo -e "  • ${YELLOW}[AVISO] Zsh:${NC} ${ZSH_USER_CONFIG} (forçando preset Mokka; ignore config de usuário)"
        elif grep -q "fastfetch" "$ZSH_USER_CONFIG"; then
            echo -e "  • ${GREEN}[OK] Zsh:${NC} ${ZSH_USER_CONFIG} (chamada de fastfetch de usuário ativa)"
        else
            echo -e "  • ${BLUE}[INFO] Zsh:${NC} ${ZSH_USER_CONFIG} (sem chamada automática de fastfetch)"
        fi
    fi

    # Bash
    if command -v bash &>/dev/null && [ -f "$BASH_USER_CONFIG" ]; then
        if grep -q "fastfetch" "$BASH_USER_CONFIG"; then
            echo -e "  • ${GREEN}[OK] Bash:${NC} ${BASH_USER_CONFIG} (chamada de fastfetch de usuário ativa)"
        else
            echo -e "  • ${BLUE}[INFO] Bash:${NC} ${BASH_USER_CONFIG} (sem chamada automática de fastfetch)"
        fi
    fi

    echo -e "\n${BOLD}Imagens Locais Disponíveis:${NC}"
    [ -f "$IMG_EAGLE" ] && echo -e "  - Águia Neon Dr460nized: ${GREEN}Presente${NC} ($IMG_EAGLE)" || echo -e "  - Águia Neon: ${RED}Ausente${NC}"
    [ -f "$IMG_CAT" ] && echo -e "  - Gato Mascote Mokka:    ${GREEN}Presente${NC} ($IMG_CAT)" || echo -e "  - Gato Mascote Mokka: ${YELLOW}Ausente${NC}"
    [ -f "$IMG_EMBLEM" ] && echo -e "  - Emblema 'G' Hexagonal: ${GREEN}Presente${NC} ($IMG_EMBLEM)" || echo -e "  - Emblema 'G': ${YELLOW}Ausente${NC}"

    runlog_event "ok" "terminal_fetch_status" "active=$active_logo"
    return 0
}

cmd_list_logos() {
    echo -e "${BOLD}Logos e Estilos Disponíveis:${NC}\n"
    printf "  %-15s %-30s %s\n" "ID" "TIPO" "DESCRIÇÃO"
    printf "  %-15s %-30s %s\n" "---------------" "------------------------------" "----------------------------------------"
    printf "  %-15s %-30s %s\n" "eagle" "Kitty Image (PNG)" "Águia low-poly Dr460nized neon roxo/magenta"
    printf "  %-15s %-30s %s\n" "cat" "Kitty Image (PNG)" "Gato mascote pastel da edição Garuda Mokka"
    printf "  %-15s %-30s %s\n" "emblem" "Kitty Image (PNG)" "Emblema 'G' hexagonal moderno do Garuda"
    printf "  %-15s %-30s %s\n" "dragon-ascii" "Built-in ASCII Art" "Dragão Dr460nized clássico em texto ANSI"
    printf "  %-15s %-30s %s\n" "garuda-ascii" "Built-in ASCII Art" "Garuda clássico em texto ANSI"
    printf "  %-15s %-30s %s\n" "<caminho.png>" "Custom Image (PNG/SVG)" "Qualquer imagem local fornecida pelo usuário"
}

apply_shell_fish() {
    [ -f "$FISH_USER_CONFIG" ] || return 0
    echo -e "${BLUE}[*] Sincronizando Shell Fish (${FISH_USER_CONFIG})...${NC}"

    if ! grep -q "function __garuda_fastfetch" "$FISH_USER_CONFIG"; then
        [ -f "$FISH_BACKUP_CONFIG" ] || cp -a "$FISH_USER_CONFIG" "$FISH_BACKUP_CONFIG"
        cat >> "$FISH_USER_CONFIG" << 'EOF'

# Override do fastfetch do usuário (linux-wayland-suite terminal-fetch)
function __garuda_fastfetch
    if status --is-interactive && type -q fastfetch
        fastfetch
    end
end
EOF
        echo -e "  [+] Hook inserido em: ${GREEN}${FISH_USER_CONFIG}${NC}"
    else
        echo -e "  [✔] Hook já configurado em: ${CYAN}${FISH_USER_CONFIG}${NC}"
    fi
}

apply_shell_zsh() {
    [ -f "$ZSH_USER_CONFIG" ] || return 0
    echo -e "${BLUE}[*] Sincronizando Shell Zsh (${ZSH_USER_CONFIG})...${NC}"

    [ -f "$ZSH_BACKUP_CONFIG" ] || cp -a "$ZSH_USER_CONFIG" "$ZSH_BACKUP_CONFIG"

    if grep -q "fastfetch --config mokka" "$ZSH_USER_CONFIG"; then
        # Substitui a chamada forçada de mokka pela chamada limpa de usuário
        sed -i 's/fastfetch --config mokka --logo-type kitty/fastfetch/g' "$ZSH_USER_CONFIG"
        sed -i 's/fastfetch --config mokka/fastfetch/g' "$ZSH_USER_CONFIG"
        echo -e "  [+] Substituído override forçado de Mokka por 'fastfetch' limpo em: ${GREEN}${ZSH_USER_CONFIG}${NC}"
    elif ! grep -q "fastfetch" "$ZSH_USER_CONFIG"; then
        cat >> "$ZSH_USER_CONFIG" << 'EOF'

# Fastfetch visual identity (linux-wayland-suite terminal-fetch)
if [[ -o interactive ]] && command -v fastfetch &>/dev/null; then
    fastfetch
fi
EOF
        echo -e "  [+] Hook interativo de fastfetch inserido em: ${GREEN}${ZSH_USER_CONFIG}${NC}"
    else
        echo -e "  [✔] Chamada de fastfetch já presente em: ${CYAN}${ZSH_USER_CONFIG}${NC}"
    fi
}

apply_shell_bash() {
    [ -f "$BASH_USER_CONFIG" ] || return 0
    echo -e "${BLUE}[*] Sincronizando Shell Bash (${BASH_USER_CONFIG})...${NC}"

    if ! grep -q "fastfetch" "$BASH_USER_CONFIG"; then
        [ -f "$BASH_BACKUP_CONFIG" ] || cp -a "$BASH_USER_CONFIG" "$BASH_BACKUP_CONFIG"
        cat >> "$BASH_USER_CONFIG" << 'EOF'

# Fastfetch visual identity (linux-wayland-suite terminal-fetch)
if [[ $- == *i* ]] && command -v fastfetch &>/dev/null; then
    fastfetch
fi
EOF
        echo -e "  [+] Hook interativo de fastfetch inserido em: ${GREEN}${BASH_USER_CONFIG}${NC}"
    else
        echo -e "  [✔] Chamada de fastfetch já presente em: ${CYAN}${BASH_USER_CONFIG}${NC}"
    fi
}

revert_shell_fish() {
    [ -f "$FISH_USER_CONFIG" ] || return 0
    if grep -q "function __garuda_fastfetch" "$FISH_USER_CONFIG"; then
        local tmp_fish
        tmp_fish="$(mktemp)"
        python3 -c "
import sys
content = open('$FISH_USER_CONFIG').read()
marker = '# Override do fastfetch do usuário'
if marker in content:
    idx = content.find(marker)
    open('$tmp_fish', 'w').write(content[:idx].rstrip() + '\n')
else:
    open('$tmp_fish', 'w').write(content)
"
        mv "$tmp_fish" "$FISH_USER_CONFIG"
        echo -e "  [+] Hook de override removido de: ${GREEN}${FISH_USER_CONFIG}${NC}"
    fi
    if [ -f "$FISH_BACKUP_CONFIG" ]; then
        rm -f "$FISH_BACKUP_CONFIG"
    fi
}

revert_shell_zsh() {
    [ -f "$ZSH_USER_CONFIG" ] || return 0
    if [ -f "$ZSH_BACKUP_CONFIG" ]; then
        cp -a "$ZSH_BACKUP_CONFIG" "$ZSH_USER_CONFIG"
        rm -f "$ZSH_BACKUP_CONFIG"
        echo -e "  [+] Backup restaurado para Zsh: ${GREEN}${ZSH_USER_CONFIG}${NC}"
    elif grep -q "linux-wayland-suite terminal-fetch" "$ZSH_USER_CONFIG"; then
        local tmp_zsh
        tmp_zsh="$(mktemp)"
        python3 -c "
import sys
content = open('$ZSH_USER_CONFIG').read()
marker = '# Fastfetch visual identity'
if marker in content:
    idx = content.find(marker)
    open('$tmp_zsh', 'w').write(content[:idx].rstrip() + '\n')
else:
    open('$tmp_zsh', 'w').write(content)
"
        mv "$tmp_zsh" "$ZSH_USER_CONFIG"
        echo -e "  [+] Hook removido de: ${GREEN}${ZSH_USER_CONFIG}${NC}"
    fi
}

revert_shell_bash() {
    [ -f "$BASH_USER_CONFIG" ] || return 0
    if [ -f "$BASH_BACKUP_CONFIG" ]; then
        cp -a "$BASH_BACKUP_CONFIG" "$BASH_USER_CONFIG"
        rm -f "$BASH_BACKUP_CONFIG"
        echo -e "  [+] Backup restaurado para Bash: ${GREEN}${BASH_USER_CONFIG}${NC}"
    elif grep -q "linux-wayland-suite terminal-fetch" "$BASH_USER_CONFIG"; then
        local tmp_bash
        tmp_bash="$(mktemp)"
        python3 -c "
import sys
content = open('$BASH_USER_CONFIG').read()
marker = '# Fastfetch visual identity'
if marker in content:
    idx = content.find(marker)
    open('$tmp_bash', 'w').write(content[:idx].rstrip() + '\n')
else:
    open('$tmp_bash', 'w').write(content)
"
        mv "$tmp_bash" "$BASH_USER_CONFIG"
        echo -e "  [+] Hook removido de: ${GREEN}${BASH_USER_CONFIG}${NC}"
    fi
}

cmd_apply() {
    local logo="${1:-eagle}"
    local target_shells="${2:-all}"
    local os_detected
    os_detected="$(detect_os)"

    if [[ "$os_detected" == "other" ]] && ! command -v fastfetch &>/dev/null; then
        echo -e "${RED}[X] Sistema incompatível ou Fastfetch ausente.${NC}"
        runlog_event "skip" "terminal_fetch_apply" "unsupported"
        return 1
    fi

    local logo_type="kitty"
    local logo_source=""
    local logo_width=40

    case "$logo" in
        eagle)
            if [ ! -f "$IMG_EAGLE" ]; then
                echo -e "${RED}[X] Imagem da águia não encontrada em: $IMG_EAGLE${NC}"
                return 1
            fi
            logo_type="kitty"
            logo_source="$IMG_EAGLE"
            logo_width=40
            ;;
        cat)
            if [ ! -f "$IMG_CAT" ]; then
                echo -e "${RED}[X] Imagem do gato Mokka não encontrada em: $IMG_CAT${NC}"
                return 1
            fi
            logo_type="kitty"
            logo_source="$IMG_CAT"
            logo_width=40
            ;;
        emblem)
            if [ ! -f "$IMG_EMBLEM" ]; then
                echo -e "${RED}[X] Imagem do emblema não encontrada em: $IMG_EMBLEM${NC}"
                return 1
            fi
            logo_type="kitty"
            logo_source="$IMG_EMBLEM"
            logo_width=38
            ;;
        dragon-ascii)
            logo_type="builtin"
            logo_source="GarudaDragon"
            logo_width=0
            ;;
        garuda-ascii)
            logo_type="builtin"
            logo_source="Garuda"
            logo_width=0
            ;;
        *)
            if [ -f "$logo" ]; then
                logo_type="kitty"
                logo_source="$(realpath "$logo")"
                logo_width=40
            else
                echo -e "${RED}[X] Opção ou arquivo de imagem inválido: $logo${NC}"
                cmd_list_logos
                return 1
            fi
            ;;
    esac

    echo -e "${BLUE}[*] Configurando identidade do terminal: ${BOLD}${logo}${NC}..."

    mkdir -p "$FASTFETCH_USER_DIR"

    # Backup atômico do config.jsonc se existir
    if [ -f "$FASTFETCH_USER_CONFIG" ] && [ ! -f "$FASTFETCH_BACKUP_CONFIG" ]; then
        cp -a "$FASTFETCH_USER_CONFIG" "$FASTFETCH_BACKUP_CONFIG"
        echo -e "  [+] Backup criado: ${CYAN}${FASTFETCH_BACKUP_CONFIG}${NC}"
    fi

    # Gerar nova configuração do Fastfetch
    generate_fastfetch_config "$logo_type" "$logo_source" "$logo_width" > "$FASTFETCH_USER_CONFIG"
    echo -e "  [+] Configuração aplicada: ${GREEN}${FASTFETCH_USER_CONFIG}${NC}"

    # Aplicar aos shells solicitados
    local installed
    installed="$(detect_installed_shells)"

    if [[ "$target_shells" == "all" ]]; then
        [[ " $installed " =~ " fish " ]] && apply_shell_fish
        [[ " $installed " =~ " zsh " ]] && apply_shell_zsh
        [[ " $installed " =~ " bash " ]] && apply_shell_bash
    else
        IFS=',' read -ra shell_arr <<< "$target_shells"
        for sh_name in "${shell_arr[@]}"; do
            case "$sh_name" in
                fish) apply_shell_fish ;;
                zsh) apply_shell_zsh ;;
                bash) apply_shell_bash ;;
            esac
        done
    fi

    runlog_event "ok" "terminal_fetch_applied" "logo=$logo;source=$logo_source;shells=$target_shells"
    echo -e "${GREEN}[OK] Identidade visual do terminal atualizada com sucesso para '${logo}'!${NC}"
    echo -e "Abra uma nova aba do terminal ou execute ${BOLD}fastfetch${NC} para conferir."
}

cmd_revert() {
    echo -e "${BLUE}[*] Revertendo customizações do terminal para os padrões do sistema...${NC}"

    if [ -f "$FASTFETCH_BACKUP_CONFIG" ]; then
        mv -f "$FASTFETCH_BACKUP_CONFIG" "$FASTFETCH_USER_CONFIG"
        echo -e "  [+] Backup restaurado: ${GREEN}${FASTFETCH_USER_CONFIG}${NC}"
    elif [ -f "$FASTFETCH_USER_CONFIG" ]; then
        rm -f "$FASTFETCH_USER_CONFIG"
        echo -e "  [+] Removido override de usuário: ${YELLOW}${FASTFETCH_USER_CONFIG}${NC}"
    fi

    revert_shell_fish
    revert_shell_zsh
    revert_shell_bash

    runlog_event "ok" "terminal_fetch_reverted" "restored"
    echo -e "${GREEN}[OK] Reversão concluída com sucesso em todos os shells!${NC}"
}

cmd_menu() {
    echo -e "${BOLD}====================================================${NC}"
    echo -e "${CYAN}${BOLD}   Menu Cosmético de Identidade do Terminal   ${NC}"
    echo -e "${BOLD}====================================================${NC}"
    echo -e "Escolha o estilo de logo para o seu Fastfetch / terminal:\n"

    echo -e "  ${BOLD}1)${NC} Águia low-poly Dr460nized Neon (PNG / Kitty) [Recomendado Dr460nized]"
    echo -e "  ${BOLD}2)${NC} Gato Mascote Mokka (PNG / Kitty)              [Tema Mokka original]"
    echo -e "  ${BOLD}3)${NC} Emblema 'G' Hexagonal Neon (PNG / Kitty)       [Garuda Moderno]"
    echo -e "  ${BOLD}4)${NC} Dragão Dr460nized em ASCII                    [Arte de texto clássica]"
    echo -e "  ${BOLD}5)${NC} Garuda clássico em ASCII                      [Arte de texto]"
    echo -e "  ${BOLD}6)${NC} Imagem personalizada (inserir caminho do PNG/SVG)"
    echo -e "  ${BOLD}7)${NC} Reverter para o padrão do sistema"
    echo -e "  ${BOLD}0)${NC} Sair sem alterar\n"

    read -rp "Digite o número da opção desejada [0-7]: " opt

    local chosen_logo=""
    case "$opt" in
        1) chosen_logo="eagle" ;;
        2) chosen_logo="cat" ;;
        3) chosen_logo="emblem" ;;
        4) chosen_logo="dragon-ascii" ;;
        5) chosen_logo="garuda-ascii" ;;
        6)
            read -rp "Digite o caminho completo da imagem: " custom_img
            chosen_logo="$custom_img"
            ;;
        7) cmd_revert; return 0 ;;
        0|*) echo "Operação cancelada."; return 0 ;;
    esac

    # Pergunta sobre sincronização de shells
    local installed
    installed="$(detect_installed_shells)"

    echo -e "\n${BOLD}Shells detectados no sistema:${NC} ${CYAN}${installed}${NC}"
    echo -e "Deseja sincronizar a inicialização do Fastfetch nos outros shells?"
    echo -e "  ${BOLD}1)${NC} Sim, sincronizar todos os shells instalados (${installed}) [Recomendado]"
    echo -e "  ${BOLD}2)${NC} Apenas no shell ativo atual"
    echo -e "  ${BOLD}3)${NC} Apenas gerar o Fastfetch sem alterar os arquivos RC dos shells\n"

    read -rp "Escolha a opção de sincronização [1-3] (padrão: 1): " sh_opt
    sh_opt="${sh_opt:-1}"

    case "$sh_opt" in
        1) cmd_apply "$chosen_logo" "all" ;;
        2)
            local current_sh
            current_sh="$(basename "${SHELL:-fish}")"
            cmd_apply "$chosen_logo" "$current_sh"
            ;;
        3)
            cmd_apply "$chosen_logo" "none"
            ;;
        *)
            cmd_apply "$chosen_logo" "all"
            ;;
    esac
}

usage() {
    echo "Uso: $(basename "$0") [--status | --menu | --list-logos | --apply [--logo <id|caminho>] [--shells <all|fish,zsh,bash>] | --revert]"
    exit 1
}

main() {
    local action="status"
    local logo="eagle"
    local target_shells="all"

    if [[ $# -eq 0 ]]; then
        if [ -t 0 ]; then
            action="menu"
        else
            action="status"
        fi
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --status)
                action="status"
                shift
                ;;
            --menu)
                action="menu"
                shift
                ;;
            --list-logos)
                action="list"
                shift
                ;;
            --apply)
                action="apply"
                shift
                ;;
            --logo)
                logo="$2"
                shift 2
                ;;
            --shells)
                target_shells="$2"
                shift 2
                ;;
            --all-shells)
                target_shells="all"
                shift
                ;;
            --revert)
                action="revert"
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo -e "${RED}Argumento desconhecido: $1${NC}"
                usage
                ;;
        esac
    done

    case "$action" in
        status) cmd_status ;;
        list) cmd_list_logos ;;
        menu) cmd_menu ;;
        apply) cmd_apply "$logo" "$target_shells" ;;
        revert) cmd_revert ;;
    esac
}

main "$@"
