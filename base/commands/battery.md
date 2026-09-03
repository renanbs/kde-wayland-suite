---
description: Diagnostica consumo de energia/bateria (GPU primária híbrida, PCIe ASPM, saúde da bateria, rádios) e aplica só as correções que o usuário escolher, com reversão simples.
---

# /battery

Diagnostica o consumo de energia da máquina e, com base na decisão do usuário, aplica correções — sempre com um mecanismo de reversão.

```bash
./bin/kde-config battery-status
```

## Fluxo obrigatório para agentes de IA

**Nunca aplique correções de bateria sem perguntar.** Este comando é diagnóstico primeiro, decisão do usuário depois:

1. Rode `./bin/kde-config battery-status` e leia a saída.
2. Para cada achado com `[FALHA]` ou `[INFO]` acionável, explique ao usuário o que significa e o trade-off (latência, estabilidade, o que muda), como já é feito nesta conversa para o mismatch de GPU primária e a política de PCIe ASPM.
3. Use `AskUserQuestion` para perguntar, achado por achado (ou tudo de uma vez, se preferir), o que ele quer aplicar. Não assuma "sim" por padrão — cada correção é opt-in.
4. Rode `./bin/kde-config battery-apply` só com as variáveis correspondentes às escolhas:

```bash
# Exemplo: usuário só quer a correção de GPU, não quer ASPM
BATTERY_FIX_GPU_PRIMARY=1 ./bin/kde-config battery-apply

# Exemplo: usuário quer as duas, com ASPM persistindo após reboot
BATTERY_FIX_GPU_PRIMARY=1 BATTERY_FIX_PCIE_ASPM=1 BATTERY_FIX_PCIE_ASPM_PERSIST=1 ./bin/kde-config battery-apply
```

5. Informe o caminho do snapshot de reversão impresso ao final (também salvo em `~/.config/kde-config-backups/.battery-latest`) e como reverter:

```bash
./bin/kde-config battery-revert
```

6. Dê um relatório final resumindo o que foi diagnosticado, o que foi aplicado, o que foi recusado/pulado, e como reverter.

## O que é diagnosticado e corrigido

- **GPU primária do compositor (sistemas híbridos Intel/NVIDIA/AMD)**: detecta se o KWin está compondo numa GPU diferente da que atende o painel interno (eDP) — isso mantém a GPU discreta sempre ligada e copiando frames à toa. A correção reordena `KWIN_DRM_DEVICES` em `~/.config/plasma-workspace/env/*.sh` para a GPU do painel ser primária, sem remover a GPU discreta da lista (continua disponível sob demanda para PRIME offload e para saídas externas eventualmente ligadas nela). Só tem efeito após logout/login ou reboot.
- **PCIe ASPM**: detecta se a política (`/sys/module/pcie_aspm/parameters/policy`) não está em `powersave`/`powersupersave`. A correção aplica `powersave` na hora; opcionalmente persiste após reboot via um serviço systemd dedicado (`BATTERY_FIX_PCIE_ASPM_PERSIST=1`). Risco conhecido: raríssimos NVMe/Wi-Fi com firmware ASPM mal implementado podem ficar instáveis — reversível na hora.
- **Saúde da bateria, rádios ociosos (Bluetooth/Docker), governor de CPU**: apenas informativo — não há correção automática (são decisões do usuário ou limitações de hardware).

## Reversão

Cada `battery-apply` cria um snapshot em `~/.config/kde-config-backups/battery_<timestamp>_<pid>/` com o estado anterior e um `manifest.env` descrevendo o que foi tocado. `battery-revert` (sem argumento) usa o snapshot mais recente; `battery-revert <caminho>` reverte um snapshot específico.
