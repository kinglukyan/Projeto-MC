# Inventário, loja e acesso à Arena

## Aplicação

1. No SQL Editor do Supabase, execute `supabase/migrations/202610170013_inventory_shop_onboarding.sql` depois da migração 012.
2. Publique os arquivos deste pacote e recarregue o site.

O SQL não foi executado no banco remoto por esta atualização.

## Alterações

- O bloqueio de novato acompanha o carregamento do perfil, a troca de conta e a abertura da Arena. Contas com progresso ou partidas anteriores têm o acesso reconciliado.
- O administrador recebe automaticamente todos os itens cadastrados, além das novas inclusões. Novas artes de personagens no editor também atualizam a loja.
- Cada conta comum recebe, uma única vez, 2 ícones aleatórios e 14 cartas diferentes: 10 personagens e 4 cartas de outros tipos. O sorteio acontece no servidor.
- Contas existentes recebem o pacote inicial uma vez; seus itens anteriores, compras e presentes são preservados, inclusive os ícones gratuitos da migração 012.
- A coleção passa a usar quantidades realmente adquiridas. Baralhos antigos são ajustados e o baralho ativo recebe uma seleção válida se ficar com menos de 12 cartas.
- Resgates aguardam a atualização do saldo, inventário, coleção, seletor de ícones e loja. O botão fica ocupado durante o resgate, sem envio duplicado.
- Ícones custam 500 Mythic Coins e cartas custam 1.000 Mythic Coins. Itens adquiridos exibem o selo “Você já tem”; cartas adquiridas não são cobradas novamente.
- Transformações especiais (Lukyan Rei de Todos e resultados Lunar/Solar) continuam exclusivas dos efeitos que as geram, sem venda ou entrada direta no baralho.
- A moeda Clash Bit continua preparada e invisível.

## Conferência realizada

Arquivos JavaScript conferidos quanto à sintaxe. Não foram executados testes de navegador, partidas ou operações no banco remoto.
