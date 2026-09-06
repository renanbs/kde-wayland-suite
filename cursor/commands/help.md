---
description: Exibe o manual completo de comandos, atalhos, soluções e fluxos guiados da suite KDE Plasma 6 Wayland.
---

# /help

Exibe a central de ajuda e documentação rápida de todos os comandos disponíveis na **KDE Plasma 6 Wayland Suite**:

```bash
./bin/kde-config help
```

---

## Tabela Geral de Comandos e Soluções

| Comando CLI | Comando Slash | O que faz | Quando usar |
| :--- | :--- | :--- | :--- |
| `./bin/kde-config status` | `/check-status` | Auditoria completa de 6 etapas de todo o ambiente | Para verificar a saúde do teclado, DMI, energia, IM, cedilha e gestos |
| `./bin/kde-config init` | `/init` | Inicialização guiada completa com backup | No primeiro setup ou para reconfigurar tudo com perguntas |
| `./bin/kde-config fix-keyboard` | `/fix-keyboard` | Corrige `Ctrl+C` no ABNT2, cedilha no US-intl e mascara o fcitx5 | Quando atalhos de teclado falharem ou cedilha sair como `ć` |
| `./bin/kde-config fix-tongfang` | `/fix-tongfang` | Desbloqueia a matriz no GRUB para laptops Tongfang/Avell/Clevo | Se a tecla física Control do notebook não responder |
| `./bin/kde-config smart-keyboard-power` | `/smart-keyboard-power` | Alterna energia do barramento (`on` sozinho, `auto` com teclado USB/BT) | Para evitar latência/trava no Left Ctrl sem gastar bateria |
| `./bin/kde-config battery-status` | `/battery` | Diagnóstico de bateria, GPU híbrida e PCIe ASPM (só leitura) | Para auditar consumo de energia e saúde da bateria |
| `./bin/kde-config battery-apply` | `/battery` | Aplica otimizações de bateria escolhidas pelo usuário | Para economizar bateria após ver o diagnóstico |
| `./bin/kde-config gestures` | `/configure-gestures` | Configura gestos de touchpad (3/4 dedos) no KWin | Para habilitar gestos suaves de swipe e overview |
| `./bin/kde-config mouse` | `/configure-mouse` | Configura o mouse Logitech MX Master 3S via logiops | Para mapear botão de polegar e SmartShift |
| `./bin/kde-config test-keyboard` | `/test-keyboard` | Monitor de eventos de teclado em tempo real | Para testar se qualquer tecla física está viva |
| `./bin/kde-config monitor-irq` | `/monitor-irq` | Monitor elétrico de hardware no IRQ 1 (i8042) | Para testar interrupções elétricas da placa-mãe |
| `./bin/kde-config switch [br\|us]` | — | Alterna o layout ativo no KWin via D-Bus | Para trocar layout sem depender de atalhos físicos |
| `./bin/kde-config report` | `/report` | Relatório da última execução + ações recomendadas | Para ver o histórico e como resolver pontos com ⚠️ ou ❌ |
| `./bin/kde-config rollback` | — | Restaura snapshot de backup anterior | Para desfazer qualquer alteração da suite |

---

## Formato de saída (obrigatório e idêntico em todas as ferramentas)

Reporte sempre nestas fases, nesta ordem:

**1. Plano** — comando que será executado e o que faz.  
**2. Execução** — uma linha por etapa (`✅`, `⏭️`, `⚠️`, `❌`).  
**3. Resumo** — tabela com o que mudou, o que não mudou, backup e como reverter.  
**4. Ações Recomendadas** — obrigatório se houver qualquer `⚠️` ou `❌`, indicando o comando exato de 1 linha para resolver.
