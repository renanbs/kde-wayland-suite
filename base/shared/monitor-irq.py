#!/usr/bin/env python3
"""
Monitor de Interrupção de Hardware (IRQ 1 - i8042 Keyboard)
Verifica se o circuito elétrico/EC está gerando pulsos de interrupção na CPU
"""

import time
import sys
import os

def get_irq1_count():
    try:
        with open("/proc/interrupts", "r") as f:
            for line in f:
                if "i8042" in line or line.strip().startswith("1:"):
                    parts = line.split()
                    counts = []
                    for p in parts[1:]:
                        if p.isdigit():
                            counts.append(int(p))
                        else:
                            break
                    return sum(counts)
    except Exception as e:
        print(f"Erro ao ler /proc/interrupts: {e}")
    return 0

def main():
    print("=" * 65)
    print("  MONITOR DE INTERRUPÇÃO ELÉTRICA / HARDWARE (IRQ 1)")
    print("=" * 65)
    print("[*] Este teste verifica se o sinal elétrico chega ao processador.")
    print("[*] Pressione a tecla Control física várias vezes seguidas.")
    print("[*] (Ctrl+C no teclado externo ou feche o terminal para sair)")
    print("-" * 65)

    last_count = get_irq1_count()
    print(f"[*] Contagem inicial de IRQ 1: {last_count}")
    print("[*] Monitorando em tempo real... (Pressione as teclas agora)")
    print("-" * 65)

    try:
        while True:
            time.sleep(0.1)
            current_count = get_irq1_count()
            diff = current_count - last_count
            if diff > 0:
                print(f"[PULSO ELÉTRICO DETECTADO] IRQ 1 aumentou em +{diff} (Total: {current_count})")
                last_count = current_count
    except KeyboardInterrupt:
        print("\n[*] Monitoramento finalizado.")

if __name__ == "__main__":
    main()
