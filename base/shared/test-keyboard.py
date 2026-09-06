#!/usr/bin/env python3
"""
Testador de Teclas e Modificadores - KDE Wayland Suite
Lê diretamente o dispositivo de eventos do teclado (/dev/input/eventX)
"""

import os
import sys
import struct

KEY_NAMES = {
    1: "ESC",
    29: "LEFT_CTRL (Control Esquerdo)",
    97: "RIGHT_CTRL (Control Direito)",
    42: "LEFT_SHIFT (Shift Esquerdo)",
    54: "RIGHT_SHIFT (Shift Direito)",
    56: "LEFT_ALT (Alt Esquerdo)",
    100: "RIGHT_ALT (AltGr / Alt Direito)",
    125: "LEFT_META (Tecla Super / Windows)",
    126: "RIGHT_META (Super Direito)",
    127: "COMPOSE / MENU",
    464: "FN (Tecla de Função)",
    57: "ESPAÇO",
    14: "BACKSPACE",
    28: "ENTER",
    15: "TAB",
    58: "CAPS_LOCK",
    44: "Z",
    45: "X",
    46: "C",
    47: "V",
}

def find_keyboard_device():
    # 1. Tenta caminho canônico do i8042
    by_path = "/dev/input/by-path/platform-i8042-serio-0-event-kbd"
    if os.path.exists(by_path):
        return by_path
    
    # 2. Varre /proc/bus/input/devices
    try:
        with open("/proc/bus/input/devices", "r") as f:
            content = f.read()
        blocks = content.strip().split("\n\n")
        for block in blocks:
            if "AT Translated Set 2 keyboard" in block:
                for line in block.split("\n"):
                    if line.startswith("H: Handlers="):
                        for part in line.split():
                            if part.startswith("event"):
                                dev = f"/dev/input/{part}"
                                if os.path.exists(dev):
                                    return dev
    except Exception:
        pass
    
    # 3. Fallback
    if os.path.exists("/dev/input/event4"):
        return "/dev/input/event4"
    
    return None

def main():
    dev_path = find_keyboard_device()
    if not dev_path:
        print("[-] Erro: Nenhum teclado integrado i8042 encontrado em /dev/input/")
        sys.exit(1)

    print("=" * 65)
    print("  TESTADOR DE TECLADO INTEGRADO (KDE WAYLAND SUITE)")
    print("=" * 65)
    print(f"[*] Dispositivo conectado: {dev_path}")
    print("[*] Pressione as teclas para testar (Ctrl+C para encerrar)")
    print("-" * 65)
    print(f"{'TECLA':<32} | {'KEYCODE':<8} | {'ESTADO':<12}")
    print("-" * 65)

    EVENT_FORMAT = "llHHI"
    EVENT_SIZE = struct.calcsize(EVENT_FORMAT)

    try:
        with open(dev_path, "rb", buffering=0) as f:
            while True:
                data = f.read(EVENT_SIZE)
                if not data:
                    break
                tv_sec, tv_usec, ev_type, ev_code, ev_value = struct.unpack(EVENT_FORMAT, data)
                
                # EV_KEY = 0x01
                if ev_type == 1:
                    if ev_value == 1:
                        status = "\033[92mPRESSIONADA\033[0m"
                    elif ev_value == 0:
                        status = "\033[90mSOLTA\033[0m"
                    elif ev_value == 2:
                        status = "\033[93mREPETIÇÃO\033[0m"
                    else:
                        status = str(ev_value)

                    nome = KEY_NAMES.get(ev_code, f"KEY_{ev_code}")
                    
                    # Destaque especial para modificadores
                    if ev_code in (29, 97, 464):
                        nome_fmt = f"\033[1;96m{nome}\033[0m"
                    elif ev_code in (42, 54, 56, 100, 125):
                        nome_fmt = f"\033[1;94m{nome}\033[0m"
                    else:
                        nome_fmt = nome

                    print(f"{nome_fmt:<40} | {ev_code:<8} | {status}")
    except KeyboardInterrupt:
        print("\n\n[*] Teste finalizado pelo usuário.")
    except PermissionError:
        print(f"\n[-] Permissão negada ao abrir {dev_path}.")
        print("    Execute com sudo ou adicione seu usuário ao grupo 'input': sudo usermod -aG input $USER")

if __name__ == "__main__":
    main()
