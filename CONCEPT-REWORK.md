# Interface inspirada nas concept arts aprovadas

Aplicada à versão principal em `outputs/mythic-clash`.

## Recursos e telas

- Citadela luminosa com cachoeiras, cinco novos emblemas de modos e moldura dourada escalável.
- Arena com cinco cartões, últimas partidas e baralhos em destaque.
- Meus baralhos com galeria, busca, ordenação, prévia e acesso ao editor original.
- Coleção com grade e painel lateral da carta selecionada.
- Universo com lista de lendas e leitor de história, áudio e HQ existentes.
- Guilda com membros reais, missões semanais e guerras existentes.
- Missões no modal existente, com percurso visual e barras de progresso.
- Comunidade com galeria, autores, votos, busca e cópia de código.
- Loja com destaque, prévia do produto e ações reais de compra/equipar.
- Filas e sala personalizada com painéis de equipe, emblemas e prévia do próprio baralho.
- Configurações organizadas em grupos com os controles existentes.
- Administração organizada em categorias, mantendo a autorização original.
- Tratamento visual dos diálogos de amigos e da conversa flutuante.
- Layouts adaptados a larguras menores, usando a mesma entrada do webapp.

## Preservação

A barra lateral e o HTML da tela de combate foram preservados. Os arquivos de estilos anteriores e a lógica de combate não foram modificados. As novas regras de estilo excluem a tela de combate, e o novo cabeçalho fica oculto durante as partidas.

O tema apresenta os dados existentes. Não foram criadas moedas, estatísticas, recompensas, jogadores ou cartas de exemplo para imitar as artes. Recursos que aparecem nas referências mas não existem no servidor, como chat de guilda ou mapa de territórios, não foram adicionados como controles fictícios. Os formatos de partida continuam obedecendo ao suporte atual do jogo.

## Arquivos e publicação

O tema está em `concept-theme.css` e `concept-theme.js`; os recursos estão em `assets/concept-ui`. `CONCEPT-ART-ASSETS.json` registra os prompts completos. A entrada principal e o cache do webapp foram atualizados para carregar os arquivos novos.

Publique todo o conteúdo desta pasta, mantendo os recursos e os caminhos. O pacote `mythic-clash-rework-principal.zip` contém essa versão. O trabalho foi realizado localmente; não houve publicação automática.

Não foram executados testes ou validação visual no navegador nesta entrega. A preservação do menu e do combate foi conferida por comparação dos arquivos com o backup. Nenhuma migração SQL nova é necessária para este tema; migrações anteriores continuam seguindo seu processo normal.


## Ajuste do chat e do Universo

- Corrigido o conflito entre a posição relativa dos painéis e a posição fixa do chat. A conversa fica no canto inferior direito, com rolagem própria e espaço para a navegação móvel.
- Parágrafos da história passam a usar fonte regular, espaçamento consistente e quebra de texto natural.
- Banners dos personagens na biblioteca, com prévia ao passar o mouse ou focar pelo teclado. O clique abre o texto. Em aparelhos de toque, o clique abre diretamente a história.
- A entrada A Convergência aparece antes dos personagens e permanece disponível em todos os filtros. Foi criada uma introdução narrativa local, editável no objeto `convergence` em `concept-theme.js`.
- Estrela original desenhada em SVG (`assets/concept-ui/convergence-star.svg`). Os banners aproveitam as artes e os hologramas disponíveis, sem gerar personagens diferentes.
- Cache do tema atualizado para a versão 2.
