---
description: Apresenta interativamente a lista de relatórios de execuções gravados na suíte e exibe o relatório selecionado pelo usuário com eventos detalhados e ações recomendadas.
---

# /report

Exibe relatórios detalhados das execuções da suíte a partir dos **eventos estruturados** gravados no disco.

---

## Fluxo Interativo Obrigatório para Agentes de IA

Ao ser acionado via `/report`, o agente de IA **NÃO deve exibir apenas o último relatório diretamente**. O agente **DEVE obrigatoriamente**:

1. **Buscar o histórico recente:** Listar os diretórios em `~/.local/state/kde-wayland-suite/runs/` e coletar data/hora, comando e contagem de eventos (`ok`, `warn`, `fail`).
2. **Apresentar a lista interativa:** Usar a ferramenta `AskUserQuestion` (ou `ask`) com a lista dos 5 a 10 relatórios mais recentes para que o usuário escolha qual deseja visualizar.
3. **Renderizar o relatório escolhido:** Exibir os detalhes completos da execução selecionada seguindo o formato padronizado abaixo.

---

## Formato de saída (obrigatório e idêntico em todas as ferramentas)

Reporte sempre nestas quatro fases, nesta ordem, com estes títulos exatos:

**1. Plano** — antes de executar qualquer coisa:

- **Comando:** a linha ou visualização do relatório que será executada
- **Faz:** uma frase sobre o que o relatório apresenta
- **Reversível:** `não aplicável`

**2. Execução** — lista dos eventos do relatório selecionado:

- `✅ <evento/etapa>` — validado com sucesso
- `⏭️ <evento/etapa>` — pulado
- `⚠️ <evento/etapa>` — aviso ou ressalva
- `❌ <evento/etapa>` — falha real registrada

**3. Resumo** — sempre ao final:

| Campo | Conteúdo |
| :--- | :--- |
| Relatório selecionado | identificador da pasta ou índice |
| Balanço da execução | contagem de ok, falhas e avisos |
| Backup | caminho do backup ou `nenhum` |
| Relatório salvo | `./bin/kde-config report <número>` (ou `~/.local/state/kde-wayland-suite/runs/`) |
| Como reverter | comando de reversão ou `não aplicável` |
| Requer | `nada` \| `logout/login` \| `reboot` |

**4. Ações Recomendadas (Obrigatório se houver ⚠️ ou ❌)**:

- `• <Descrição do problema>`: `comando exato para corrigir`
