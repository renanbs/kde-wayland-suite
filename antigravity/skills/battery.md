---
name: battery
description: Diagnostica consumo de energia/bateria (GPU primária híbrida, PCIe ASPM, saúde da bateria, rádios) e aplica só as correções que o usuário escolher, com reversão simples.
---

# Bateria / Consumo de Energia — KDE Wayland

Diagnostica o consumo de energia da máquina e, com base na decisão do usuário, aplica correções — sempre com um mecanismo de reversão.

```bash
./bin/kde-config battery-status
```

## Fluxo obrigatório

**Nunca aplique correções de bateria sem perguntar.** Diagnóstico primeiro, decisão do usuário depois:

1. Rode `./bin/kde-config battery-status` e leia a saída.
2. Para cada achado com `[FALHA]` ou `[INFO]` acionável, explique o que significa e o trade-off (latência, estabilidade, o que muda).
3. Use `AskUserQuestion` para perguntar o que aplicar — cada correção é opt-in, nunca padrão.
4. Rode `./bin/kde-config battery-apply` só com as variáveis correspondentes às escolhas:

```bash
BATTERY_FIX_GPU_PRIMARY=1 ./bin/kde-config battery-apply
BATTERY_FIX_GPU_PRIMARY=1 BATTERY_FIX_PCIE_ASPM=1 BATTERY_FIX_PCIE_ASPM_PERSIST=1 ./bin/kde-config battery-apply
```

5. Informe o snapshot de reversão impresso ao final e como reverter: `./bin/kde-config battery-revert`.
6. Dê um relatório final: o que foi diagnosticado, o que foi aplicado, o que foi recusado, como reverter.

## O que é diagnosticado e corrigido

- **GPU primária do compositor** (sistemas híbridos Intel/NVIDIA/AMD): reordena `KWIN_DRM_DEVICES` para a GPU do painel interno (eDP) ficar primária, sem remover a GPU discreta da lista. Só tem efeito após logout/login ou reboot.
- **PCIe ASPM**: aplica `powersave` na hora; opcionalmente persiste após reboot via serviço systemd (`BATTERY_FIX_PCIE_ASPM_PERSIST=1`). Risco raro de instabilidade em NVMe/Wi-Fi com firmware ASPM mal implementado.
- **Saúde da bateria, rádios ociosos, governor de CPU**: apenas informativo.

## Reversão

Cada `battery-apply` cria um snapshot em `~/.config/kde-config-backups/battery_<timestamp>_<pid>/`. `battery-revert` (sem argumento) usa o mais recente; `battery-revert <caminho>` reverte um snapshot específico.

---

## Formato de saída (obrigatório e idêntico em todas as ferramentas)

Reporte sempre nestas três fases, nesta ordem, com estes títulos exatos.

**1. Plano** — antes de executar qualquer coisa:

- **Comando:** a linha exata que será executada
- **Faz:** uma frase sobre o que muda no sistema
- **Reversível:** como desfazer — ou `não aplicável` quando for só leitura

**2. Execução** — uma linha por etapa, com o marcador do resultado:

- `✅ <etapa>` — concluída e verificada
- `⏭️ <etapa>` — pulada (diga por quê)
- `⚠️ <etapa>` — concluída com ressalva (diga qual)
- `❌ <etapa>` — falhou (cole a mensagem de erro real, não parafraseie)

**3. Resumo** — sempre ao final, mesmo quando nada mudou:

| Campo | Conteúdo |
| :--- | :--- |
| O que mudou | lista objetiva, ou `nada — já estava correto` |
| O que não mudou | o que foi pulado ou recusado, e por quê |
| Backup | caminho do snapshot, ou `nenhum` |
| Como reverter | o comando exato |
| Requer | `nada` \| `logout/login` \| `reboot` |

**Regras:**

- Nunca declare sucesso sem verificar: rode o `status` correspondente ou releia o arquivo alterado antes de marcar `✅`.
- Se algo precisar de `sudo` e a sessão não tiver TTY, não tente contornar — peça ao usuário para rodar com o prefixo `!` e mostre a linha exata.
- Falhas entram no relatório com a saída real do comando; nunca omita nem suavize um erro.
- Se uma correção exigir logout ou reboot para valer, diga isso no `Requer` e repita no texto.
