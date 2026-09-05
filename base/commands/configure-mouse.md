---
description: Instala o logiops e configura o Logitech MX Master 3S no KDE Plasma 6 Wayland — botão de gesto para troca de workspace/overview e SmartShift fixo em rolagem livre.
---

# /configure-mouse

Instala o `logiops` (se necessário), gera `~/.config/logid.cfg`, linka em `/etc/logid.cfg` e ativa o serviço `logid.service` para o Logitech MX Master 3S.

```bash
./bin/kde-config mouse
```

## O que é configurado

- **Botão de gesto** (grande, sob o polegar): segurar+arrastar troca de workspace (`Meta+Ctrl+Left/Right`, sem mover a janela ativa junto), cima/toque = Overview (`Meta+W`), baixo = Mostrar Área de Trabalho (`Meta+D`).
- **Multi-monitor**: habilita `Switch desktops independently for each screen` no KWin, garantindo que a troca de workspace pelo botão de gesto reflita corretamente em setups com múltiplos monitores.
- **Roda de rolagem**: SmartShift desligado, fixa no modo livre (sem "travinhas"). Pressione o botão físico embaixo da roda uma vez após aplicar a config para fixar o modo livre.
- Config editável sem sudo em `~/.config/logid.cfg` — depois de editar, rode `sudo systemctl restart logid.service` para recarregar.

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
