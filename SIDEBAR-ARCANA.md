# Barra lateral — Convergência Arcana

Implementação do conceito 3 escolhido pelo usuário.

## Visual

- Cristal escuro com textura original criada pela ferramenta integrada de geração de imagens.
- Molduras prateadas, emblema da Convergência em vetor e destaque violeta na opção ativa.
- Ícones em SVG para manter nitidez em diferentes tamanhos de tela.
- Tipografia, perfil, nome, rank, contagem de cartas e resultados usando os dados reais existentes.
- As imagens conceito tinham valores fictícios de demonstração. Eles não foram incluídos no jogo.

## Desktop

Barra fixa de 286 px, ou 266 px entre 961 e 1200 px de largura. Cabeçalho e perfil ancorados; navegação central com rolagem independente quando necessário. Menus de Baralho, Amigos e Missões mantêm os elementos e eventos existentes.

## Celular e tablet

- Até 960 px: botão Menu na barra superior e painel lateral retrátil.
- Painel com altura dinâmica da tela, margens seguras e rolagem interna.
- Controles principais de pelo menos 44 px, opções de navegação de 50 px.
- Fundo da página bloqueado enquanto o painel está aberto.
- Fechar pelo botão ×, toque fora ou Escape; o foco retorna ao botão Menu.
- Tab permanece dentro do painel aberto. O conteúdo atrás fica inativo até o fechamento.
- Ao escolher uma página ou ação, o painel fecha. Os botões de expansão dos submenus mantêm o painel aberto.
- Navegação oculta durante o combate, seguindo a estrutura existente.
- Adaptação a telas baixas em orientação horizontal e preferência por movimento reduzido.

## Arquivos

- `sidebar-arcane.css`: estilos isolados da barra e do botão de menu.
- `sidebar-arcane.js`: ícones, painel móvel, foco e estados acessíveis.
- `assets/sidebar-arcane/crystal-texture.png`: imagem decorativa sem textos.
- `assets/sidebar-arcane/arcane-crest.svg`: emblema vetorial.
- `assets/sidebar-arcane/texture-prompt.json`: prompt e método da imagem.
- `index.html`: carrega os novos estilos e comportamento.
- `sw.js`: versão de cache e arquivos novos para acesso offline.

O HTML do menu preserva seus IDs e os elementos são reaproveitados. O código das regras, autenticação e rede não foi alterado nesta atualização. O combate mantém sua estrutura e estilos.

## Entrega

Atualização local incluída em `mythic-clash-rework-principal.zip`, pronta para substituir os arquivos da hospedagem. Esta alteração de menu não exige uma nova migração SQL. As migrações das cartas, de entregas anteriores, continuam no pacote com suas pendências documentadas.

Revisão estática dos estilos, eventos e referências. Não foram executados testes de navegador nem de aparelhos nesta entrega.
