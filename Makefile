.PHONY: all status check fix-keyboard gestures switch-br switch-us shortcut-switch rollback install-cli preflight help

all: status

help:
	@echo "Alvos disponíveis no Makefile:"
	@echo "  make status          - Executa a auditoria completa de teclado e gestos"
	@echo "  make check           - Alias para make status"
	@echo "  make fix-keyboard    - Corrige Ctrl+C no ABNT2 e configura XCompose para US-intl"
	@echo "  make gestures        - Configura gestos de touchpad (libinput-gestures)"
	@echo "  make preflight       - Executa diagnóstico base de ambiente e ferramentas"
	@echo "  make switch-br       - Alterna layout ativo para ABNT2 (br)"
	@echo "  make switch-us       - Alterna layout ativo para US-intl (us)"
	@echo "  make shortcut-switch - Configura atalho Meta+Space para alternar layouts"
	@echo "  make rollback        - Restaura snapshot anterior de configurações"
	@echo "  make install-cli     - Instala o comando kde-config em ~/.local/bin"

status:
	@./bin/kde-config status

check: status

fix-keyboard:
	@./bin/kde-config fix-keyboard

gestures:
	@./bin/kde-config gestures

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

install-cli:
	@./bin/kde-config install
