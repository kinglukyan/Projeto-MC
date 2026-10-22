# Revisão do Atlas e da Arena · versão 2026.10.21

## Entrega

Esta é a mesma pasta principal do jogo. O arquivo ao lado, **Mythic-Clash-Completo.zip**, é atualizado no mesmo lugar. Não é necessário juntar outros pacotes. Não foi feito envio ao GitHub, implantação na Vercel ou alteração do banco online.

## Publicação

1. Guarde a pasta e o ZIP completos.
2. No Supabase, após confirmar que a 049 já foi aplicada, execute em ordem:
   - `supabase/migrations/202610210050_audit_rules_and_mode_guards.sql`
   - `supabase/migrations/202610210051_post_match_effect_details.sql`
3. Envie os arquivos desta pasta ao repositório GitHub já conectado à Vercel. A configuração existente prepara a publicação automaticamente.
4. Confira a versão **2026.10.21** no final do hall. O identificador menor ao lado diferencia as compilações.

Não execute novamente todas as migrações antigas. Os dados das contas continuam no Supabase, não dentro deste ZIP.

## Alterações

### Guardião

- Navegação entre áreas separada da ação de enfrentar o desafio atual.
- Ação principal: Enfrentar Aquiles, ou o próximo oponente da jornada. Ao consultar uma área futura, a ação volta ao desafio liberado.
- Indicação da próxima área afastada dos oponentes.
- Nomes dos bloqueados mais legíveis, mantendo sua condição de bloqueio.
- Caminho entre desafios com traço e brilho mais visíveis.
- Título do Atlas separado da área dos marcadores e faixa inferior mais compacta.
- Novo ícone do baú integrado aos botões de tesouro.
- Enquadramento geográfico, zoom e tamanho do seletor de baralho não foram tratados como defeitos, conforme solicitado.

### Cartas

- Krishna: outras unidades Hindus da mesma fileira recebem +1 de poder. A aura é única e deixa de funcionar com silêncio. Não concede bônus ao próprio Krishna. Texto e arte foram atualizados; o cliente e a migração 050 usam a mesma regra.
- Loki: nome, imagem e holograma seguem a identidade copiada; indicação identifica Loki e a habilidade copiada. O poder continua sendo calculado pelo motor, não pela apresentação.
- Histórico de alterações públicas do campo aparece **somente no pós-partida**: mudanças de poder, movimento, identidade, equipamentos, silêncio, proteção, saída do campo e Submundo. Mãos e baralhos privados não são copiados.
- Para partidas online, o histórico depende da migração 051 e começa nos eventos posteriores à instalação. Partidas antigas não ganham detalhes retroativamente.
- O histórico compara estados confirmados. Efeitos intermediários que se anulem dentro de uma única atualização do servidor podem não gerar uma linha individual.
- Medusa: mantida a regra de perder o próximo turno. A validação real em 1×1 e 2×2 fica com o proprietário, conforme solicitado.

### Interface, coleção e comunidade

- Pesquisa por nome de personagem/ícone no seletor do perfil, sem diferenciar acentos.
- Banners com área de imagem estável e alternativa com a arte do personagem em caso de falha.
- Ampliação de carta limitada à janela e mesa compacta no modo teste.
- Botões dos baralhos podem quebrar linha para evitar exceder a largura.
- Submenus laterais recolhidos ao mudar de tela.
- Resumo de rank compacto; trilha completa expansível; somente o rank imediatamente seguinte é Próximo.
- Criar/entrar em guilda antes dos painéis de informações.
- Presentes baseados na coleção; somente cartas com cópia extra aparecem. Botão desabilitado sem amigo, item ou saldo. Envio protegido contra repetição enquanto aguarda resposta e liberado para tentar novamente após erro.
- Expedição com seleção e imagem da carta, sem pedir ID técnico.
- Publicação comunitária a partir dos baralhos salvos, gerando o código internamente.
- Mictlantecuhtli classificado como Deus; nomes de ícones gerados sem sufixos Chibi inconsistentes.
- Busca no Universo e indicação de história em preparação.
- Textos de lobby, Personalizada, Trixx e Submundo padronizados; instruções específicas do laboratório.
- Erros comuns de conexão traduzidos para português com orientação para tentar novamente.
- Versão visível no rodapé do hall de entrada.

## Mapeamento dos modos

| Entrada | Formação | Início | Motor/servidor |
| --- | --- | --- | --- |
| Normal | 1 jogador | Convergir | `join_matchmaking('normal')`, estado individual |
| Ranqueada | 1 jogador | Convergir | `join_matchmaking('ranked')`, estado individual |
| Normal/Ranqueada | dupla aceita na sala | anfitrião Convergir | `start_duo_lobby_queue`, quatro jogadores, campo por equipe e mão privada por jogador |
| Personalizada | 1 vaga ocupada de cada lado | anfitrião inicia | `custom_room_start`, 1×1 |
| Personalizada | 2 vagas ocupadas de cada lado | anfitrião inicia | `custom_room_start`, 2×2 |

Slots 1 e 3 são aliados; 2 e 4 são adversários. Equipes desequilibradas não iniciam. A personalizada conserva regras, seleção de decks, observador, convites e prontidão após o relatório. A 050 impede iniciar uma personalizada com participante que já esteja em partida ativa ou desafio ativo do Atlas. A fila solo rejeita um modo inválido e uma partida ativa no cliente; o servidor conserva as verificações anteriores.

**Não foram executadas partidas reais nem testes automatizados nesta alteração, por solicitação do proprietário, que fará a validação. O mapeamento e os ajustes no código não são certificação de funcionamento em produção.**

## Roteiro para você conferir depois de publicar

1. 1×1 normal e ranqueada: entrar com duas contas, encontrar partida, jogar, passar, finalizar e voltar à sala.
2. 2×2 normal e ranqueada: formar duas duplas com quatro contas; confirmar os lados, a alternância entre jogadores e as mãos privadas.
3. Personalizada: criar sala, entrar por código como jogador/observador; iniciar 1×1; repetir com duas duplas; impedir início com 2 contra 1.
4. Medusa: verificar um único turno perdido no 1×1; no 2×2, ambos os adversários perdem o próximo turno individual, inclusive com Heimdall. Não deve obrigar a passar o Round nem impedir jogadas posteriores.
5. Krishna: jogar outra unidade Hindu na mesma fileira; ela ganha +1. Silenciar ou remover Krishna deve retirar a aura. Outra fileira e o próprio Krishna não recebem esse bônus.
6. Loki: copiar uma unidade equipada e conferir identidade, holograma, poder e habilidade; sair do campo encerra a cópia.
7. Pós-partida: confirmar que os detalhes só aparecem após o término e que não revelam cartas que nunca estiveram públicas.
8. Atlas: conferir CTA do desafio liberado, navegação por áreas, bloqueios, caminho e tesouro a cada cinco primeiras vitórias.
9. Perfil: pesquisar um ícone com e sem acento e equipá-lo.
10. Presentes/expedição/comunidade: confirmar disponibilidade, seleção visual, envio único e publicação do baralho escolhido.

## Arte alterada

`assets/cards-remake/hindu-krishna-v2.png` foi criada por edição com a ferramenta integrada de imagens. A referência anterior foi preservada. O novo baú usa `assets/guardian-campaign/atlas/tesouro-atlas.png`.
