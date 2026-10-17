# Correção do carregamento do inventário

O SQL 013 terminou com sucesso e o catálogo público já contém 54 cartas e 39 ícones.
Foi encontrado um erro no cliente: o carregamento do perfil escrevia em `#profile-wins`
e `#profile-losses`, que não existem mais no HTML. Isso provocava uma exceção antes
das chamadas que carregam inventário, cópias de cartas e baralhos. A falha acontecia
para todas as contas e era escondida pelo tratamento de erro na entrada.

Os campos antigos agora são opcionais. O carregamento conclui a leitura dos itens
antes de marcar a conta como pronta. Falhas futuras ficam visíveis com opção de tentar
novamente. As versões dos arquivos e o cache foram atualizados.

## Aplicar

Substitua os quatro arquivos deste pacote na raiz do site: online.js, index.html,
mobile.html e sw.js. Recarregue a página depois da publicação.

Não é necessário executar outro SQL para esta correção.
Não houve acesso aos inventários privados das contas nem alteração do banco remoto.
Foi conferida a sintaxe do JavaScript e a ausência dos dois campos no HTML.
