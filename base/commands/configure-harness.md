---
description: Configura e audita o perfil do host de IA (Harness como OMP, Claude Code, Cursor, Antigravity) e associa os papéis de modelos recomendados (reasoning, code, review, security).
---

# /configure-harness

Gerencia e audita o alinhamento entre o host de IA ativo e os modelos configurados para a suite:

```bash
./bin/kde-config configure-harness
```

---

## Fluxo Guiado de Configuração (Obrigatório para Agentes de IA)

O agente deve detectar o harness ativo e usar a ferramenta `AskUserQuestion` para coletar as preferências do usuário:

Pergunta 1 — **Papel de Raciocínio & Arquitetura (`reasoning`)** (singleSelect):
- **"Claude 3.7 Sonnet (Recomendado)"** — Excelente para decomposição profunda e raciocínio técnico.
- **"Claude 3.5 Sonnet / Opus"** — Alta precisão arquitetural.
- **"Gemini 2.5 Pro / Flash"** — Janela de contexto massiva e raciocínio rápido.
- **"DeepSeek R1 / O3-Mini"** — Foco em raciocínio lógico e algorítmico.

Pergunta 2 — **Papel de Implementação & Código (`code`)** (singleSelect):
- **"Claude 3.7 Sonnet (Recomendado)"** — Engenharia cirúrgica, scripts e patches de kernel/C/Rust/Bash.
- **"Claude 3.5 Sonnet"** — Padrão da indústria para código limpo.
- **"Gemini 2.5 Flash"** — Execução ultrarrápida.

Pergunta 3 — **Papel de Revisão & Sanidade (`review`)** (singleSelect):
- **"Gemini 2.5 Flash / Fast (Recomendado)"** — Revisão ágil de formato, regressão e validação.
- **"Claude 3.5 Haiku"** — Verificação leve e de baixo custo.

### Mapeamento das Respostas para Execução:

```bash
./bin/kde-config configure-harness --set <harness> <reasoning> <code> <review> <security>
```

Para sincronizar automaticamente com o harness ativo:
```bash
./bin/kde-config configure-harness --sync
```

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

**4. Ações Recomendadas (Obrigatório se houver ⚠️ ou ❌)**:

- `• <Descrição do problema>`: `comando exato para corrigir`
