# Bônus por fileira, Apolo e hologramas

- Soldados de Esparta, Alfa/Betas, Homem/Mulher, Guardião Nórdico e Rei de Todos consideram somente aliados da mesma fileira para os bônus de grupo.
- Exemplo: dois Homens na primeira fileira têm 2 de poder cada; o Homem sozinho na segunda permanece com 1, antes de outros bônus.
- Ares fortalece os aliados elegíveis da própria fileira na entrada. Rá fortalece os egípcios da própria fileira no fim da rodada.
- Apolo passa a conceder uma aura contínua: dobra a força de todos os aliados da sua fileira, incluindo ele próprio e quem entrar depois. Ao mover uma carta para outra fileira ou retirar Apolo, a aura é recalculada. Vários Apolos na mesma fileira acumulam suas duplicações.
- Os bônus de Local, Terreno e Clima continuam seguindo suas regras próprias.
- Todos os hologramas comuns ficaram 25% maiores. Os lobisomens sob Lunar recebem 15% adicionais sobre o novo tamanho geral. A formação dos companheiros e o espaço acima das cartas foram ajustados para acomodar o crescimento.

## Instalação

Publique os arquivos e execute **supabase/migrations/202610180024_lane_buffs_apollo_aura.sql** após o SQL 023. Atualize a página. Para avaliar a nova aura sem misturar multiplicadores de partidas anteriores à atualização, comece uma nova rodada ou reinicie o modo teste.

O SQL não foi executado no banco remoto. Foram conferidos estaticamente sintaxe e referências; não foram executadas novas partidas de teste nesta alteração.
