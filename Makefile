.PHONY: all init report status check fix-keyboard fix-tongfang revert-tongfang test-keyboard monitor-irq smart-keyboard-power gestures mouse battery-status battery-apply battery-revert switch-br switch-us shortcut-switch rollback install-cli preflight help

all: status

init:
	@./bin/kde-config init

help:
	@echo "Alvos disponíveis no Makefile:"
	@echo "  make init            - Inicializa e salva todo o ambiente com backups"
	@echo "  make status          - Executa a auditoria completa de teclado e gestos"
	@echo "  make check           - Alias para make status"
	@echo "  make fix-keyboard    - Corrige Ctrl+C no ABNT2 e configura XCompose para US-intl"
	@echo "  make gestures        - Configura gestos de touchpad (libinput-gestures)"
	@echo "  make fix-tongfang    - Desbloqueia teclado/matriz em laptops Tongfang/Avell via GRUB"
	@echo "  make revert-tongfang - Reverte configuração do GRUB para backup anterior"
	@echo "  make test-keyboard   - Monitor de eventos de teclas em tempo real"
	@echo "  make monitor-irq     - Monitor de pulsos elétricos de hardware (IRQ 1)"
	@echo "  make smart-keyboard-power - Gerenciamento dinâmico de energia do teclado integrado"
	@echo "  make mouse           - Configura o Logitech MX Master 3S (logiops/logid)"
	@echo "  make battery-status  - Diagnostico de bateria/energia (so leitura)"
	@echo "  make battery-apply   - Aplica correcoes de bateria (use BATTERY_FIX_*=1; nunca sem antes perguntar ao usuario)"
	@echo "  make battery-revert  - Reverte a ultima aplicacao de battery-apply"
	@echo "  make preflight       - Executa diagnóstico base de ambiente e ferramentas"
	@echo "  make switch-br       - Alterna layout ativo para ABNT2 (br)"
	@echo "  make switch-us       - Alterna layout ativo para US-intl (us)"
	@echo "  make shortcut-switch - Configura atalho Meta+Space para alternar layouts"
	@echo "  make rollback        - Restaura snapshot anterior de configurações"
	@echo "  make report          - Relatorio da ultima execucao + tendencia historica"
	@echo "  make install-cli     - Instala o comando kde-config em ~/.local/bin"

status:
	@./bin/kde-config status

check: status

fix-keyboard:
	@./bin/kde-config fix-keyboard

fix-tongfang:
	@./bin/kde-config fix-tongfang

revert-tongfang:
	@./bin/kde-config revert-tongfang

test-keyboard:
	@./bin/kde-config test-keyboard

monitor-irq:
	@./bin/kde-config monitor-irq
smart-keyboard-power:
	@./bin/kde-config smart-keyboard-power


gestures:
	@./bin/kde-config gestures

mouse:
	@./bin/kde-config mouse

battery-status:
	@./bin/kde-config battery-status

battery-apply:
	@./bin/kde-config battery-apply

battery-revert:
	@./bin/kde-config battery-revert

preflight:
	@./bin/kde-config preflight

switch-br:
	@./bin/kde-config switch br

switch-us:
	@./bin/kde-config switch us

shortcut-switch:
	@./bin/kde-config shortcut-switch

rollback:
	@./bin/kde-config rollback

report:
	@./bin/kde-config report

install-cli:
	@./bin/kde-config install
