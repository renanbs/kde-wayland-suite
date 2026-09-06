---
description: Verifica se há novas versões da suite no GitHub e aplica a atualização do repositório, links simbólicos e marketplaces locais do OMP/Claude.
---

# /upgrade

Verifica e atualiza a **KDE Plasma 6 Wayland Suite** para a versão mais recente publicada no GitHub:

```bash
./bin/kde-config upgrade
```

---

## Fluxo Guiado de Atualização (Obrigatório para Agentes de IA)

Antes de aplicar a atualização, o agente deve consultar o status remoto e usar `AskUserQuestion` para confirmar a ação com o usuário:

Pergunta 1 — **Ação de Atualização** (singleSelect):
- **"Verificar e Atualizar Imediatamente (Recomendado)"** — Executa `git pull`, atualiza links simbólicos e sincroniza o plugin no marketplace do OMP/Claude.
- **"Apenas Verificar Versão (Somente Leitura)"** — Compara a versão local e remota sem modificar o sistema.

### Mapeamento das Respostas para Execução:

* **Atualizar Imediatamente:**
  ```bash
  ./bin/kde-config upgrade --apply
  ```
* **Apenas Verificar:**
  ```bash
  ./bin/kde-config upgrade --check
  ```

---

## Formato de saída (obrigatório e idêntico em todas as ferramentas)

Reporte sempre nestas quatro fases, nesta ordem, com estes títulos exatos:

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
| Versão anterior | versão antes da atualização |
| Versão atualizada | versão final pós-atualização |
| Backup | histórico do Git preservado |
| Relatório salvo | `./bin/kde-config report` (ou `~/.local/state/kde-wayland-suite/runs/`) |
| Como reverter | `git checkout <commit_anterior>` |
| Requer | `nada` \| `logout/login` \| `reboot` |

**4. Ações Recomendadas (Obrigatório se houver ⚠️ ou ❌)**:

- `• <Descrição do problema>`: `comando exato para corrigir`
