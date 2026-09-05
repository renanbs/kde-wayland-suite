---
description: Corrige o problema de atalhos (Ctrl+C) no layout ABNT2, remove variáveis legadas de IM e configura o suporte completo a cedilha no US-intl para Chrome, Orca IDE, Electron, GTK e Qt no KDE Wayland.
---

# /fix-keyboard

Aplica a correção atômica para teclado, atalhos e cedilha (' + c -> ç) no KDE Plasma 6 Wayland.

```bash
./bin/kde-config fix-keyboard
```

Antes de rodar, pergunte ao usuário se ele quer habilitar a **auto-cura do layout no login**: o Plasma tem um bug conhecido que, ao encerrar a sessão, pode regravar `~/.config/kxkbrc` mantendo só o layout ativo no momento do logout (o `br` some, o widget de troca de layout desaparece da barra). Se ele quiser proteção automática contra isso em todo reboot, rode com a variável habilitada:

```bash
KDE_SUITE_LAYOUT_AUTOHEAL=1 ./bin/kde-config fix-keyboard
```

Isso instala uma entrada de autostart que reaplica o layout completo (`br,us`) a cada login. Se o usuário não quiser essa entrada extra de autostart, rode sem a variável — o comando corrige o `kxkbrc` na hora normalmente.

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
