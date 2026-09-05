#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# configure-mouse.sh — Configuração do Logitech MX Master 3S no KDE Plasma 6 Wayland
# Instala/gera config do logiops (logid) com botão de gesto -> troca de workspace
# e overview, e SmartShift fixo no modo de rolagem livre.
# ==============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

LOGID_CFG="$HOME/.config/logid.cfg"
LOGID_CFG_SYSTEM="/etc/logid.cfg"

echo -e "${BOLD}==> [1/5] Verificando instalação do logiops (logid)...${NC}"
if command -v logid >/dev/null 2>&1; then
    echo -e "    ${GREEN}[OK]${NC} logid já instalado ($(logid --version 2>&1 | head -1))."
else
    echo -e "    ${YELLOW}logid não encontrado.${NC}"

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO="${ID:-unknown}"
        DISTRO_LIKE="${ID_LIKE:-}"
    else
        DISTRO="unknown"
        DISTRO_LIKE=""
    fi

    if [ "$DISTRO" = "arch" ] || [ "$DISTRO_LIKE" = "arch" ] || [ "$DISTRO" = "garuda" ]; then
        if command -v paru >/dev/null 2>&1; then
            AUR_HELPER="paru"
        elif command -v yay >/dev/null 2>&1; then
            AUR_HELPER="yay"
        else
            echo -e "    ${RED}Erro: distro baseada em Arch detectada, mas nenhum helper AUR (paru/yay) foi encontrado.${NC}"
            echo -e "    ${RED}Instale um helper AUR (ex: 'sudo pacman -S paru') e rode este comando de novo,${NC}"
            echo -e "    ${RED}ou instale 'logiops' manualmente: https://github.com/PixlOne/logiops${NC}"
            exit 1
        fi

        echo -e "    ${YELLOW}Instalando 'logiops' via $AUR_HELPER...${NC}"
        if ! "$AUR_HELPER" -S --noconfirm logiops; then
            echo -e "    ${RED}Erro: falha ao instalar 'logiops' via $AUR_HELPER. Veja a saída acima para detalhes.${NC}"
            exit 1
        fi
    else
        echo -e "    ${RED}Erro: 'logiops' não está disponível via gerenciador de pacotes nesta distro ($DISTRO).${NC}"
        echo -e "    ${RED}Compile e instale manualmente a partir de: https://github.com/PixlOne/logiops${NC}"
        echo -e "    ${RED}Depois rode este comando de novo para aplicar a configuração do MX Master 3S.${NC}"
        exit 1
    fi

    if ! command -v logid >/dev/null 2>&1; then
        echo -e "    ${RED}Erro: instalação concluída, mas o binário 'logid' ainda não foi encontrado no PATH.${NC}"
        exit 1
    fi
    echo -e "    ${GREEN}[OK]${NC} logid instalado com sucesso ($(logid --version 2>&1 | head -1))."
fi

echo -e "${BOLD}==> [2/5] Gravando $LOGID_CFG (botão de gesto e SmartShift)...${NC}"
mkdir -p "$HOME/.config"
if [ -f "$LOGID_CFG" ] && [ ! -L "$LOGID_CFG" ]; then
    cp "$LOGID_CFG" "${LOGID_CFG}.bak_$(date +%Y%m%d_%H%M%S)"
fi

cat << 'EOF' > "$LOGID_CFG"
devices: (
    {
        name: "MX Master 3S";

        // SmartShift desligado = roda sempre no modo livre (sem "travinhas").
        // O modo é fixado manualmente pelo botão físico embaixo da roda.
        smartshift: {
            on: false;
        };

        hiresscroll: {
            hires: true;
            invert: false;
            target: false;
        };

        dpi: 1000;

        buttons: (
            // Gesture button (botão grande sob o polegar, cid 0xc3)
            // tap/cima = Meta+W (Overview), baixo = Meta+D (Mostrar Área de Trabalho),
            // esquerda/direita = trocar workspace (Meta+Ctrl+Left/Right, sem mover a janela ativa)
            {
                cid: 0xc3;
                action = {
                    type: "Gestures";
                    gestures: (
                        {
                            direction: "Up";
                            mode: "OnRelease";
                            action = {
                                type: "Keypress";
                                keys: ["KEY_LEFTMETA", "KEY_W"];
                            };
                        },
                        {
                            direction: "Down";
                            mode: "OnRelease";
                            action = {
                                type: "Keypress";
                                keys: ["KEY_LEFTMETA", "KEY_D"];
                            };
                        },
                        {
                            direction: "Left";
                            mode: "OnRelease";
                            action = {
                                type: "Keypress";
                                keys: ["KEY_LEFTMETA", "KEY_LEFTCTRL", "KEY_LEFT"];
                            };
                        },
                        {
                            direction: "Right";
                            mode: "OnRelease";
                            action = {
                                type: "Keypress";
                                keys: ["KEY_LEFTMETA", "KEY_LEFTCTRL", "KEY_RIGHT"];
                            };
                        },
                        {
                            direction: "None";
                            mode: "OnRelease";
                            action = {
                                type: "Keypress";
                                keys: ["KEY_LEFTMETA", "KEY_W"];
                            };
                        }
                    );
                };
            }
        );
    }
);
EOF
echo -e "    ${GREEN}[OK]${NC} $LOGID_CFG gravado."

echo -e "${BOLD}==> [3/5] Linkando $LOGID_CFG_SYSTEM -> $LOGID_CFG (requer sudo)...${NC}"
sudo ln -sf "$LOGID_CFG" "$LOGID_CFG_SYSTEM"
echo -e "    ${GREEN}[OK]${NC} Link simbólico criado."

echo -e "${BOLD}==> [4/5] Habilitando desktops virtuais independentes por tela (multi-monitor)...${NC}"
kwriteconfig6 --file kwinrc --group Windows --key PerOutputVirtualDesktops true --notify
echo -e "    ${GREEN}[OK]${NC} 'Switch desktops independently for each screen' habilitado — necessário para a troca de workspace do botão de gesto refletir corretamente em setups multi-monitor."

echo -e "${BOLD}==> [5/5] Habilitando e reiniciando logid.service (requer sudo)...${NC}"
sudo systemctl enable --now logid.service
sudo systemctl restart logid.service
sleep 1
if sudo systemctl is-active --quiet logid.service; then
    echo -e "${GREEN}==> [SUCESSO] logid.service ativo e configurado para o MX Master 3S.${NC}"
    echo -e "    Pressione uma vez o botão físico embaixo da roda de rolagem para fixar o modo livre."
else
    echo -e "    ${RED}Aviso: logid.service não está ativo. Rode 'sudo journalctl -u logid -n 30 --no-pager' para depurar.${NC}"
fi
