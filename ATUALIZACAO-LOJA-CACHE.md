# Loja, ampliação de cartas e atualizações com F5

Publique todos os arquivos deste pacote na raiz do site. Não há SQL novo.

- Imagens de campos e mãos ficam recortadas dentro dos quadros da loja.
- Clique na imagem ou no conteúdo de uma carta da loja para ampliar e ler os
  dados reais: nome, tipo, facção, poder, habilidade e história. Comprar continua
  sendo uma ação separada no botão de preço.
- A carta da coleção preenche o retângulo interno da ampliação, sem os limites
  antigos de altura. O tamanho acompanha a tela no celular.
- O F5 consulta os arquivos do servidor antes de usar o cache. O cache serve de
  reserva quando não há conexão. A instalação não baixa mais todas as imagens
  do jogo antes de ativar a atualização.
- Na transição do cache antigo, páginas abertas são recarregadas uma vez. Nas
  atualizações seguintes, partidas em andamento recebem aviso em vez de um
  recarregamento automático. Os dados de login permanecem guardados.
- O arquivo `_headers` reforça a atualização em hospedagens compatíveis.

As alterações estão no pacote local; nenhuma publicação remota foi realizada.
Foi conferida a sintaxe dos arquivos JavaScript; não foram executados testes
de navegador ou partidas.
