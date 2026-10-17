# Cartas de terreno

As oito artes originais foram copiadas sem alteração para `assets/terrains/`. Troia conserva o ID anterior `campo-troia` para manter os baralhos salvos. As demais sete cartas ampliam o catálogo de 42 para 49 cartas.

| Terreno | Bônus enquanto ativo |
| --- | --- |
| Yggdrasil | Odin +2 |
| Alto Egito | Todos os egípcios +2 |
| Baixo Egito | Todos os egípcios +2 |
| Bifrost | Todos os nórdicos +2, exceto Loki |
| Esparta | Espartanos +2; Ares +3 |
| Labirinto de Dédalos | Minotauro e monstros gregos +2 |
| Troia | Aquiles, Athena e Ares +3 |
| Nilfheim | Loki e gigantes de gelo +2 |

## Funcionamento

- Os terrenos usam o espaço compartilhado de Terreno já existente.
- O bônus beneficia as cartas elegíveis dos dois jogadores, seguindo a regra anterior de terreno compartilhado.
- Um único terreno ativo por rodada; outro não pode ocupar o espaço enquanto estiver preenchido.
- O bônus é recalculado para cartas presentes e futuras, sem alterar permanentemente seu poder base. Termina quando o terreno é removido no encerramento da rodada.
- O Minotauro recebe +2 uma vez no Labirinto, sem duplicação por também ser monstro grego.
- Ares recebe +3 em Esparta. O +2 dos espartanos não é aplicado adicionalmente a ele.
- Medusa e Minotauro estão classificados como monstros gregos. O Soldado de Esparta é espartano.
- Loki, Leônidas e gigantes de gelo têm identidades de alvo reservadas nas regras, mas não foram criadas cartas jogáveis para eles. Os bônus correspondentes serão aproveitados quando essas cartas forem cadastradas e liberadas.
- Os 29 personagens novos que estavam em prévia continuam em preparação. Esta entrega implementa os terrenos, sem liberar efeitos de personagens ainda não implementados.
- As cartas de terreno estão disponíveis na edição local para montar baralhos e jogar contra o Guardião. O jogo usa sua regra existente de três cópias iniciais por carta liberada. Custos novos não foram inventados; não há pagamento de energia no motor atual.

## Online e publicação

Aplicar `supabase/migrations/202610170005_terrain_cards.sql` no Supabase **depois das migrações anteriores e antes de publicar o ZIP**.

Essa migração cadastra as oito artes no catálogo público, amplia a validação de baralhos e ações para os sete terrenos novos, mantém as verificações de autenticação/turnos e aplica os bônus no servidor para 1v1 e 2v2. Aceita entradas de quantidade zero do catálogo, sem liberar personagens em prévia com quantidade positiva. Mantém Athena e Alfa alinhados entre as duas rotinas de ações online.

A migração está no pacote e ainda não foi aplicada no servidor remoto. Não foram executados testes de partidas, navegador ou SQL nesta entrega.

## Arquivos

- `terrain-cards.json`: catálogo, classificação e regras compartilhadas.
- `terrain-cards.js`: registro dos terrenos e cálculo dos bônus no navegador.
- `app.js`: integração do catálogo e do cálculo na partida.
- `terrenos.html`: galeria com nomes, imagens e efeitos, adaptada a telas pequenas.
- `supabase/migrations/202610170005_terrain_cards.sql`: alterações correspondentes no servidor.
- `sw.js`: cache dos arquivos desta edição.

A estrutura visual do combate e a barra lateral arcana foram mantidas.
