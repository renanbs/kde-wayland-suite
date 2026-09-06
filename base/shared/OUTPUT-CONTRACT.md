# Contrato de Saída Padronizado

Fonte canônica do formato de relatório que **todo** comando/skill desta suite
deve seguir, em **todas** as ferramentas (Claude Code, Cursor, OMP, OpenCode,
Antigravity). O bloco abaixo é copiado ao final de cada `.md` de comando e de
skill; ao alterá-lo aqui, replique nos demais arquivos.

O objetivo é que a mesma operação produza o mesmo relatório independentemente
da ferramenta usada, e que o usuário consiga comparar execuções e saber sempre
o que mudou, o que não mudou e como desfazer.

---

## Formato de saída (obrigatório e idêntico em todas as ferramentas)

Reporte sempre nestas três fases, nesta ordem, com estes títulos exatos:

### 1. Plano

Antes de executar qualquer coisa:

- **Comando:** a linha exata que será executada
- **Faz:** uma frase sobre o que muda no sistema
- **Reversível:** como desfazer — ou `não aplicável` quando for só leitura

### 2. Execução

Uma linha por etapa, com o marcador correspondente ao resultado:

- `✅ <etapa>` — concluída e verificada
- `⏭️ <etapa>` — pulada (diga por quê)
- `⚠️ <etapa>` — concluída com ressalva (diga qual)
- `❌ <etapa>` — falhou (cole a mensagem de erro real, não parafraseie)

### 3. Resumo

Sempre ao final, mesmo quando nada mudou:

| Campo | Conteúdo |
| :--- | :--- |
| O que mudou | lista objetiva, ou `nada — já estava correto` |
| O que não mudou | o que foi pulado ou recusado, e por quê |
| Backup | caminho do snapshot, ou `nenhum` |
| Como reverter | o comando exato |
| Requer | `nada` \| `logout/login` \| `reboot` |

### Regras

- Nunca declare sucesso sem verificar: rode o `status` correspondente ou releia
  o arquivo alterado antes de marcar `✅`.
- Se algo precisar de `sudo` e a sessão não tiver TTY, não tente contornar —
  peça ao usuário para rodar com o prefixo `!` e mostre a linha exata.
- Falhas entram no relatório com a saída real do comando; nunca omita nem
  suavize um erro.
- Se uma correção exigir logout ou reboot para valer, diga isso no `Requer` e
  repita no texto — não deixe o usuário achar que já está valendo.
