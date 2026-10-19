# Verso oficial das cartas e moeda da loja

A arte enviada foi mantida em sua forma original SVG e passou a ocupar `assets/card-back.svg`, o recurso compartilhado pelo jogo. O arquivo de origem estava nomeado como PNG, mas seu conteúdo já era SVG.

Isso atualiza mãos ocultas, pilhas de baralho, animações de compra, boas-vindas e abertura do pacote, desempate, detalhes sem arte e os demais componentes que usam esse recurso. Os filtros coloridos antigos sobre o verso foram removidos das pilhas e das compras para preservar a arte dos dois lados do campo.

A moeda da loja não tinha dimensões próprias na imagem interna e podia ocupar seu tamanho natural, ultrapassando a caixa do saldo. A caixa agora mede 42px e a moeda 32px. A mesma arte é carregada diretamente, sem trocar a imagem depois da abertura da tela.

Publicar o ZIP atualizado do site. Não exige novo SQL. Nada foi publicado automaticamente nesta conversa.
