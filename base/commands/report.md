---
description: Mostra o relatório da última execução da suíte (o que passou, falhou ou foi pulado) e a tendência histórica das métricas, como a saúde da bateria ao longo do tempo.
---

# /report

Relatório das execuções da suíte, montado a partir dos **eventos estruturados** que cada comando grava — não do texto do terminal.

```bash
./bin/kde-config report
```

Variações:

```bash
./bin/kde-config report            # última execução + tendência histórica
./bin/kde-config report 10         # lista as 10 execuções mais recentes
./bin/kde-config report --history  # só a tendência das métricas
```

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

Prefira **ler `events.tsv`** a parsear a saída do terminal: o texto é colorido, está em português e muda a cada ajuste de redação, enquanto os ids dos eventos são estáveis. Use os eventos para montar as fases **Execução** e **Resumo** do formato padronizado abaixo.

Se o usuário perguntar "o que mudou?", "deu certo?" ou "está piorando?", este comando responde sem precisar reexecutar nada — e sem depender do que ainda estiver no scrollback.

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
| Relatório salvo | `./bin/kde-config report` (ou `~/.local/state/kde-wayland-suite/runs/`) |
| Como reverter | o comando exato |
| Requer | `nada` \| `logout/login` \| `reboot` |

**Regras:**

- Nunca declare sucesso sem verificar: rode o `status` correspondente ou releia o arquivo alterado antes de marcar `✅`.
- Se algo precisar de `sudo` e a sessão não tiver TTY, não tente contornar — peça ao usuário para rodar com o prefixo `!` e mostre a linha exata.
- Falhas entram no relatório com a saída real do comando; nunca omita nem suavize um erro.
- Se uma correção exigir logout ou reboot para valer, diga isso no `Requer` e repita no texto.
