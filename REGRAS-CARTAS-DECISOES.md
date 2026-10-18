# Regras das cartas — decisões consolidadas

Versão de estudo de 18/10/2026. Este documento registra as decisões do criador após a análise das 57 cartas. Quando divergir do levantamento anterior, esta versão representa a regra desejada. A implementação deve ser ajustada separadamente; o documento não comprova que o site ou o banco já seguem todas estas regras.

## 1. Vocabulário e princípios

- **Turno e rodada:** significam a mesma coisa nos textos das cartas. Cada jogada da partida conta para efeitos com duração em turnos, inclusive jogadas de aliados e adversários.
- **Round:** cada disputa da melhor de três. Encerrar um Round é diferente de encerrar um turno.
- **Fileira:** uma das três linhas de uma equipe. Um bônus de fileira não alcança outra fileira, salvo exceção expressa.
- **Campo:** o conjunto das fileiras. Lukyan — Rei de Todos é uma exceção expressa aos bônus limitados à fileira.
- **Entrada:** invocação normal ou retorno de uma unidade ao campo. Ressurreições e Betas invocados por outro Beta executam habilidades de entrada. Movimento de fileira e transformação não são novas invocações.
- **Combos:** manter as combinações nas mãos do jogador. Não adicionar tetos de multiplicação, limites de pontuação ou travas de combo que não tenham sido solicitados.
- **Encerramento do Round:** limpar efeitos temporários, formas temporárias e progresso acumulado, conforme a regra já adotada para Dionísio e Hércules. Isso não antecipa a duração normal de um efeito durante o Round.

## 2. Unidades: alvo, ativação e duração

| Carta | Regra aprovada | Ativação e encerramento |
|---|---|---|
| Soldado de Esparta | Cada outro Soldado aliado na mesma fileira dobra seu poder. Crescimento exponencial, recíproco e acumulativo. | Contínuo: recalcular ao entrar, sair ou mover um Soldado. Não alcança outra fileira. |
| Athena | Concede +2 às outras unidades aliadas da mesma fileira. Não concede a si própria. Inclui unidades presentes e futuras. | Aura contínua. Ao sair ou mudar de fileira, sua contribuição acompanha a nova posição. |
| Lobisomem Alfa | Recebe +2 por Beta aliado na mesma fileira. Betas invocados pela habilidade de outro Beta também contam. | Contínuo: recalcular quando os Betas entram, saem, mudam de fileira ou mudam de forma. |
| Guardião Nórdico | Usa o mesmo padrão exponencial do Soldado: cada outro Guardião aliado na mesma fileira dobra seu poder. | Contínuo e recíproco. Dois Guardiões: ×2 em cada um; três: ×4 em cada um; quatro: ×8 em cada um. |
| Medusa | Impede a próxima jogada adversária conforme o efeito de petrificação. Em 2×2, ambos os jogadores inimigos perdem seu próximo turno. | É um efeito contra o jogador e atravessa a proteção de Heimdall. Cada adversário consome sua própria perda de turno. |
| Poseidon | Tsunami reduz em 2 o poder das unidades inimigas que estiverem na fileira superior no instante do impacto. | Impacto único na entrada. Não atinge unidades invocadas depois. O modificador aplicado termina com a saída da unidade/limpeza do Round. |
| Zeus | Destrói até duas unidades inimigas escolhidas aleatoriamente. | Na entrada. Não prioriza as unidades de maior poder. Respeitar a proteção de Heimdall ao formar o conjunto de alvos elegíveis. |
| Hades | Escolhe e ressuscita somente uma unidade do próprio Submundo. Retorna na fileira de Hades e ativa sua habilidade de entrada. | Na entrada. Equipamentos, Locais, Terrenos e Eventos não são alvos de ressurreição de Hades. |
| Lobisomem Omega | Manter a regra aprovada: sozinho na fileira, recebe +8 se a soma inimiga da fileira correspondente superar seu poder de comparação. | Contínuo: perder a condição de estar sozinho ou a vantagem inimiga remove o bônus. |
| Lukyan — Rei da Festa | Manter o bônus de +3 por estar bem posicionado com outro aliado na fileira. Se mudar de fileira, recalcular pela composição da nova fileira. | Atualizar ao reposicionar. A interpretação adotada neste documento conserva o valor impresso: +3 se houver ao menos outro aliado, sem inventar +3 por aliado. |
| Anúbis | Usar o poder atual da vítima, incluindo seus bônus. Uma unidade de base 3 que esteja com 15 pode ser enviada ao Submundo; a recuperação deve corresponder a 15. | Na entrada. O exemplo aprovado elimina a antiga restrição de alvo com poder atual ≤3. A recuperação usa o próprio Submundo; ver a definição técnica de poder no Submundo na seção 7. |
| Odin | No início do próximo turno do dono, observar o topo do próprio baralho; manter ou descartar para ganhar +2 na pontuação do Round. | Uma consulta por entrada. O bônus de pontuação termina na limpeza do Round. |
| Lukyan — Rei de Todos | Com Excalibur, dobra por cada outro aliado em todo o campo aliado, independentemente da fileira. Sem teto de multiplicação. | Contínuo: recalcular ao entrar/sair qualquer aliado. Mantém os buffs da forma base. Ao sair do campo, recuperar a identidade original de Lukyan. |
| Minotauro | Ao entrar sozinho na própria fileira, recebe +3. | Bônus de entrada. Não conceder retroativamente por ficar sozinho mais tarde. |
| Apolo | Dobra todas as unidades aliadas de sua fileira, inclusive ele próprio, unidades presentes e futuras. Vários Apolos acumulam suas duplicações. | Aura contínua: acompanha a presença e a fileira de cada Apolo. Sem novo teto de combo. |
| Rá | No fim de cada turno do próprio dono, concede +1 aos egípcios aliados na mesma fileira. | Cada Rá presente ativa. Os aumentos acumulam durante o Round e são limpos no encerramento dele. |
| Ragnar | Ao entrar, move para sua fileira um aliado de menor poder que esteja em outra fileira. Empates permitem escolher entre os elegíveis. | Entrada única. O movimento não reativa a habilidade de entrada da unidade movida. |
| Afrodite | Ao entrar, pode roubar uma unidade inimiga com poder atual menor que 5. Manter a unidade com seus bônus e equipamentos. | Transferência de controle, sem nova invocação. Mostrar corações no campo inimigo antes da mudança visual. Respeitar Heimdall. |
| Aquiles | Ao entrar, ganha +1 por aliado grego elegível como soldado/herói na mesma fileira. | O bônus fica fixado na entrada. Não recalcular por mudança de fileira. |
| Seth | Ao entrar, escolhe uma fileira e redistribui aleatoriamente os poderes das unidades elegíveis, aliadas e inimigas, nela. | Mantido como está, respeitando Heimdall. O modificador de troca termina com a saída/limpeza do Round. |
| Osíris | Quando destruído, dobra uma outra unidade aliada aleatória ainda em campo. | Mantido como está. Sem aliado elegível, não aplica bônus. O multiplicador dura enquanto o alvo permanecer no campo, até a limpeza do Round. |
| Thor | Ao entrar, destrói a unidade inimiga elegível de maior poder. Em empate, escolhe entre as empatadas. | Mantido como está, respeitando Heimdall. Sem alvo elegível, não destrói outra categoria de carta. |
| Ártemis | Ao entrar, elimina até duas unidades Monstros de cada lado, incluindo aliados. Manter a prioridade atual por maior poder entre as elegíveis. | Impacto único. A proteção de Heimdall deve ser considerada nas unidades inimigas protegidas. |
| Sobek | Ao entrar acompanhado de outro aliado na mesma fileira, recebe +2. | Bônus de entrada, mantido como está. |
| Ares | Ao entrar, fortalece aliados presentes na mesma fileira: espartanos/Leônidas +2; demais gregos +1. Não somar +1 adicional ao espartano. | Impacto único; não alcançar unidades que chegarem depois. Mantido como está. |
| Beowulf | Ao entrar, ganha +3 se existir unidade da facção Monstros na mesa, em qualquer lado/fileira. | Bônus de entrada, mantido como está. |
| Heimdall | Protege sua fileira também de destruição, roubo, movimento, transformação e alterações de poder causadas pelo inimigo. | Proteção contínua enquanto estiver presente e ativo. Medusa funciona porque seu alvo é o jogador. Ver a interação entre silêncio e proteção na seção 7. |
| Dionísio | Silencia efeitos por três turnos, contados pelas jogadas da partida, incluindo aliados e adversários. | Aplicar durante a duração definida; expira após três turnos contados ou na limpeza do Round. Não usar o contador de Rounds para medir a duração. |
| Butter | Rouba carta aleatória da mão inimiga; se a mão estiver vazia, busca no baralho inimigo; se também estiver vazio, busca no Submundo inimigo. | Uma obtenção por entrada. Usar a primeira fonte disponível nessa ordem. Se todas estiverem vazias, não há carta a obter. |
| Hefestos | Ao entrar, concede +3 a um aliado equipado. | Mantido como está. O bônus termina com a saída/limpeza do Round. |
| Hércules | No fim de cada turno do próprio dono, ganha +1 de progresso/poder, mantendo o teto atual de 12 de progresso. | Acumula dentro do Round; todo progresso é zerado ao trocar de Round. |
| Hermes | Ao entrar, pode mover outra unidade aliada para uma fileira diferente. | Mantido como está. Movimento não reativa entrada. |
| Hórus | Revela até duas cartas da mão adversária somente ao dono da habilidade, inclusive em 2×2. Com uma carta na mão, revela uma; com nenhuma, nenhuma. | Informação privada. O parceiro do dono não recebe automaticamente os dados. Não retirar as cartas da mão adversária. |
| Lobisomem Beta | Ao entrar, invoca os outros Betas da mão do próprio dono na mesma fileira. | Cada Beta invocado conta como entrada e participa imediatamente dos bônus do Alfa. Mantido como está. |
| Ísis | Ao entrar, escolhe carta elegível do próprio Submundo com poder base ≤2. Unidades retornam na sua fileira e reativam entrada; outros tipos mantêm suas exigências atuais de alvo/espaço. | Mantido como está. A elegibilidade continua baseada no poder base, diferentemente de Anúbis. A restrição nova de Hades a unidades não é transferida automaticamente para Ísis. |
| Mulher | Cada Homem aliado na mesma fileira dobra seu poder. No Lunar, se for da facção Monstros, vira Alfa. | Contínuo; manter as formas originais e o alcance de fileira. |
| Homem | Cada outro Homem aliado na mesma fileira dobra seu poder. No Lunar, se for da facção Monstros, vira Beta. | Contínuo; não contar a si próprio. Manter as formas originais e o alcance de fileira. |
| Loki | A cópia considera o poder completo do alvo: bônus, equipamentos e demais modificadores. A identidade copiada deve permitir as interações aprovadas de facção e equipamento. | Manter a cópia durante a presença no campo, até a limpeza do Round. Evitar contar o mesmo equipamento/bônus duas vezes; ver seção 7. |

## 3. Equipamentos

| Carta | Regra aprovada | O que ocorre na saída |
|---|---|---|
| Mjölnir | Somente um Mjölnir por Thor; +4. | Destruir Thor separa o equipamento. Se Thor retornar por ressurreição, volta sem Mjölnir e precisa equipar outra carta para recuperar o bônus. |
| Runa Uruz | Manter +2 em portador Nórdico e aplicar a mesma lógica de uma cópia equipada por unidade. | Ressuscitar o portador não devolve a Runa equipada. |
| Olho que Tudo Vê | +4 nos portadores compatíveis: Hórus, Rá e Osíris. Loki que esteja copiando uma identidade compatível também pode equipar. | A ressurreição não reanexa automaticamente o equipamento. |
| Raio de Zeus | Apenas um Raio por Zeus; +4. | A saída separa o equipamento; para voltar a receber seu bônus, precisa equipar novamente. |
| Excalibur | Apenas uma por Lukyan. A transformação mantém os buffs já recebidos. Rei de Todos não recebe um +4 adicional inventado sobre a transformação. | A saída devolve a identidade de Lukyan base; equipamento precisa ser obtido/equipado novamente. |

Restrições por unidade não limitam quantos portadores distintos podem estar equipados. Não foi estabelecido que uma unidade possa ter somente um equipamento de qualquer tipo; o limite confirmado é por equipamento especificado.

## 4. Locais e terrenos

Todos mantêm o funcionamento compartilhado: atingem os dois lados, incluem unidades presentes e futuras e deixam de contribuir quando substituídos, suspensos ou removidos no fim do Round.

| Carta | Regra aprovada |
|---|---|
| Grécia | +2 a todos os gregos. Loki copiando uma identidade grega também é considerado grego para esse efeito. |
| Asgard | +2 a todos os Nórdicos. A inclusão de Loki é intencional. |
| Egito | +2 a todos os Egípcios. Acúmulo com terreno e outros bônus aprovado. |
| Yggdrasil | Odin +2. |
| Alto Egito | Egípcios +2. |
| Baixo Egito | Egípcios +2. |
| Bifrost | Nórdicos +2, exceto Loki. A exceção de Loki é intencional. |
| Esparta | Espartanos +2; Ares +3, sem duplicar as duas parcelas no mesmo Ares. |
| Labirinto de Dédalos | Minotauro e monstros gregos +2, sem duplicar por satisfazer duas condições. |
| Troia | Aquiles, Athena e Ares +3. |
| Nilfheim | Loki e gigantes de gelo +2. |

## 5. Eclipse

As três definições são mantidas: Eclipse é a carta jogável; Eclipse Lunar e Eclipse Solar são resultados especiais, sem entrada direta no baralho/mão.

- **Eclipse:** sorteio 50% Lunar/50% Solar, com efeito nos dois lados. Exibir a carta neutra antes da revelação do resultado.
- **Lunar:** lobisomens, vampiros e Ártemis dobram; Apolo e Rá ficam com metade, arredondada para baixo. Homem/Mulher da facção Monstros viram Beta/Alfa. Formas originalmente lobisomens recuperam a identidade de origem.
- **Solar:** Apolo e Rá dobram; Ártemis fica com metade, arredondada para baixo. Vampiros vão ao Submundo; Alfa vira Mulher, Beta/Omega viram Homem.
- Transformações preservam identidade de origem, estado e fileira, sem disparar novamente habilidade de entrada.
- Local e Terreno continuam ativos. A regra de substituir Clima/Evento somente por Clima/Evento permanece.
- Os bônus deixam de valer quando o evento muda, é suspenso ou o Round termina. Enviar um vampiro ao Submundo é uma remoção; trocar depois para Lunar não o ressuscita automaticamente.
- A proteção ampliada de Heimdall precisa ser aplicada aos efeitos inimigos do evento.

## 6. Interações e motivos das decisões

| Interação | Resultado desejado | Motivo |
|---|---|---|
| Athena + aliado novo | O aliado recebe +2 imediatamente; Athena não se beneficia de si própria. | A habilidade representa uma formação mantida enquanto a fonte está presente. |
| Beta em cadeia + Alfa | Cada Beta invocado na fileira aumenta o Alfa imediatamente. | A forma de invocação não muda a participação do Beta no grupo. |
| Guardiões/Soldados/Homens | Crescimento exponencial preservado. | Posicionamento, construção de baralho e combos fazem parte da estratégia desejada. |
| Rei de Todos + aliados em outras fileiras | Todas as outras unidades do campo aliado contam para sua multiplicação. | A palavra “campo” é uma exceção expressa ao alcance de fileira. |
| Lukyan base mudando de fileira | Reavaliar a presença de companhia na nova fileira. | Seu bônus deve refletir seu posicionamento atual. |
| Aquiles mudando de fileira | Conservar o bônus obtido na entrada. | Sua habilidade foi definida como um ganho de entrada, sem acompanhar movimento. |
| Zeus + inimigos de poderes diferentes | Sorteio entre alvos elegíveis; poder não dá prioridade. | A destruição foi definida como aleatória. |
| Poseidon + invocação posterior | A nova unidade não sofre o tsunami antigo. | O efeito é um impacto que já terminou. |
| Hades + equipamento no Submundo | Equipamento não é elegível. | Ressurreição de Hades é restrita a unidades. |
| Medusa + Heimdall no 2×2 | Ambos os jogadores inimigos perdem a próxima jogada. | A proteção de unidades não protege jogadores contra Medusa. |
| Ressurreição de Thor | Thor volta sem o Mjölnir; precisa receber novo equipamento. | Ressuscitar a unidade não ressuscita seu conjunto de itens anexados. |
| Loki copiando grego/portador do Olho | Participa do Local Grécia e pode receber Olho quando a identidade copiada for compatível. | A cópia precisa produzir as interações expressamente aprovadas. |
| Fim de turno do dono | Rá e Hércules processam seus ganhos. | “Rodada” nos textos representa turno; o melhor de três usa “Round”. |
| Silêncio de Dionísio | Contar três jogadas globais. | A duração não depende do retorno do turno ao invocador. |

## 7. Detalhes ainda necessários para especificar a implementação

As decisões acima estão registradas. Os pontos abaixo descrevem lacunas operacionais que não devem receber regras inventadas durante a alteração do código.

1. **Anúbis e poder no Submundo:** a vítima deve ser medida pelo poder atual antes de sair. Para localizar uma unidade de “15 de poder” no Submundo, proponho usar seu último poder registrado ao sair do campo, pois ela já não recebe auras enquanto está fora. O código atual guarda um campo de poder na morte, mas o filtro de Anúbis ainda usa poder base. É preciso confirmar essa interpretação antes de escolher a representação definitiva. Também definir o tratamento de cartas que foram descartadas diretamente da mão/baralho e nunca tiveram poder em campo.
2. **Lukyan base:** o texto atual concede +3 quando acompanhado, sem dizer “por aliado”. O documento mantém esse valor e reavalia a condição ao mover. Se o número de aliados tiver de multiplicar o +3, isso representa outra fórmula e precisa ser declarado.
3. **Dionísio e fronteira de turno:** ficou confirmado que o contador usa jogadas globais. Ainda especificar se o turno em que Dionísio entra é o primeiro dos três ou se a contagem começa na jogada seguinte, e se um turno pulado por Medusa consome uma unidade da duração.
4. **Heimdall contra Dionísio:** Medusa é exceção confirmada. A proteção de Heimdall foi ampliada para efeitos inimigos sobre sua fileira; falta resolver a precedência quando Dionísio silencia globalmente a própria habilidade que fornece essa proteção. Não assumir silenciosamente que o silêncio atravessa o escudo.
5. **Loki e duplicação de poder:** copiar um valor já aumentado por equipamento e também anexar uma cópia mecânica desse equipamento pode contar o mesmo bônus duas vezes. A implementação deve preservar a intenção de copiar tudo, mas precisa definir se copia o estado completo ou um valor final. Também é necessário definir se acompanha alterações futuras do alvo e o que ocorre se uma troca de identidade tornar um equipamento incompatível.
6. **Butter em 2×2:** a prioridade mão → baralho → Submundo está definida. Falta determinar se primeiro considera todas as mãos adversárias antes dos baralhos ou se escolhe um jogador inimigo e segue as três fontes dele.

## 8. Alterações necessárias em relação ao código analisado

| Área | Diferença a corrigir na implementação |
|---|---|
| Guardião Nórdico | Trocar a duplicação única pela multiplicação por cada outro Guardião da fileira. |
| Medusa 2×2 | Marcar a perda de turno dos dois adversários. |
| Zeus | Substituir seleção dos dois maiores pelo sorteio de até dois alvos elegíveis. |
| Hades | Excluir equipamentos e zonas da seleção de ressurreição. |
| Lukyan base | Reavaliar o bônus ao trocar de fileira. |
| Anúbis | Retirar o limite atual ≤3; unificar a comparação e o resgate pelo poder aprovado. |
| Rei de Todos | Contar aliados de todo o campo, sem limite de multiplicação. |
| Rá/Hércules | Mover as ativações de encerramento de Round para fim de turno do dono e manter limpeza no encerramento do Round. |
| Heimdall | Ampliar proteção para todos os efeitos inimigos de unidade/estado aprovados, preservando a exceção de Medusa. |
| Dionísio | Substituir duração por Round por contador de três turnos globais. |
| Butter | Implementar fontes alternativas: mão, baralho, Submundo. |
| Hórus | Conferir isolamento da informação por jogador, inclusive na resposta do servidor de 2×2. |
| Loki | Uniformizar identidade/facção compatíveis e cópia do poder completo, sem duplicar parcelas. |
| Equipamentos | Impedir cópias proibidas no mesmo portador e garantir retorno por ressurreição sem os itens anteriores. |
| Apresentação | Ajustar textos das cartas, descrições, logs e interfaces ao vocabulário turno/rodada/ Round. |
| Online/local | Aplicar as mesmas regras no motor local e no servidor, com migração própria para os dados e funções necessários. |

Athena, Alfa, Poseidon, Apolo, Ares, Aquiles e demais cartas marcadas como aprovadas mantêm as particularidades descritas neste documento. A revisão não autoriza acrescentar limites aos combos.


## 9. Implementação desta entrega

As convenções operacionais efetivamente adotadas, a migração necessária e a verificação estão em `ATUALIZACAO-REGRAS-APROVADAS.md`. Elas detalham os pontos da seção 7, sem alterar o histórico das decisões.
