---
description: Desbloqueia o teclado integrado e a matriz de modificadores (tecla Control física) em laptops com chassi Tongfang, Avell, Clevo e Tuxedo via parâmetros do kernel i8042 e ACPI no GRUB.
---

# /fix-tongfang

Aplica os parâmetros de kernel necessários para que o driver `i8042` e o DSDT ACPI reconheçam a matriz completa de teclas (inclusive a tecla Control física) em laptops com chassi Tongfang / Avell / Clevo:

```bash
./bin/kde-config fix-tongfang
```

### O que o comando faz:
1. Identifica o hardware via DMI (`/sys/class/dmi/id/`).
2. Faz backup automático de `/etc/default/grub` em `/etc/default/grub.bak-tongfang`.
3. Injeta os parâmetros `i8042.nopnp=1 i8042.nomux=1 i8042.reset=1 acpi_osi='Windows 2020'` na variável `GRUB_CMDLINE_LINUX_DEFAULT`.
4. Atualiza a imagem do GRUB com `update-grub` / `grub-mkconfig`.
5. Registra o evento estruturado no runlog para auditoria pelo comando `report`.

### Para reverter:
```bash
./bin/kde-config revert-tongfang
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
- Se uma correção exigir logout ou reboot para valer, diga isso no `Requer` e repita no texto.
