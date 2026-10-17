# Correção da regressão de carregamento

Publique todos os arquivos deste pacote e pressione F5. Não há SQL novo.
O layout compacto do construtor de decks foi mantido.

- HTML continua sendo consultado no servidor para mostrar as versões novas no F5.
- Scripts e estilos com versão no endereço reutilizam a cópia local. Quando uma
  atualização muda a versão, o navegador busca o arquivo novo.
- Imagens salvas aparecem imediatamente. A consulta de versões acontece em segundo
  plano e deixa de bloquear HTML, imagens e fontes.
- Foram retirados os abortos de downloads após 4 segundos, que podiam impedir o
  carregamento em conexões mais lentas. Os caches existentes são preservados.
- Perfil e sincronização de inventário iniciam juntos. Nome, saldo e dados do perfil
  podem aparecer antes de terminar a entrega de itens; o inventário ainda é lido
  depois da sincronização. Missões e comunidade não aguardam mais o perfil terminar.
- Chamadas simultâneas de comunidade compartilham a mesma leitura.

Esta correção está em arquivos locais. Não foi publicada nem medida no navegador
do usuário. A sintaxe dos arquivos JavaScript foi conferida.
