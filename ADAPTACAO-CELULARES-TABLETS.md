# Adaptação para celulares e tablets

## Correções

- Menu lateral: uma opção por linha, largura completa, ícones alinhados, textos legíveis e rolagem própria para acessar todas as opções em telas baixas.
- Cabeçalho: organização dos controles em duas linhas no telefone, com margens e áreas de toque adequadas.
- Meus baralhos: título e descrição com largura própria; ações abaixo do texto. Modo Construtor destacado, pesquisa e ordenação reorganizadas, slots dentro da largura disponível.
- Coleção: filtros com quebra de linha, busca e seleção de facção adaptadas e grade de duas cartas nos telefones.
- Loja: categorias reorganizadas, painéis e cartões adaptados à largura disponível.
- Perfil: painéis em uma coluna nos telefones, informações e ações sem ultrapassar a tela.
- Configurações e administração: formulários em uma coluna, botões com quebra de linha, tabelas com rolagem interna e categorias acessíveis por toque.
- Guilda, decks da comunidade, partidas personalizadas, fila, desafio direto e Guardião: títulos, botões e painéis adaptados aos espaços disponíveis.
- Hall, login, cadastro e boas-vindas: navegação e controles adaptados, símbolos de mitologia e leque preservados.
- Construtor: áreas da mesa e coleção acessíveis por rolagem em telefones de pouca altura; cabeçalho e ações permanecem acessíveis.
- Combate: corrigido o alinhamento da mão no tablet, que deixava as primeiras cartas fora do alcance da rolagem. A ampliação das cartas e os controles existentes foram preservados.
- Campos de texto com fonte de 16 px nas telas compactas para evitar o zoom automático ao focar no iPhone.

## Telas verificadas

As 14 telas principais foram abertas em 320, 390, 768 e 1024 px de largura: Arena, Meus baralhos, Coleção, Universo, Guilda, Decks da comunidade, Personalizada, Fila, Perfil, Configurações, Loja, Administração, Guardião e Desafio direto.

Também foram verificadas as janelas do construtor, laboratório de combos, cartas ampliadas, amigos, missões e os controles adicionais da administração. O fluxo inicial incluiu hall público, login, cadastro, escolha da mitologia e ampliação das cartas recebidas. Foi incluída uma prévia do combate em 844 × 390, na horizontal.

Nas 56 combinações de tela principal e largura, o documento permaneceu dentro da largura da janela. Listas de cartas e tabelas mantêm sua rolagem interna quando necessária.

## Limites da conferência

A verificação foi local no Chromium, com contas e respostas do servidor simuladas. Não foram executadas operações sobre contas reais. A conferência não incluiu um aparelho físico com Safari, nem partidas online entre jogadores reais.

## Publicação

Publicar o conteúdo completo do novo ZIP. Os HTML já incluem a nova folha `responsive-layout.css`, com versão calculada a partir do conteúdo. Esta adaptação não exige uma nova migração SQL.
