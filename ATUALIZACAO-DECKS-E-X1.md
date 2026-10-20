> A tela X1 foi reunida à Personalizada na atualização seguinte. Consulte `ATUALIZACAO-CARREGAMENTO-E-CONTINUIDADE.md` para a interface atual e o SQL 043.

# Decks personalizados, avaliador e sala X1 — 20/10/2026

## Publicação

1. Aplicar `supabase/migrations/202610200042_deck_identity_direct_room.sql` no Supabase, após os SQLs 040 corrigido e 041 da coleção Remake.
2. Subir o conteúdo atualizado desta pasta para o GitHub conectado à Vercel, mantendo `vercel.json`, `_manutencao` e a estrutura dos arquivos.
3. Aguardar a publicação da branch de produção terminar.

Esta entrega foi atualizada localmente. O site e o banco remoto não foram alterados nesta execução. Foram feitas checagens de sintaxe e conferência das referências de arquivos; partidas de teste não foram executadas.

## Personalizar baralhos

Em **Baralhos**, selecione o deck e clique no brasão ou em **Personalizar deck**.

- 12 símbolos de facção, usando os mesmos desenhos das cartas.
- 12 brasões de estratégia: Eclipse, Matilha, Pelotão, Submundo, Convergência, Realeza, Caos, Arsenal, Lunar, Proteção, Ofensiva e Combos.
- Paleta visual e seletor de cor, sem precisar digitar códigos.
- Nome, ícone e fundo são salvos no deck da conta.
- Os símbolos aparecem na galeria, na Arena e no baralho selecionado nas salas.
- A exclusão de um deck reorganiza os slots preservando a identidade dos restantes.

Salve um deck novo no construtor antes de personalizá-lo. O SQL 042 adiciona colunas às montagens existentes; não altera cartas, poderes, recompensas ou quantidades da coleção.

## Avaliador

Disponível em **Avaliar baralho**, no detalhe de um deck; em **Avaliar este baralho**, nas salas; e em **Avaliar deck**, no construtor. No construtor, considera a edição atual, inclusive mudanças ainda não salvas. Não modifica sua montagem.

O índice vai de 0 a 100 e é uma análise de composição, não uma chance de vitória:

| Critério | Peso | O que considera |
|---|---:|---|
| Consistência | 25 | Probabilidade de ter duas unidades nas primeiras cinco cartas e proporção de unidades |
| Sinergia | 30 | Presença e quantidade de apoios compatíveis para os efeitos dependentes |
| Autonomia | 20 | Unidades disponíveis e dependências sem suporte |
| Respostas | 15 | Controle, redução, movimento, silêncio, remoção e efeitos equivalentes |
| Fôlego | 10 | Compra, seleção, informação, recuperação e proteção |

As probabilidades são combinatórias: compra de cinco cartas sem reposição. A chance de combo exige uma cópia da fonte e a quantidade mínima de apoios; cópias da mesma unidade são contadas sem sobreposição indevida. Compras extras, buscas e trocas não entram nessas porcentagens. Elas não preveem a disponibilidade de alvos no campo ou Submundo.

O avaliador reconhece portadores dos equipamentos atuais, terrenos e locais, companheiros, Betas e Alfa, as 70 regras Remake e papéis dos personagens anteriores. Auras de fileira exigem posicionamento. A análise chama atenção para Eclipse, Locais compartilhados, Artemis com Monstros e o efeito de Nergal nos dois lados. Recomendações de apoio usam apenas cartas disponíveis na coleção, incluindo cópias livres de uma carta já usada.

A nota só é apresentada como índice quando a montagem é válida: de 14 a 35 cartas, quantidades inteiras, cópias suficientes e nenhuma carta especial exclusiva, de prévia ou pausada. O avaliador é uma ferramenta de aconselhamento do cliente; a validação oficial das partidas permanece no servidor.

## Sala X1

- Quadros de jogador e adversário no mesmo padrão visual das salas de fila.
- O botão **+** abre os amigos, com online primeiro, ícone e elo.
- Convite direto para um amigo ou geração de código compartilhável.
- Entrada com código recebido, seletor de deck e avaliação na própria sala.
- Código pendente com prazo, botão de copiar e cancelamento.
- Convites existentes restaurados da conta ao abrir a sala.
- A partida começa quando o convidado aceita, seguindo o propósito de desafio direto.
- O convite recebido usa uma janela flutuante na camada superior.

As operações novas verificam a conta, limitam a frequência de chamadas e só permitem ao dono personalizar seu deck ou cancelar seu próprio convite.

## Arquivos principais

- `deck-identity.js` e `assets/deck-icons/`: catálogo e personalização.
- `deck-evaluator.js`: algoritmo e relatório explicativo.
- `direct-lobby.js`: sala de desafio direto.
- `deck-tools.css`: adaptação visual para computador, tablet e celular.
- `supabase/migrations/202610200042_deck_identity_direct_room.sql`: persistência e operações da sala.
