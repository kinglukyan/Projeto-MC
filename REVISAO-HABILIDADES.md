# Revisão das habilidades — 20/10/2026

## Alcance e limites

Revisão do código e do catálogo completo, incluindo unidades, equipamentos, Locais, Terrenos, Clima, formas especiais e clones. Os motores local e online foram comparados. A revisão não equivale a uma sessão de partidas reais: esta entrega não foi executada no banco de produção nem submetida a testes de partidas.

## Correções desta entrega

- **Chang’e:** a proteção permanece durante as jogadas intermediárias e termina no início do próximo turno do invocador. A repetição da fase inicial no mesmo turno não a remove.
- **Enlil:** pode escolher qualquer outro aliado; apenas o bônus de +2 depende de ele ser Mesopotâmico.
- **Shiva:** não pede escolha quando existe apenas um menor alvo elegível. Em empate, o invocador decide o lado aliado e um dono das unidades empatadas decide o lado inimigo. Em duplas, a escolha representa o campo da equipe.
- **Locais, Terrenos e Climas:** registram o jogador de origem e vão ao Submundo ao serem substituídos ou ao fechar o Round. Isso torna recuperações como Enki possíveis. Eclipse guarda a carta original, não entrega uma forma especial para a mão. Partidas iniciadas antes desta atualização não permitem reconstruir com segurança o dono de zonas antigas.
- **Escolhas:** a seleção é conferida novamente contra as opções legais; a interface impede envios duplicados durante a requisição e permite tentar novamente em caso de falha.
- **Ressurreição sem entrada:** Dagda, Izanagi, Xipe e clones não exibem a vinheta de habilidade de entrada como se ela tivesse sido ativada. A aparição da unidade continua visível.
- **Retorno de tokens:** um clone devolvido à mão desaparece, sem se tornar uma carta permanente.
- **Limpeza de poder:** bônus e penalidades passam a ser registrados separadamente. Exemplo: +4 e -2 resultam em +2; limpar a redução deixa +4, enquanto remover o bônus deixa -2. Vale também para ajustes por troca de poder e cópias; Aquiles não perde seu bônus duas vezes se Erlang o remover antes de ele mudar de fileira. O saldo anterior de partidas já iniciadas não permite reconstruir as parcelas que se anularam; a separação vale para novos ajustes.
- **Poder exato:** cópias, trocas, Anúbis e renascimento calculam a diferença antes do limite mínimo de zero. Isso evita que uma penalidade oculta abaixo de zero faça uma cópia de poder 5 terminar com 4, por exemplo.
- **Ômega:** compara a força inimiga com seu poder completo sem o próprio bônus condicional, incluindo clima, terreno e auras.
- **Proteção e Dionísio:** a proteção temporária de Chang’e também fica suspensa quando os efeitos da unidade estão globalmente silenciados.
- **Anúbis e salvamento:** no servidor, a recuperação só é oferecida se a vítima realmente foi destruída; Boitatá pode impedir a destruição. O ajuste de poder e a memória do Round só são aplicados à unidade realmente ressuscitada, nunca à última unidade pré-existente na fileira.
- **Identidade copiada:** Ares e Beowulf passam a reconhecer a facção e as características copiadas por Loki, em vez de consultar apenas a carta física Loki.
- **Ereshkigal e não unidades:** o bloqueio atinge ressurreição de unidades; não impede Ísis de recuperar um equipamento compatível nem a recuperação de Locais/Terrenos.
- **Poder no fechamento do Round:** registra o poder de todas as unidades antes de retirar a primeira aura do campo. Assim, o Submundo mantém o valor correto para Anúbis, independentemente da ordem de limpeza das cartas.
- **Cartas pausadas:** uma invocação bloqueada não devolve o objeto de estado como se fosse uma unidade.

## Critérios usados

- **Entrada:** acontece uma vez ao entrar, salvo quando a ressurreição declara ativar a entrada. Roubo e movimento não repetem entradas.
- **Aura:** recalculada com a fileira, identidade e habilidade ativas. Entradas futuras recebem o efeito; saída, silêncio ou mudança de fileira remove a parcela contínua.
- **Bônus recebido:** permanece até o fim do Round, salvo regra expressa. Aquiles perde definitivamente seu bônus de entrada ao sair da fileira em que o recebeu.
- **Poder:** limites de alvos usam poder atual; recuperações que dizem poder base usam o valor impresso. Anúbis considera o poder atual da vítima e o poder registrado no Submundo.
- **Proteções:** Heimdall bloqueia efeitos inimigos sobre a fileira; Medusa age contra o jogador. Durga, Vishnu, Curupira, Chang’e e Boitatá respeitam seus tipos de proteção e não bloqueiam sacrifícios aliados.
- **Silêncio:** Morgana/Cuca desligam a habilidade própria. Equipamentos, bônus recebidos e auras externas permanecem. Dionísio suspende efeitos por 3 jogadas subsequentes, exceto resistências previstas por Heimdall. Utu e Ganesha removem o silêncio dos alvos indicados.
- **Duplas:** mão, deck, compras e Submundo pessoal respeitam o jogador; a fileira é da equipe. Hórus revela informação somente ao invocador. Medusa passa o próximo turno dos dois inimigos.
- **Uma vez por Round:** ressurreição conserva os marcadores já gastos de renascimento, salvamento e luto. A troca de Round limpa esses marcadores.
- **Sem alvo:** encerra apenas o efeito sem alvo; não inventa um alvo inválido. Efeitos independentes, como comprar antes de mover, continuam acontecendo.
- **Escolhas opcionais:** podem concluir sem alvo quando a carta diz “pode” ou “até”. Reordenações mantêm as cartas não compradas na ordem escolhida.
- **Equipamentos:** uma cópia por portador; destruir ou devolver equipamento respeita a origem em duplas. Ressuscitar a unidade não devolve seus equipamentos.
- **Rounds:** poder e soma são independentes por Round. Limpeza de campo ao encerrá-lo não conta como destruição para Osíris/Cú Chulainn/Xipe.

## Instalação

Com as migrações anteriores até 043 aplicadas, executar `supabase/migrations/202610200044_ability_interaction_audit.sql`. Para instalação nova, seguir toda a sequência até 044. Publicar também os arquivos atualizados do site. Não reaplicar somente a 040 sobre um banco já atualizado até 044.

## Catálogo revisado

Texto vigente e mecanismo de cada carta. “Entrada” significa seleção/execução pela fila de habilidades; “contínuo” significa recalcular enquanto a fonte estiver ativa. A ficha impressa prevalece sobre inferências pelo nome.

### Grécia

#### Soldado de Esparta

**FORMAÇÃO ESPARTANA** · Poder 3 · Contínuo, equipamento, zona ou regra própria.

Cada outro Soldado de Esparta aliado na mesma fileira dobra o poder desta carta. O efeito é recíproco e acumulativo.

#### Athena

**FORMAÇÃO FALANGE** · Poder 4 · Contínuo, equipamento, zona ou regra própria.

Todas as outras cartas na mesma fileira de Athena ganham +2 pontos de poder cada.

#### Grécia

**Bônus de Local** · Poder 0 · Contínuo, equipamento, zona ou regra própria.

Enquanto este Local estiver ativo, todos os gregos recebem +2 de poder, nos dois lados do campo.

#### Troia

**Bônus de Terreno** · Poder 0 · Contínuo, equipamento, zona ou regra própria.

Fortalece Aquiles, Athena e Ares em +3 de poder.

#### Medusa

**VIRE PEDRA** · Poder 4 · Entrada: petrify.

Ao entrar, os jogadores inimigos perdem seu próximo turno. Em duplas, afeta ambos os adversários, mesmo com Heimdall.

#### Poseidon

**DEUS DO MAR** · Poder 7 · Entrada: tsunami.

Ao entrar, o tsunami reduz em 2 o poder das unidades inimigas presentes na fileira superior. Novas entradas não são afetadas.

#### Zeus

**SENHOR DOS CÉUS** · Poder 8 · Entrada: destroy_two.

Ao entrar, destrói até duas unidades inimigas aleatórias que possam ser afetadas.

#### Hades

**SUBMUNDO RESPONDA** · Poder 7 · Entrada: revive.

Ao entrar, escolha uma unidade do seu próprio Submundo para retornar na fileira de Hades, ativando sua habilidade de entrada.

#### Minotauro

**FÚRIA DO LABIRINTO** · Poder 3 · Entrada: alone_bonus.

Ao entrar em campo, se estiver sozinho em sua fileira de batalha, ganha +3 pontos de poder.

#### Apolo

**BENÇÃO DO SOL** · Poder 6 · Entrada: double_lane.

Enquanto Apolo estiver em campo, dobra o poder de todas as cartas aliadas na sua fileira, incluindo ele próprio e as que entrarem depois.

#### Afrodite

**MEU AMADO TRAIDOR** · Poder 5 · Entrada: steal.

Ao entrar em campo, o invocador pode escolher uma carta inimiga em campo para roubar, desde que ela tenha menos de 5 de poder.

#### Aquiles

**A FÚRIA DE MIRMIDÃO** · Poder 3 · Entrada: greek_bonus.

Ao entrar em campo, ganha +1 de poder para cada soldado grego ou herói aliado em sua fileira.

#### Ártemis

**TIRO PRECISO** · Poder 5 · Entrada: hunt_monsters.

Ao entrar em campo, elimina duas cartas Monstros de cada lado.

#### Ares

**DEUS DA GUERRA** · Poder 5 · Entrada: war_buff.

Ao entrar, concede +2 aos espartanos e a Leônidas e +1 aos demais gregos aliados na mesma fileira.

#### Dionísio

**FESTIVAL DO VINHO** · Poder 4 · Entrada: silence.

Ao entrar, silencia efeitos pelas próximas 3 jogadas da partida, contando aliados e adversários. Fileiras inimigas protegidas por Heimdall resistem ao silêncio.

#### Hefestos

**MELHORIA ARTEFATUAL** · Poder 4 · Entrada: improve.

Ao entrar em campo, aumenta em +3 os pontos de poder de um personagem com carta de equipamento.

#### Hércules

**OS DOZE TRABALHOS** · Poder 4 · Contínuo, equipamento, zona ou regra própria.

No fim de cada turno do dono, ganha +1 de poder, até 12 de progresso. Todo progresso é zerado ao trocar de Round.

#### Hermes

**TROCA VELOZ** · Poder 3 · Entrada: move.

Ao entrar em campo, você pode mover outra carta sua de uma fileira para outra, reorganizando sua pontuação.

#### Esparta

**Bônus de Terreno** · Poder 0 · Contínuo, equipamento, zona ou regra própria.

Fortalece os espartanos em +2 de poder e Ares em +3 de poder.

#### Labirinto de Dédalos

**Bônus de Terreno** · Poder 0 · Contínuo, equipamento, zona ou regra própria.

Fortalece o Minotauro e os monstros gregos em +2 de poder.

#### Raio de Zeus

**Equipar** · Poder 0 · Contínuo, equipamento, zona ou regra própria.

Somente Zeus pode equipar. Concede +4 de poder. Apenas um Raio por portador.

### Monstros

#### Lobisomem Alfa

**UIVO DE ALFA** · Poder 4 · Contínuo, equipamento, zona ou regra própria.

Recebe +2 de poder por Lobisomem Beta aliado na mesma fileira.

#### Lobisomem Omega

**ENCURRALADO** · Poder 1 · Contínuo, equipamento, zona ou regra própria.

Se o Lobisomem Omega for o único na sua fileira de batalha e o inimigo tiver mais poder que o Omega, seu poder aumenta em 8.

#### Lobisomem Beta

**UIVO DO BETINHA** · Poder 2 · Entrada: summon_betas.

Ao entrar em campo, chama os outros Betas que estiverem na mão do invocador para o campo.

#### Mulher

**AINDA SOU ALFA** · Poder 2 · Contínuo, equipamento, zona ou regra própria.

Cada Homem aliado na mesma fileira dobra seu poder. No Eclipse Lunar, Mulher da facção Monstros vira Lobisomem Alfa; fora do Lunar, recupera sua forma original.

#### Homem

**JUNTOS SOMOS FORTES** · Poder 1 · Contínuo, equipamento, zona ou regra própria.

Cada outro Homem aliado na mesma fileira dobra seu poder. No Eclipse Lunar, Homem da facção Monstros vira Lobisomem Beta; fora do Lunar, recupera sua forma original.

### Nórdicos

#### Guardião Nórdico

**VONTADE DO NORTE** · Poder 2 · Contínuo, equipamento, zona ou regra própria.

Cada outro Guardião Nórdico aliado na mesma fileira dobra seu poder. O efeito é recíproco e acumulativo.

#### Mjölnir

**Equipar** · Poder 0 · Contínuo, equipamento, zona ou regra própria.

Somente Thor pode equipar. Concede +4 de poder. Apenas um por portador; ressuscitar Thor não devolve o equipamento.

#### Runa Uruz

**Equipar** · Poder 0 · Contínuo, equipamento, zona ou regra própria.

Um aliado nórdico recebe +2 de poder. Apenas uma Runa Uruz por portador; a ressurreição não a reanexa.

#### Odin

**SABEDORIA DE YGGDRASIL** · Poder 8 · Entrada: schedule_foresight.

No início do próximo turno do dono, observe a carta do topo do seu baralho. Você pode descartá-la para ganhar +2 na soma da rodada ou mantê-la no topo.

#### Ragnar

**INVASORES DE KATGAT** · Poder 3 · Entrada: rally.

Ao entrar em campo, move uma carta aliada de baixo poder de outra fileira para a mesma fileira de Ragnar, unindo as forças.

#### Thor

**MARTELADA DE MJÖLNIR** · Poder 6 · Entrada: destroy_strongest.

Ao entrar em campo, escolhe a carta inimiga de maior poder e a envia para o Submundo.

#### Beowulf

**CORAGEM DE GEAT** · Poder 3 · Entrada: monster_bonus.

Ao entrar em campo, se houver alguma carta da facção Monstros na mesa, ganha +3 pontos de poder adicional.

#### Heimdall

**VIGÍLIA DE BIFRÖST** · Poder 3 · Contínuo, equipamento, zona ou regra própria.

Enquanto ativo, protege a própria fileira de efeitos inimigos, incluindo destruição, roubo, movimento, transformação e alterações de poder. Medusa afeta o jogador e não é bloqueada.

#### Yggdrasil

**Bônus de Terreno** · Poder 0 · Contínuo, equipamento, zona ou regra própria.

Fortalece Odin em +2 de poder.

#### Bifrost

**Bônus de Terreno** · Poder 0 · Contínuo, equipamento, zona ou regra própria.

Fortalece todos os nórdicos, exceto Loki, em +2 de poder.

#### Nilfheim

**Bônus de Terreno** · Poder 0 · Contínuo, equipamento, zona ou regra própria.

Fortalece Loki e os gigantes de gelo em +2 de poder.

#### Asgard

**Bônus de Local** · Poder 0 · Contínuo, equipamento, zona ou regra própria.

Enquanto este Local estiver ativo, todos os nórdicos recebem +2 de poder, nos dois lados do campo.

#### Loki

**ILUSÃO TRAIÇOEIRA** · Poder 3 · Entrada: copy.

Ao entrar, copia a habilidade, a identidade e o poder completo de um inimigo, incluindo bônus e equipamentos. A cópia termina ao sair do campo ou encerrar o Round.

### Universal

#### Eclipse

**Destino Celestial** · Poder 0 · Contínuo, equipamento, zona ou regra própria.

Ao jogar na área de Clima/Evento, sorteia Eclipse Lunar ou Solar, com 50% de chance para cada. O resultado afeta os dois lados até o fim do Round.

#### Excalibur

**Equipar** · Poder 0 · Contínuo, equipamento, zona ou regra própria.

Apenas uma Excalibur por portador. Rei Arthur recebe +4. Lukyan se transforma em Rei de Todos e mantém seus buffs, sem +4 extra.

#### Eclipse Lunar

**Destino Celestial** · Poder 0 · Contínuo, equipamento, zona ou regra própria.

Mulher e Homem da facção Monstros assumem as formas Alfa e Beta. Lobisomens transformados pelo Solar recuperam sua forma original. Dobra o poder dos lobisomens, vampiros e de Ártemis; Apolo e Rá perdem metade, arredondada para baixo.

#### Eclipse Solar

**Destino Celestial** · Poder 0 · Contínuo, equipamento, zona ou regra própria.

Dobra o poder de Apolo e Rá. Vampiros vão ao Submundo; lobisomens Beta e Omega viram Homem, e Alfa vira Mulher. Ártemis perde metade do poder, arredondada para baixo.

### Alyns

#### Lukyan — Rei da Festa

**REI DA FESTA** · Poder 3 · Entrada: crowd_bonus.

Enquanto houver outro aliado na mesma fileira, recebe +3 de poder. O bônus é recalculado ao mudar de fileira.

#### Lukyan — Rei de Todos

**REI DE TODOS** · Poder 6 · Contínuo, equipamento, zona ou regra própria.

COM EXCALIBUR, SEU PODER GANHA 1 PONTO POR CADA OUTRO ALIADO EM TODO O SEU CAMPO.

#### Butter

**CLEPTOMANÍACO** · Poder 4 · Entrada: steal_hand.

Ao entrar, rouba uma carta aleatória da mão inimiga. Sem cartas na mão, rouba do baralho; se também estiver vazio, do Submundo inimigo.

### Egípcios

#### Anúbis

**TROCA VELOZ** · Poder 5 · Entrada: anubis.

Ao entrar, envia uma unidade inimiga ao Submundo e pode recuperar uma unidade do próprio Submundo com o mesmo poder atual que a vítima tinha antes de sair.

#### Rá

**LUZ DA CRIAÇÃO** · Poder 8 · Contínuo, equipamento, zona ou regra própria.

No fim de cada turno do dono, concede +1 de poder a cada egípcio aliado na mesma fileira. Os bônus são limpos no fim do Round.

#### Seth

**TROVOADA DO CAOS** · Poder 4 · Entrada: shuffle_lane.

Ao entrar em campo, escolhe uma fileira e troca os valores de poder de todas as cartas nela, aliadas e inimigas, de forma aleatória entre elas.

#### Osíris

**JUSTIÇA CÍCLICA** · Poder 6 · Contínuo, equipamento, zona ou regra própria.

Ao ser destruído e enviado para o cemitério, dobra o poder de outra carta aliada aleatória em campo.

#### Sobek

**INUNDAÇÃO FERTILIZANTE** · Poder 2 · Entrada: ally_bonus.

Ao entrar em campo, se houver outra carta aliada na mesma fileira, ganha +2 de poder adicional.

#### Hórus

**OLHO DE HÓRUS** · Poder 4 · Entrada: reveal.

Ao entrar, somente o dono vê até duas cartas aleatórias da mão adversária, inclusive em duplas.

#### Ísis

**RESSURREIÇÃO DE OSÍRIS** · Poder 4 · Entrada: revive_cost.

Ao entrar em campo, escolha uma carta com 2 ou menos de poder do seu próprio Submundo para retornar ao campo na fileira de Ísis.

#### Alto Egito

**Bônus de Terreno** · Poder 0 · Contínuo, equipamento, zona ou regra própria.

Fortalece todos os egípcios em +2 de poder.

#### Baixo Egito

**Bônus de Terreno** · Poder 0 · Contínuo, equipamento, zona ou regra própria.

Fortalece todos os egípcios em +2 de poder.

#### Egito

**Bônus de Local** · Poder 0 · Contínuo, equipamento, zona ou regra própria.

Enquanto este Local estiver ativo, todos os egípcios recebem +2 de poder, nos dois lados do campo.

#### Olho que Tudo Vê

**Equipar** · Poder 0 · Contínuo, equipamento, zona ou regra própria.

Hórus, Rá e Osíris recebem +4 de poder. Loki copiando uma dessas identidades também pode equipar. Apenas um por portador.

### Japonesa

#### Amaterasu

**AURORA CELESTIAL** · Poder 5 · Contínuo/gatilho: aura.

Enquanto estiver em campo, as outras unidades Japonesas aliadas em sua fileira recebem +2 de poder. Não acumula com outra Amaterasu.

#### Fūjin

**VENTOS ERRANTES** · Poder 4 · Entrada: moveAlly.

Ao entrar, mova outra unidade aliada para uma fileira aliada à sua escolha que tenha espaço.

#### Hachiman

**ESTANDARTE DE GUERRA** · Poder 6 · Contínuo/gatilho: grow.

Ao fim de cada turno do seu dono, Hachiman recebe +1 de poder até o fim do Round se houver outra unidade aliada nesta fileira.

#### Inari

**COLHEITA DAS RAPOSAS** · Poder 3 · Entrada: drawCompany.

Ao entrar, compre 1 carta. Se houver outra unidade Japonesa aliada nesta fileira, Inari recebe +2 até o fim do Round.

#### Izanagi

**SOPRO DA CRIAÇÃO** · Poder 5 · Entrada: reviveQuiet.

Ao entrar, ressuscite uma unidade Japonesa de poder base até 4 do seu submundo nesta fileira, sem ativar sua habilidade de entrada.

#### Izanami

**PORTÕES DE YOMI** · Poder 6 · Entrada: destroy.

Ao entrar, escolha uma unidade inimiga de poder atual até 5. Destrua-a e dê -2 a Izanami até o fim do Round.

#### Raijin

**TAMBORES DO TROVÃO** · Poder 6 · Entrada: reduce.

Ao entrar, escolha até 2 unidades inimigas na fileira oposta. Cada uma perde 2 de poder até o fim do Round.

#### Ryūjin

**MARÉ DO REI DRAGÃO** · Poder 8 · Entrada: wave.

Ao entrar, as unidades inimigas já presentes na fileira oposta perdem 2 de poder até o fim do Round.

#### Susanoo

**CORTE DA TEMPESTADE** · Poder 5 · Entrada: destroy.

Ao entrar, destrua uma unidade inimiga de poder atual até 4 na fileira oposta.

#### Tsukuyomi

**ESPELHO DA LUA** · Poder 3 · Entrada: copyPower.

Ao entrar, escolha outra unidade em campo. Tsukuyomi copia seu poder atual até o fim do Round, sem copiar sua habilidade.

### Chinesa

#### Ao Guang

**TRIBUTO DO MAR** · Poder 4 · Entrada: equipmentReturn.

Ao entrar, devolva um equipamento inimigo à mão de seu dono. Se fizer isso, compre 1 carta.

#### Chang'e

**REFÚGIO NA LUA** · Poder 4 · Entrada: guard.

Ao entrar, escolha outra unidade aliada nesta fileira. Até o início do seu próximo turno, ela não pode ser destruída ou roubada por efeitos inimigos.

#### Erlang Shen

**OLHO DA VERDADE** · Poder 6 · Entrada: purge.

Ao entrar, remova os bônus positivos de poder de uma unidade inimiga à sua escolha. Equipamentos permanecem e deixam de conceder poder neste Round.

#### Fuxi

**OITO TRIGRAMAS** · Poder 4 · Entrada: reorder.

Ao entrar, veja as 3 primeiras cartas do seu deck e devolva-as ao topo na ordem que quiser. Compre 1 carta.

#### Guanyin

**COMPAIXÃO INFINITA** · Poder 4 · Entrada: recover.

Ao entrar, recupere para sua mão uma unidade de poder base até 4 do seu submundo.

#### Hou Yi

**FLECHA DOS NOVE SÓIS** · Poder 6 · Entrada: reduce.

Ao entrar, uma unidade inimiga à sua escolha perde 4 de poder até o fim do Round.

#### Imperador de Jade

**MANDATO CELESTIAL** · Poder 8 · Contínuo/gatilho: occupiedAura.

Enquanto estiver em campo, as outras unidades Chinesas aliadas em sua fileira recebem +1 de poder para cada fileira aliada ocupada.

#### Nezha

**RODAS DE FOGO** · Poder 6 · Entrada: moveEnemy.

Ao entrar, mova uma unidade inimiga da fileira oposta para outra fileira inimiga com espaço. Ela perde 2 de poder até o fim do Round.

#### Nüwa

**REMENDO DOS CÉUS** · Poder 5 · Entrada: cleanse.

Ao entrar, remova as reduções de poder de até 2 outras unidades aliadas em sua fileira.

#### Sun Wukong

**PELOS DO REI MACACO** · Poder 7 · Entrada: clones.

Ao entrar, invoque nesta fileira até 2 Clones Macacos de poder 2, sem habilidade. Eles são unidades Chinesas e desaparecem ao fim do Round.

#### Clone Macaco

**Clone** · Poder 2 · Contínuo, equipamento, zona ou regra própria.

Sem habilidade. Desaparece ao fim do Round.

### Brasil

#### Boitatá

**FOGO QUE PROTEGE** · Poder 6 · Contínuo/gatilho: saveOnce.

Uma vez por Round, enquanto Boitatá estiver em campo com a habilidade ativa, impeça a primeira destruição causada por um efeito inimigo contra outra unidade Brasil aliada de sua fileira.

#### Boto Encantado

**BAILE DO ENCANTADO** · Poder 5 · Entrada: bounce.

Ao entrar, você pode devolver outra unidade Brasil aliada de sua fileira para a sua mão. Se ela voltar para a mão, Boto recebe +2 de poder até o fim do Round. Retornar à mão não conta como destruição.

#### Caipora

**PACTO DA MATA** · Poder 4 · Contínuo/gatilho: aura.

Enquanto Caipora estiver em campo com a habilidade ativa, as outras unidades Brasil aliadas de sua fileira recebem +1 de poder, incluindo as que chegarem depois. O bônus termina ao sair da fileira ou quando a habilidade deixar de atuar.

#### Cuca

**NÉVOA DOS PESADELOS** · Poder 4 · Entrada: silence.

Ao entrar, silencie a habilidade de uma unidade inimiga na fileira oposta pelas próximas 2 jogadas da partida, contando aliados e inimigos. A contagem começa após esta jogada.

#### Curupira

**CAMINHOS INVERTIDOS** · Poder 5 · Contínuo/gatilho: protectMove.

Enquanto Curupira estiver em campo com a habilidade ativa, efeitos inimigos não podem mover as unidades aliadas de sua fileira.

#### Iara

**CANTO DAS ÁGUAS** · Poder 5 · Entrada: steal.

Ao entrar, escolha uma unidade inimiga com até 5 de poder atual na fileira oposta. Traga-a para a fileira de Iara, se houver espaço. A habilidade de entrada da unidade não é ativada.

#### Lampião

**EMBOSCADA DA CAATINGA** · Poder 6 · Entrada: rally.

Ao entrar, você pode mover outra unidade Brasil aliada para a fileira de Lampião, se houver espaço. Se ela mudar de fileira, recebe +2 de poder até o fim do Round.

#### Mapinguari

**RUGIDO DA FLORESTA** · Poder 4 · Contínuo/gatilho: company.

Enquanto houver pelo menos 2 outras unidades Brasil aliadas em sua fileira, Mapinguari recebe +3 de poder. O bônus é recalculado quando unidades entram, saem ou mudam de fileira.

#### Mula sem Cabeça

**GALOPE EM CHAMAS** · Poder 7 · Entrada: wave.

Ao entrar, reduza em 2 o poder de cada unidade inimiga que já estiver na fileira oposta, até o fim do Round, sem reduzir abaixo de 0. Não afeta unidades que entrarem depois.

#### Saci-Pererê

**REDEMOINHO TRAVESSO** · Poder 3 · Entrada: moveEnemy.

Ao entrar, escolha uma unidade inimiga na fileira oposta. Mova-a para outra fileira inimiga à sua escolha, se houver espaço.

### Celtas

#### Brigid

**CHAMA DE RENOVAÇÃO** · Poder 4 · Entrada: cleanse.

Ao entrar, remova as reduções de poder de outra unidade aliada em sua fileira e conceda +2 a ela até o fim do Round.

#### Cú Chulainn

**FÚRIA DO CÃO** · Poder 7 · Contínuo/gatilho: mourning.

Na primeira vez em cada Round que outra unidade aliada de sua fileira for destruída, Cú Chulainn recebe +4 até o fim do Round.

#### Dagda

**CALDEIRÃO DA ABUNDÂNCIA** · Poder 4 · Entrada: reviveQuiet.

Ao entrar, ressuscite uma unidade Celta de poder base até 3 do seu submundo nesta fileira, sem ativar sua habilidade de entrada.

#### Dama do Lago

**DÁDIVA DO LAGO** · Poder 4 · Entrada: recover.

Ao entrar, recupere um equipamento do seu submundo para sua mão.

#### Lancelot

**CAMPEÃO DO REI** · Poder 4 · Contínuo/gatilho: company.

Enquanto houver outra unidade Celta aliada na mesma fileira, Lancelot recebe +3 de poder.

#### Lugh

**MESTRE DAS ARTES** · Poder 6 · Entrada: choice.

Ao entrar, escolha: compre 1 carta ou conceda +3 de poder a outra unidade aliada desta fileira até o fim do Round.

#### Merlin

**VISÃO DE AVALON** · Poder 3 · Entrada: draft.

Ao entrar, veja as 3 primeiras cartas do seu deck. Escolha 1 para sua mão e devolva as demais ao fundo, na ordem que quiser.

#### Morgana

**VÉU DA FEITICEIRA** · Poder 5 · Entrada: silence.

Ao entrar, escolha uma unidade inimiga na fileira oposta. Silencie sua habilidade até o fim do próximo turno do dono dela.

#### Morrigan

**PRESSÁGIO DOS CORVOS** · Poder 5 · Entrada: drainGrave.

Ao entrar, uma unidade inimiga à sua escolha perde 1 de poder por unidade no submundo inimigo, até o fim do Round.

#### Rei Arthur

**JURAMENTO DA TÁVOLA** · Poder 5 · Contínuo/gatilho: aura.

Enquanto Arthur estiver em campo, as outras unidades Celtas aliadas em sua fileira recebem +1 de poder.

### Asteca

#### Chalchiuhtlicue

**ÁGUAS DO RENASCIMENTO** · Poder 4 · Entrada: recover.

Ao entrar, recupere uma unidade Asteca de poder base até 4 do seu submundo para sua mão.

#### Coatlicue

**VENTRE DA TERRA** · Poder 5 · Contínuo/gatilho: graveGrowth.

Enquanto estiver em campo, Coatlicue recebe +1 de poder por cada 2 unidades no seu submundo.

#### Huitzilopochtli

**MARCHA DO SOL** · Poder 5 · Entrada: sacrificeBuff.

Ao entrar, você pode destruir outra unidade aliada desta fileira. Se fizer isso, as demais unidades aliadas já nela recebem +2 até o fim do Round.

#### Mictecacíhuatl

**MEMÓRIA DOS MORTOS** · Poder 4 · Entrada: graveDraw.

Ao entrar, compre 1 carta se seu submundo contiver uma unidade. Se contiver 3 ou mais, Mictecacíhuatl também recebe +2 até o fim do Round.

#### Mictlantecuhtli

**SENHOR DE MICTLAN** · Poder 5 · Entrada: lockGrave.

Ao entrar, escolha até 2 unidades no submundo inimigo. Elas não podem sair de lá até o fim do Round.

#### Quetzalcóatl

**SOPRO DA SERPENTE** · Poder 5 · Entrada: drawMove.

Ao entrar, compre 1 carta. Depois, você pode mover outra unidade aliada para uma fileira aliada com espaço.

#### Tezcatlipoca

**ESPELHO DE OBSIDIANA** · Poder 6 · Entrada: swap.

Ao entrar, escolha outra unidade aliada nesta fileira. Troque o poder atual dela com o de Tezcatlipoca até o fim do Round.

#### Tláloc

**CHUVA DE JADE** · Poder 6 · Entrada: wave.

Ao entrar, as unidades inimigas já presentes na fileira central perdem 2 de poder até o fim do Round.

#### Xipe Tótec

**PELE RENOVADA** · Poder 5 · Contínuo/gatilho: rebirth.

Na primeira vez que Xipe Tótec for destruído neste Round, devolva-o à mesma fileira com poder 3, sem equipamentos e sem ativar habilidades de entrada.

#### Xochiquétzal

**JARDIM DA BELEZA** · Poder 4 · Contínuo/gatilho: aura.

Enquanto estiver em campo, as outras unidades Astecas aliadas em sua fileira recebem +2 de poder.

### Hindu

#### Durga

**MURALHA DA DEUSA** · Poder 7 · Contínuo/gatilho: protectDestroy.

Enquanto Durga estiver em campo, as outras unidades Hindus aliadas em sua fileira não podem ser destruídas por habilidades inimigas.

#### Ganesha

**ABRIDOR DE CAMINHOS** · Poder 4 · Entrada: unsilenceDraw.

Ao entrar, remova o silêncio de outra unidade aliada. Se nenhuma estiver silenciada, compre 1 carta.

#### Hanuman

**SALTO DEVOTO** · Poder 6 · Entrada: moveSelf.

Ao entrar, você pode mover Hanuman para outra fileira aliada com espaço. Se mover, ele recebe +2 até o fim do Round.

#### Indra

**VAJRA CELESTIAL** · Poder 5 · Entrada: equipmentDestroy.

Ao entrar, destrua um equipamento inimigo à sua escolha. Se não houver equipamento inimigo, Indra recebe +2 até o fim do Round.

#### Kali

**FIM DO CICLO** · Poder 7 · Entrada: sacrificeHunt.

Ao entrar, escolha outra unidade aliada nesta fileira e destrua-a. Depois, destrua uma unidade inimiga de poder atual até o dela antes da destruição.

#### Krishna

**CANÇÃO DO DEVER** · Poder 5 · Contínuo/gatilho: equipmentAura.

Enquanto Krishna estiver em campo, as outras unidades Hindus aliadas em sua fileira recebem +1 de poder por equipamento nelas, até +3 por unidade.

#### Lakshmi

**FORTUNA FLORESCENTE** · Poder 3 · Entrada: drawBuff.

Ao entrar, compre 1 carta. Se houver outra unidade Hindu aliada nesta fileira, dê +2 a ela até o fim do Round.

#### Saraswati

**MELODIA DO CONHECIMENTO** · Poder 4 · Entrada: draft.

Ao entrar, veja as 2 primeiras cartas do seu deck. Adicione 1 à sua mão e coloque a outra no fundo.

#### Shiva

**DANÇA DA RENOVAÇÃO** · Poder 8 · Entrada: shiva.

Ao entrar, destrua a outra unidade de menor poder atual em cada lado. Em caso de empate, seu dono escolhe entre as empatadas.

#### Vishnu

**PRESERVAÇÃO DIVINA** · Poder 6 · Contínuo/gatilho: protectReduction.

Enquanto Vishnu estiver em campo, as outras unidades Hindus aliadas em sua fileira não podem ter seu poder reduzido por efeitos inimigos.

### Mesopotâmica

#### Enki

**ÁGUAS DA SABEDORIA** · Poder 4 · Entrada: recover.

Ao entrar, recupere uma carta de Local ou Terreno do seu submundo para sua mão.

#### Enlil

**SOPRO DOS IMPÉRIOS** · Poder 6 · Entrada: moveAlly.

Ao entrar, mova outra unidade aliada para uma fileira aliada com espaço. Ela recebe +2 até o fim do Round se for Mesopotâmica.

#### Ereshkigal

**TRONO DO SUBMUNDO** · Poder 7 · Contínuo/gatilho: blockRevive.

Enquanto Ereshkigal estiver em campo, unidades no submundo inimigo não podem ser ressuscitadas na fileira oposta.

#### Ishtar

**ESTRELA DA CONQUISTA** · Poder 5 · Entrada: steal.

Ao entrar, se sua fileira tiver menos poder total que a oposta, roube uma unidade inimiga dela de poder atual até 4 para sua fileira, se houver espaço.

#### Marduk

**DECRETO DA BABILÔNIA** · Poder 7 · Entrada: destroy.

Ao entrar, destrua uma unidade inimiga de poder atual até 6. Marduk perde 2 de poder até o fim do Round se destruir uma unidade.

#### Nanna - Sîn

**CRESCENTE DE UR** · Poder 5 · Contínuo/gatilho: grow.

Ao fim de cada turno do seu dono, Nanna / Sin recebe +1 de poder até o fim do Round se houver uma carta de Clima em campo.

#### Nergal

**SOMBRA DA PESTE** · Poder 6 · Entrada: waveBoth.

Ao entrar, todas as outras unidades já presentes na fileira de Nergal e na fileira oposta perdem 2 de poder até o fim do Round.

#### Ninurta

**CAÇADOR DE MONSTROS** · Poder 7 · Entrada: destroy.

Ao entrar, destrua uma unidade inimiga da facção Monstros com poder atual até 6 na fileira oposta.

#### Tiamat

**MAR PRIMORDIAL** · Poder 9 · Entrada: sacrificeFeed.

Ao entrar, destrua outra unidade aliada desta fileira, se houver. Se destruir, Tiamat recebe metade do poder atual dela, arredondada para baixo, até o fim do Round.

#### Utu - Shamash

**LUZ DO JULGAMENTO** · Poder 6 · Entrada: cleanseAll.

Ao entrar, remova o silêncio e as reduções de poder das outras unidades Mesopotâmicas aliadas já presentes nesta fileira.

