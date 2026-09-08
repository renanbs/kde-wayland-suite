.PHONY: all init scan profile setup report status check fix-keyboard fix-tongfang revert-tongfang test-keyboard monitor-irq smart-keyboard-power smart-wifi-power wifi-power screen-hz screen-60 screen-120 configure-harness set-lang gestures mouse battery-status battery-apply battery-revert switch-br switch-us shortcut-switch rollback upgrade update install-cli preflight help

all: status

init:
	@./bin/kde-config init

scan:
	@./bin/kde-config scan

profile:
	@./bin/kde-config profile

setup:
	@./bin/kde-config setup
help:
	@echo "Available targets in Makefile:"
	@echo "  make init            - Hardware inspection and machine profiling (safe, non-destructive)"
	@echo "  make scan            - Alias for make init"
	@echo "  make setup           - Contextual modular configuration wizard based on detected hardware"
	@echo "  make status          - Runs unified health audit of keyboard, gestures, power and wifi"
	@echo "  make check           - Alias for make status"
	@echo "  make fix-keyboard    - Fixes Ctrl+C on ABNT2 and sets up native cedilla on US-intl"
	@echo "  make gestures        - Configures 3/4-finger touchpad gestures (libinput-gestures)"
	@echo "  make fix-tongfang    - Unlocks keyboard matrix in GRUB for Tongfang/Avell laptops"
	@echo "  make revert-tongfang - Reverts GRUB configuration to previous backup"
	@echo "  make test-keyboard   - Interactive real-time key event monitor"
	@echo "  make monitor-irq     - Hardware electric pulse monitor on IRQ 1 (i8042 keyboard)"
	@echo "  make smart-keyboard-power - Dynamic keyboard power management (anti-latch + battery saver)"
	@echo "  make configure-harness    - Configures AI host harness profile and model roles"
	@echo "  make smart-wifi-power     - Dynamic Wi-Fi power management (AC vs Battery)"
	@echo "  make screen-hz            - Shows current internal display refresh rate and modes"
	@echo "  make screen-60            - Switches internal display refresh rate to 60 Hz"
	@echo "  make screen-120           - Switches internal display refresh rate to 120 Hz / max"
	@echo "  make set-lang        - Saves language preference (use LANG=<en|pt-BR>)"
	@echo "  make mouse           - Configures Logitech MX Master 3S (logiops/logid)"
	@echo "  make battery-status  - Battery and power diagnostics (read-only)"
	@echo "  make battery-apply   - Applies battery optimizations (use BATTERY_FIX_*=1; ask user first)"
	@echo "  make battery-revert  - Reverts the last battery-apply execution"
	@echo "  make preflight       - Runs environment, distribution and D-Bus tool diagnostics"
	@echo "  make switch-br       - Switches active layout to ABNT2 (br)"
	@echo "  make switch-us       - Switches active layout to US-intl (us)"
	@echo "  make shortcut-switch - Configures Meta+Space shortcut to switch layouts"
	@echo "  make rollback        - Restores previous configuration snapshots"
	@echo "  make report          - Run report from structured events + historical trends"
	@echo "  make upgrade         - Checks and applies suite and marketplace updates"
	@echo "  make install-cli     - Installs kde-config CLI command in ~/.local/bin"
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
smart-wifi-power:
	@./bin/kde-config smart-wifi-power
wifi-power: smart-wifi-power
screen-hz:
	@./bin/kde-config screen-hz
screen-60:
	@./bin/kde-config screen-60
screen-120:
	@./bin/kde-config screen-120
configure-harness:
	@./bin/kde-config configure-harness

set-lang:
	@./bin/kde-config set-lang $(LANG)



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

upgrade:
	@./bin/kde-config upgrade

update: upgrade
report:
	@./bin/kde-config report

install-cli:
	@./bin/kde-config install
