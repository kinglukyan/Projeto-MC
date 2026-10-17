# Coleção e ícones iniciais

1. Execute no Supabase a migração `202610170014_owned_collection_icons.sql`, depois da 013.
2. Publique os arquivos atualizados do site e recarregue a página.

A coleção e o editor de baralhos mostram apenas cartas realmente possuídas. Os
contadores e filtros usam essa mesma coleção. Novas cartas aparecem após a compra
ou resgate. A prévia lateral também é limpa quando uma carta deixa de estar visível.

A migração retira a liberação gratuita de todos os chibis da atualização 012 nas
contas comuns e mantém os dois ícones iniciais aleatórios. Compras realizadas depois
da entrega inicial e recompensas comprovadas de códigos são preservadas. Os ícones
retirados são arquivados em tabela privada para recuperação administrativa.

O Capacete de Ares (`ares-helm`) sai da loja, do seletor, dos perfis e dos ícones
alternativos de guildas. Ele não será concedido novamente ao administrador. O
registro inativo permanece no banco para respeitar referências históricas.

O administrador continua recebendo o catálogo restante. Cartas não foram removidas
das contas. Esta migração não foi executada no banco remoto pelo assistente.
