---
description: "Notificações nativas do macOS, aprovações, formulários de perguntas e painel de sessões para o DSH Desktop."
kind: "package-reference"
---

# DSH Notify

[简体中文](README.md) · [English](README.en.md) · [日本語](README.ja.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Русский](README.ru.md) · **Português**

Adiciona ao **DeepSeek Harness Desktop** notificações nativas do macOS, aprovações, formulários de perguntas e um painel de sessões na barra de menus. Responda a uma solicitação pela notificação ou volte ao espaço de trabalho e à sessão correspondentes.

O projeto combina um plug-in do DSH e o auxiliar **DSH Notify.app**, iniciado e encerrado junto com o Desktop. Não é necessário navegador, DSH Bridge ou serviço de modelo adicional. Este é um plug-in da comunidade; a versão estável atual é **v0.5.0**. Veja as [versões e os downloads](https://github.com/realDGD/dsh-macos-notify/releases/tag/v0.5.0).

## Recursos

| Recurso | Funcionamento |
| --- | --- |
| Notificações nativas | Avisa sobre conclusão, erros, aprovações e perguntas. Um clique abre a sessão correspondente. |
| Aprovação rápida | Escolha **Permitir uma vez** ou **Rejeitar** na notificação ou no menu, ou abra os detalhes para revisar o comando. |
| Formulários completos | Um aviso abre todas as perguntas, com seleção única ou múltipla, campos de texto independentes e um único envio do conjunto. |
| Painel de sessões | Mostra atividade, subagentes aninhados e as cinco sessões principais recentes, com status e progresso. |
| Contexto e código | Renderiza localmente tabelas Markdown, fórmulas e código, com destaque Shell/JSON e quebra de linha em comandos e argumentos. |
| Idiomas | Segue o DSH em chinês simplificado, inglês, japonês, espanhol, francês, alemão, russo e português. Nomes, perguntas, opções, respostas e comandos mantêm o idioma original. |

Os seis idiomas adicionados estão disponíveis no código-fonte atual e ainda não foram publicados em uma versão estável. Recompile o auxiliar nativo da mesma revisão para usá-los. Veja as [fontes de terminologia e a manutenção](docs/localization.md).

O DSH decide se uma solicitação continua válida. A primeira resposta aceita prevalece; solicitações respondidas, canceladas ou expiradas são retiradas e os botões antigos não repetem ações. Fechar uma janela de perguntas ou perder a conexão brevemente mantém os rascunhos. **Limpar respostas** apaga seleções e texto sem cancelar a solicitação. Os rascunhos ficam apenas na memória do auxiliar e são apagados após a confirmação de resposta, cancelamento ou retirada pelo DSH. Encerrar o auxiliar descarta rascunhos não enviados. Um resultado sem confirmação nunca é repetido automaticamente.

## Exemplos da interface

**As imagens e gravações abaixo usam a interface em inglês como exemplo. O plug-in também oferece a interface em português.** São capturas nativas reais com espaços de trabalho, sessões e solicitações fictícios. Os controles da Central de Notificações seguem o idioma do macOS. Clique para ampliar. Veja a [origem e o alcance das imagens](docs/images/README.md).

### Sessões e ações rápidas

<table>
<tr><th>Menu de sessões</th><th>Estados e animação do ícone</th></tr>
<tr>
<td valign="top"><a href="docs/images/menu-sessions-en.png"><img src="docs/images/menu-sessions-en.png" alt="Exemplo em inglês de sessões ativas e recentes, aprovações e perguntas" width="400"></a></td>
<td valign="top"><a href="docs/images/menu-icon-states-en.gif"><img src="docs/images/menu-icon-states-en.gif" alt="Exemplo em inglês dos estados e da rotação do peixe" width="400"></a></td>
</tr>
</table>

O peixe gira durante as tarefas. Laranja indica aprovação ou pergunta; vermelho, interrupção anormal; verde, conclusão. Prioridade: **entrada necessária > interrupção anormal > conclusão**. Abrir o painel restaura o ícone branco. Uma parada iniciada pelo usuário não gera alerta de erro.

### Aprovações e detalhes

<table>
<tr><th>Notificação e ações</th><th>Revisão de comandos e permissões</th></tr>
<tr>
<td valign="top"><a href="docs/images/notification-approval-en.png"><img src="docs/images/notification-approval-en.png" alt="Notificação em inglês com ações de permitir, rejeitar e ver detalhes" width="400"></a></td>
<td valign="top"><a href="docs/images/approval-details-en.png"><img src="docs/images/approval-details-en.png" alt="Janela em inglês com comando, argumentos completos e contexto" width="400"></a></td>
</tr>
</table>

**Ver detalhes** abre o motivo, o comando, os argumentos completos e o contexto. Os argumentos são indentados e as linhas longas se ajustam à largura. **Ver original** e **Copiar argumentos originais** mantêm o conteúdo de origem. A formatação não altera a solicitação enviada ao DSH.

### Perguntas e formulários

<table>
<tr><th>Notificação de perguntas</th><th>Opções e texto por pergunta</th></tr>
<tr>
<td valign="top"><a href="docs/images/notification-questionnaire-en.png"><img src="docs/images/notification-questionnaire-en.png" alt="Exemplo em inglês de uma notificação com duas perguntas" width="400"></a></td>
<td valign="top"><a href="docs/images/questionnaire-en.png"><img src="docs/images/questionnaire-en.png" alt="Formulário em inglês com seleção única e múltipla, textos independentes e envio conjunto" width="400"></a></td>
</tr>
</table>

**Abrir perguntas** abre o formulário inteiro; **Enviar todas as respostas** envia o conjunto de uma vez. Uma resposta anterior no DSH invalida a notificação antiga. **Abrir no DSH** fecha a janela após confirmar a sessão correta. As demonstrações não executam comandos, chamam modelos ou enviam respostas reais.

<a id="installation"></a>

## Instalação

**Recomenda-se o gerenciador de plug-ins do DSH Desktop.** É necessário macOS 13 ou posterior, DSH Desktop oficial e Apple Command Line Tools. A compatibilidade de execução e o status do auxiliar foram verificados em `0.2.2-rc.1`. O Desktop usa seu Node.js/pnpm incluído; Node.js 22+ separado só é necessário para compilação manual ou desenvolvimento. Veja os limites de macOS antigos, Intel e cliques reais em [compatibilidade](docs/compatibility.md).

`v0.5.0` instala o auxiliar automaticamente; o antigo `v0.5.0-preview.1` exige o procedimento manual. Para os novos idiomas, considere também a observação sobre o código-fonte acima.

1. Execute no Terminal e conclua a instalação do sistema. Se as ferramentas já estiverem instaladas, continue. Não são necessários o Xcode completo nem um certificado pago.

   ```sh
   xcode-select --install
   ```

2. No Desktop, abra **Plug-ins → Adicionar plug-in**, cole o endereço, confirme que confia na origem e escolha **Instalar**:

   ```text
   github:realDGD/dsh-macos-notify
   ```

3. Se os scripts forem bloqueados, revise o plug-in, autorize a execução e tente novamente. O auxiliar será compilado em `/Applications/DSH Notify.app`. Uma compilação correspondente é reutilizada; atualizações preservam as configurações e uma cópia do aplicativo anterior.
4. Escolha **Ativar agora**. Salve o trabalho, saia do Desktop com **⌘Q** e abra novamente; fechar uma janela não encerra o aplicativo. Permita notificações do **DSH Notify** quando o macOS solicitar.
5. Em **Configurações → DSH Notify**, confira a conexão e as permissões. Envie a notificação de teste e clique nela para verificar a sessão correta. A aceitação pelo macOS confirma apenas o recebimento para entrega; o clique verifica a navegação.

Veja o [guia oficial de plug-ins](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/client/ui-plugin-manager/README.md).

### Pelo Terminal

Instale o comando por **Manage dsh Command…** no menu do Desktop, abra um novo terminal e execute:

```sh
dsh plugin --profile desktop add github:realDGD/dsh-macos-notify
```

O Desktop usa o perfil `desktop`; `--profile web` aponta para um ambiente Web separado. Autorize scripts bloqueados no gerenciador. Veja a [instalação detalhada](docs/install.md) e o [guia oficial do comando](https://github.com/deepseek-ai/deepseek-harness/blob/master/apps/desktop/README.md#terminal-command).

### Pedir ajuda ao DSH

Copie em uma nova conversa:

```text
Instale DSH Notify no DeepSeek Harness Desktop oficial neste Mac:
https://github.com/realDGD/dsh-macos-notify
Leia primeiro README e docs/install.md. Verifique a versão do DSH, macOS 13+ e Command Line Tools.
Use o perfil desktop e o gerenciador de plug-ins ou o comando dsh incluído.
Confira se a versão tem o idioma necessário e compile /Applications/DSH Notify.app da mesma revisão do plug-in.
Preserve configurações e cópias anteriores. Explique minhas ações necessárias nos diálogos de instalação do sistema, aprovação de scripts e notificações.
Peça que eu salve o trabalho, saia e reabra o Desktop. Oriente o envio e o clique da notificação de teste até confirmar a sessão correta.
```

### Instalação manual

Para prévias antigas, falha na instalação automática ou desenvolvimento: instale Command Line Tools e [Node.js 22+](https://nodejs.org/en/download), depois:

```sh
git clone https://github.com/realDGD/dsh-macos-notify.git
cd dsh-macos-notify
npm ci --ignore-scripts
bash macos/install.sh
pwd
```

Cole o caminho absoluto de `pwd` em **Plug-ins → Adicionar plug-in**, ative, reinicie e teste. Também é possível extrair um arquivo-fonte completo de [Releases](https://github.com/realDGD/dsh-macos-notify/releases) e começar em `npm ci --ignore-scripts`. Mantenha plug-in e auxiliar na mesma revisão. O ícone oficial normalmente vem de `/Applications/DeepSeek Harness.app`; outros caminhos são configurados conforme o [guia](docs/install.md).

### Problemas comuns

| Problema | Solução |
| --- | --- |
| Falta `swiftc` | Conclua a instalação iniciada por `xcode-select --install` e tente novamente. |
| Scripts bloqueados | Autorize os scripts e tente novamente no DSH. |
| `dsh` não encontrado | Use o gerenciador ou repare o comando no Desktop e abra outro terminal. |
| Versão incompatível | Escolha versões correspondentes pelo [guia](docs/compatibility.md). |
| Auxiliar ausente ou atualização recusada | Use a instalação manual ou resolva os rascunhos e feche as janelas de aprovação e perguntas. |
| GitHub inacessível | Verifique a conexão ou use um arquivo completo já baixado. Alterar o registro npm não baixa o GitHub. |
| Nenhuma notificação | Verifique **Ajustes do Sistema → Notificações → DSH Notify** e os modos de Foco; envie um teste. |

O auxiliar acompanha o Desktop; não é um item de início de sessão.

## Uso diário

- Clique no peixe. A atividade prioriza sessões fixadas, solicitações de entrada e interrupções anormais, depois sessões em execução. As recentes mostram até cinco sessões principais, sem duplicatas nem subagentes.
- As cotas das seções contam apenas sessões principais. Expandir mostra dois subagentes; a linha adicional revela os demais. A altura cresce até o limite, quando as setas para cima/baixo percorrem o restante. Não há rolagem por roda ou barra. Uma área de uma única linha não fixa a sessão principal.
- Cima/Baixo selecionam a linha de mais subagentes. Enter/Espaço expandem ou recolhem, e Direita também expande. O foco passa ao primeiro subagente revelado. Esquerda nessa linha retorna ao pai.
- A contagem de tarefas aparece no anel de progresso; um plano concluído vira uma marca verde. Sem plano, não há anel. As aprovações têm botões verticais; perguntas abrem o formulário. **Ações** separa várias solicitações da mesma sessão.
- Configure os tipos, o som, resultados independentes de subagentes, espera pela conclusão e silêncio ao visualizar a sessão.
- O clique direito oferece abrir DSH, configurações do DSH Notify, ocultar a barra e sair do DSH. A engrenagem também abre as configurações. Clicar fora fecha o painel e mantém as janelas independentes.
- Sair exige confirmação se há tarefas em execução, aprovações ou respostas pendentes, ou status antigo, incompleto ou indisponível. O auxiliar solicita o encerramento normal do aplicativo.
- Ocultar a barra mantém notificações e janelas nativas disponíveis. Reative nas configurações do DSH Notify.
- Altere o idioma no DSH. As janelas abertas atualizam os textos mantendo escolhas e rascunhos; notificações entregues conservam o idioma de envio.

O contexto é renderizado localmente com Markdown e KaTeX: títulos, listas, citações, tabelas, fórmulas e código. Imagens remotas não são carregadas automaticamente e o HTML não é executado. Conteúdos longos indicam o limite de corte; abra o DSH para ler tudo.

## Atualização e desinstalação

Salve o trabalho, resolva rascunhos e feche as janelas nativas antes de atualizar. No gerenciador atual, **remova o plug-in e adicione novamente**. A instalação automática também verifica e atualiza o auxiliar. Na instalação manual, execute `npm ci --ignore-scripts` e `bash macos/install.sh`, adicione o mesmo diretório e reinicie o Desktop normalmente. Configurações e cópias são mantidas; o processo anterior deve terminar antes da substituição.

Ao migrar de `dsh-notify-web` / `DSH Jump.app`, remova o plug-in antigo e a retransmissão de conclusão/erro para evitar duplicatas. A identidade histórica do auxiliar é mantida para permissões e compatibilidade.

Para desinstalar, remova o plug-in no DSH e execute no diretório-fonte:

```sh
bash macos/uninstall.sh
```

Reinicie o Desktop. Configurações e cópias dos aplicativos permanecem; apenas os arquivos gerenciados por este instalador são removidos.

## Privacidade e limites

Não são criados listeners de rede, serviços em nuvem ou sessões de modelo adicionais. Navegação e configurações usam a conexão autenticada do DSH e arquivos privados do usuário atual. Perguntas e aprovações ficam temporariamente no armazenamento local para exibir os formulários e não são exportadas com diagnósticos. Não envie estados locais, tokens, conversas ou capturas com dados reais sem ocultação em relatos de problemas.

O macOS controla notificações, Foco e prévias da tela bloqueada. O silêncio não aprova, rejeita ou responde automaticamente. É suportado um Host/diretório de estado local ativo. Vários Hosts compartilhando o diretório, macOS antigos e Intel não foram verificados em dispositivos reais. A aceitação local existente cobre expansão do menu, navegação recente, preservação de rascunhos, limpeza e retirada após resposta ou cancelamento no DSH; não comprova aceitação real em cada idioma.

## Desenvolvimento e verificação

```sh
npm ci --ignore-scripts
npm test
npm run test:native
npm run check:release
```

O arquivo completo contém testes, arquivos de bloqueio, CI e scripts de compilação. O `.tgz` inclui código de execução e fontes do auxiliar, sem toda a suíte de testes. Veja o [procedimento de publicação](docs/release.md) e o [histórico](CHANGELOG.md).

## Licença

[MIT](LICENSE). O nome DSH e o ícone oficial obtido localmente identificam a integração; não concedem direitos sobre marcas de terceiros. Recursos de renderização e licenças constam em [THIRD_PARTY](THIRD_PARTY.md).
