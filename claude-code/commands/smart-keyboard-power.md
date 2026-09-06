---
description: Gerencia dinamicamente a energia do barramento do teclado integrado (i8042/serio0) para eliminar a trava/latência do Left Ctrl sem desperdiçar bateria quando um teclado USB/Bluetooth estiver conectado.
---

# /smart-keyboard-power

Gerencia o estado de energia (*Runtime Power Management*) da porta `serio0` do teclado integrado:
- **Sem teclado externo:** Mantém `power/control = "on"` (barramento sempre acordado, zero latência, eliminando a trava/latência do `Left Ctrl`).
- **Com teclado externo (USB/Bluetooth):** Alterna automaticamente para `power/control = "auto"` para economizar bateria enquanto o usuário digita no teclado externo.

```bash
./bin/kde-config smart-keyboard-power --apply
```

---

## Fluxo Guiado de Configuração (Obrigatório para Agentes de IA)

Antes de aplicar qualquer alteração, o agente **deve usar a ferramenta `AskUserQuestion`** para coletar a preferência do usuário:

Pergunta 1 — **Política de Energia do Teclado** (singleSelect):
- **"Dinâmico Inteligente (Recomendado)"** — Instala a regra udev que mantém `on` quando usado sozinho e `auto` quando um teclado externo for plugado.
- **"Sempre Ativo ('on' contínuo)"** — Força `power/control = on` estaticamente sem regra de alternância.
- **"Desativar / Padrão do Sistema ('auto')"** — Remove a regra udev e restaura o padrão do Linux.

### Mapeamento das Respostas para Execução:

* **Dinâmico Inteligente:**
  ```bash
  ./bin/kde-config smart-keyboard-power --apply
  ```
* **Desativar / Reverter:**
  ```bash
  ./bin/kde-config smart-keyboard-power --remove
  ```
* **Consultar Estado:**
  ```bash
  ./bin/kde-config smart-keyboard-power --status
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

**Regras:**

- Nunca declare sucesso sem verificar: rode o `status` correspondente ou releia o arquivo alterado antes de marcar `✅`.
- Se algo precisar de `sudo` e a sessão não tiver TTY, não tente contornar — peça ao usuário para rodar com o prefixo `!` e mostre a linha exata.
- Falhas entram no relatório com a saída real do comando; nunca omita nem suavize um erro.
