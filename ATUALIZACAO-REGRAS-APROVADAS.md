# Atualização das regras aprovadas — 18/10/2026

## Conteúdo

Regras alinhadas no motor local e em uma nova migração online: Guardiões exponenciais por fileira; Zeus aleatório; Medusa nos dois adversários em duplas; Hades somente unidades; Anúbis com poder atual sem o antigo limite de 3; Lukyan base recalculado ao reposicionar e Rei de Todos contando todo o campo; Heimdall com proteção ampliada; Dionísio por três turnos globais; Rá/Hércules no fim do turno do dono; Butter com fontes alternativas; cópia de Loki e equipamentos únicos por portador.

Athena alcança aliados atuais/futuros sem beneficiar a si mesma. Betas invocados em cadeia alimentam o Alfa. Apolo mantém a aura e seus multiplicadores acumulativos. Poseidon é impacto único na fileira superior inimiga. Nenhum teto adicional foi colocado nos combos.

## Instalação

1. Atualizar os arquivos do site com este pacote.
2. No Supabase, executar `supabase/migrations/202610180025_approved_card_rules.sql` **depois do SQL 024**. A migração roda em transação e conserva as permissões dos auxiliares.
3. Iniciar uma nova partida ou reiniciar o modo de teste para estudar as regras novas, evitando bônus antigos já gravados em partidas anteriores.

A migração não foi aplicada ao Supabase remoto por esta entrega. Os arquivos não foram publicados remotamente.

## Convenções adotadas para os detalhes operacionais

- Dionísio dura as **próximas três jogadas**, sem consumir o próprio turno de invocação. Passar ou perder um turno por Medusa também avança o contador. A mesma jogada não pode consumi-lo duas vezes.
- Heimdall resiste ao silêncio inimigo e mantém sua fileira ativa. O silêncio do próprio time não recebe essa proteção. Medusa continua atingindo diretamente os jogadores.
- Anúbis compara o poder da vítima antes da remoção com o último poder registrado na morte das unidades do próprio Submundo. Para descartes que nunca entraram em campo, usa o poder base. A unidade recuperada retoma esse valor; sua habilidade de entrada pode acrescentar efeitos depois.
- Lukyan base mantém +3 se acompanhado; o número de unidades determina a existência de companhia, não cria um novo +3 por aliado.
- Butter em 2×2 busca primeiro nas mãos adversárias, depois nos baralhos, depois no Submundo da equipe inimiga. Se todas as fontes estiverem vazias, não cria cartas.
- Loki copia o valor completo no instante da escolha. Guarda os equipamentos copiados como efeito virtual, sem gerar cópias físicas no Submundo. Seus próprios efeitos futuros podem mudar esse valor. Facção/compatibilidade usam a identidade copiada. Um item já incluído na cópia não pode ser equipado uma segunda vez.
- Ressurreição normal não reanexa equipamentos; os itens físicos ficam separados no Submundo. Excalibur conserva os bônus da forma base na transformação.
- O modo de teste avança uma jogada global por clique em “Avançar turno”, alternando o lado considerado para Rá/Hércules/Odin.

## Verificação

- 20 cenários no motor JavaScript, cobrindo mudanças, combinações, proteção, turnos, fontes de roubo, cópia, ressurreição e limpeza.
- 12 grupos de cenários em PostgreSQL temporário (PGlite), com compilação e execução da migração 025 sobre as funções anteriores, incluindo os ganchos reais de 1×1 e 2×2.
- Entre esses grupos, 228 comparações de poder (38 unidades × 6 ambientes) entre JavaScript e PostgreSQL, sem divergência.
- Verificação estática do projeto e dos arquivos SQL.

Não houve teste visual no navegador nem execução no banco de produção. As imagens impressas das cartas conservam a arte anterior; as descrições de habilidade e as regras do motor foram atualizadas. A ficha e a seção de história exibem o texto atual.
