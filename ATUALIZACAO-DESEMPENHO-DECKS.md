# Carregamento mais leve e cartas lado a lado

Publique os arquivos deste pacote na raiz do site, incluindo `asset-manifest.json`.
Não há SQL novo. Pressione F5 após publicar.

- A abertura não espera as imagens de telas fechadas nem um atraso fixo de 2 segundos.
- Imagens da coleção, loja e editor carregam conforme ficam visíveis. Áudio não é
  baixado antecipadamente. Consultas secundárias da comunidade aguardam o perfil.
- F5 continua buscando HTML, scripts e estilos atuais. Um pequeno manifesto de
  versões permite reutilizar imagens e fontes sem alterações imediatamente; arquivos
  alterados são buscados novamente. O manifesto é regenerado no pacote completo.
- O construtor mostra cartas compactas lado a lado, com quantidade e botões abaixo,
  adaptando o número de colunas à largura da tela. Os controles atuais são mantidos.

Na primeira abertura após esta atualização, as imagens visíveis ainda precisam ser
armazenadas no novo cache. As seguintes reutilizam esses arquivos. O ganho real depende
da conexão e da hospedagem; não foram medidos tempos de carregamento no site publicado.

Se atualizar imagens manualmente no futuro, gere e publique um novo `asset-manifest.json`
com os respectivos hashes. Sem atualizar o manifesto, imagens com o mesmo nome serão
reutilizadas. O script de empacotamento do projeto já faz essa geração automaticamente.
