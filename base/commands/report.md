---
description: Mostra o relatório da última execução da suíte (o que passou, falhou ou foi pulado), histórico numerado e seleção interativa, com ações recomendadas para resolver pontos não conformes.
---

# /report

Relatório das execuções da suíte, montado a partir dos **eventos estruturados** que cada comando grava — não do texto do terminal.

```bash
./bin/kde-config report
```

### Variações e Seleção de Relatórios:

```bash
./bin/kde-config report            # Exibe a última execução + tendência histórica
./bin/kde-config report --list     # Lista os relatórios recentes numerados [1..N]
./bin/kde-config report 3          # Exibe detalhadamente o 3º relatório mais recente
./bin/kde-config report --select   # Abre menu interativo no terminal para escolher o relatório
./bin/kde-config report --history  # Exibe apenas a tendência histórica das métricas
```

---

## Onde os dados ficam

Cada execução de qualquer comando da suíte grava um diretório em `~/.local/state/kde-wayland-suite/runs/<timestamp>-<comando>/`:

| Arquivo | Conteúdo |
| :--- | :--- |
| `events.tsv` | Um registro por checagem: `epoch · status · id · detalhe`. `status` ∈ `ok`, `warn`, `fail`, `skip`, `info`, `metric` |
| `output.log` | A saída bruta do comando, com os códigos de cor ANSI removidos (forense) |
| `meta.env` | Comando, código de saída, duração, versão da suíte, host |

Registros com status `metric` carregam um valor numérico e alimentam a tendência histórica (ex.: `battery_health_percent`).

O `report` e o `help` **não** geram runs — são leitura pura e só poluiriam o histórico.

## Retenção e desligamento

Mantém os **50 runs** mais recentes por padrão. Ajustável:

- `KDE_SUITE_RUNLOG_KEEP=100` — muda quantos runs preservar
- `KDE_SUITE_RUNLOG=0` — desliga o registro por completo
- `KDE_SUITE_RUNLOG_ROOT=<caminho>` — muda onde gravar

## Para agentes de IA

Prefira **ler `events.tsv`** a parsear a saída do terminal: os IDs dos eventos são estruturados e estáveis. Use os eventos para montar as fases **Execução**, **Resumo** e **Ações Recomendadas** do formato padronizado abaixo.

---

## Formato de saída (obrigatório e idêntico em todas as ferramentas)

Reporte sempre nestas fases, nesta ordem, com estes títulos exatos.

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
| Relatório salvo | `./bin/kde-config report` (ou `~/.local/state/kde-wayland-suite/runs/`) |
| Como reverter | o comando exato |
| Requer | `nada` \| `logout/login` \| `reboot` |

**4. Ações Recomendadas (Obrigatório se houver ⚠️ ou ❌)**:

- `• <Descrição do problema>`: `comando exato para corrigir`
