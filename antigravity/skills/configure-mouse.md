---
name: configure-mouse
description: Instala o logiops e configura o Logitech MX Master 3S no KDE Plasma 6 Wayland — botão de gesto para troca de workspace/overview e SmartShift fixo em rolagem livre.
---

# Configuração do Mouse (Logitech MX Master 3S) — KDE Wayland

Execute a configuração do mouse:

```bash
./bin/kde-config mouse
```

Configura:
- Botão de gesto (sob o polegar): arrastar troca de workspace, cima/toque = Overview, baixo = Mostrar Área de Trabalho.
- Multi-monitor: habilita `Switch desktops independently for each screen` no KWin.
- SmartShift desligado, roda de rolagem sempre no modo livre.
- Config em `~/.config/logid.cfg`, linkada em `/etc/logid.cfg`, editável sem sudo.

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
