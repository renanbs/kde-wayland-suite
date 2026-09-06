---
description: Configura e audita o perfil do host de IA (Harness como OMP + Antigravity, Claude Code, Cursor) e associa os papéis de modelos recomendados (reasoning, code, review, security).
---

# /configure-harness

Gerencia e audita o alinhamento entre o host de IA ativo e os modelos configurados para a suite:

```bash
./bin/kde-config configure-harness
```

---

## Fluxo Guiado de Configuração (Obrigatório para Agentes de IA)

O agente deve detectar o harness ativo e usar a ferramenta `AskUserQuestion` para coletar as preferências do usuário com o catálogo de modelos atualizado:

Pergunta 1 — **Papel de Raciocínio & Arquitetura (`reasoning`)** (singleSelect):
- **"google-antigravity/gemini-3.7-flash (Recomendado)"** — Ultrarrápido, raciocínio fluido e janela de contexto massiva.
- **"google-antigravity/gemini-3.7-pro"** — Raciocínio profundo e decomposição arquitetural complexa.
- **"anthropic/claude-3.7-sonnet"** — Raciocínio híbrido e extended thinking.
- **"deepseek/deepseek-r1"** — Foco em raciocínio lógico e algorítmico puro.

Pergunta 2 — **Papel de Implementação & Código (`code`)** (singleSelect):
- **"google-antigravity/gemini-3.7-flash (Recomendado)"** — Execução cirúrgica, scripts, C/Rust e patches de kernel.
- **"anthropic/claude-3.7-sonnet"** — Engenharia de precisão para refatoração e código complexo.
- **"openai/gpt-4o"** — Padrão multi-tarefa rápido.

Pergunta 3 — **Papel de Revisão & Sanidade (`review`)** (singleSelect):
- **"google-antigravity/gemini-3.7-flash (Recomendado)"** — Validação ágil de contratos de saída, testes e verificações de regressão.
- **"anthropic/claude-3.5-haiku"** — Verificação leve e de baixo custo.

Pergunta 4 — **Papel de Segurança & Pentest Defensivo (`security`)** (singleSelect):
- **"anthropic/claude-3.7-sonnet (Recomendado)"** — Auditoria defensiva rigorosa, análise de permissões e segurança de hardware.
- **"google-antigravity/gemini-3.7-flash"** — Varredura rápida de vetores de risco e sanitização.

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

**1. Plano** — comando que será executado e o que faz.  
**2. Execução** — uma linha por etapa (`✅`, `⏭️`, `⚠️`, `❌`).  
**3. Resumo** — tabela com o que mudou, o que não mudou, backup e como reverter.  
**4. Ações Recomendadas (Obrigatório se houver ⚠️ ou ❌)**:

- `• <Descrição do problema>`: `comando exato para corrigir`
