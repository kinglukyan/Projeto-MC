# Ícones e desempate pelo Eclipse

## Instalação

1. Aplicar o SQL `supabase/migrations/202610180030_random_eclipse_tiebreak.sql`, depois do 029.
2. Publicar o conteúdo completo do novo ZIP.

## Visuais

- Sete novos emblemas de rank, mantendo os nomes e faixas atuais.
- Dez medalhas e oito brasões para títulos, apresentados em atlas para reduzir requisições.
- Moeda Mythic Coin com a estrela de quatro pontas da Convergência.
- Efeito de energia Lunar e Solar para a revelação do Eclipse.
- VS centralizado entre os painéis da fila e na apresentação das partidas, inclusive em tamanhos compactos.

Imagens produzidas com a ferramenta integrada image_gen. Os prompts estão em `assets/identity-v2/generation-prompts.json`. As imagens WebP preservam a transparência.

## Desempate

O desempate se aplica ao empate final da partida. Não altera o encerramento normal de um Round.

1. O servidor sorteia uma unidade de cada baralho, respeitando a quantidade de cópias. Compara o poder base, sem bônus de campo ou equipamentos.
2. O menor poder vence. Se os poderes forem iguais, acontece outra puxada, até cinco.
3. Após cinco puxadas empatadas, Lunar é atribuído a um lado e Solar ao outro. O sorteio final tem 50% para cada face. Vence o lado correspondente à face revelada.
4. Nas duplas, a decisão vale para a equipe e utiliza as unidades dos baralhos de seus integrantes.
5. Se o conjunto de unidades se esgotar antes de cinco puxadas, ele é reposto com as mesmas cópias originais. Sem unidades disponíveis em um dos lados, a decisão segue diretamente para o Eclipse.

O resultado online é calculado e salvo uma única vez sob bloqueio da partida. Atualizar a página recupera a mesma decisão. O cliente apresenta a animação; não escolhe as cartas nem o vencedor. Recompensas e classificação são ajustadas a partir do registro anterior de empate, evitando crédito repetido.

No Guardião, o servidor também sorteia o resultado, respeitando o limite de recompensas já existente. O baralho do jogador é conferido com a coleção; o Guardião utiliza as unidades de seu baralho padrão.

## Animação

As cartas entram viradas, são reveladas juntas e exibem seus poderes. O histórico registra cada puxada. Depois dos cinco empates, aparece a atribuição Lunar/Solar. O Eclipse central permanece neutro durante o sorteio e só mostra a face final na revelação. Há opção de reduzir animações e suporte à preferência de movimento reduzido do dispositivo.

## Conferências

Foi conferida a sintaxe dos scripts e compilado o SQL em PostgreSQL temporário. As prévias visuais usam respostas simuladas nos fluxos de vitória por unidade, cinco empates e revelação Lunar, em desktop e celular. Nenhuma migração foi executada no banco real e o pacote não foi publicado remotamente.
