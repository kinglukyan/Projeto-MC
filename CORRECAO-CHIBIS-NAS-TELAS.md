# Correção dos chibis nas diferentes telas — 2026.10.22.5

O ajuste anterior criou uma moldura com tamanho de 100%, que nas listas entrava nas regras de texto flexível e crescia além do ícone. Agora os quatro retratos usam a mesma moldura de tamanho dos chibis existentes, mantendo apenas o recorte facial como regra específica.

- Lista de membros e perfis públicos: 52 × 52 pixels, circular.
- Autor de deck na comunidade: 36 × 36 pixels, circular.
- Perfil, barra lateral, avatares de batalha, loja e seletor: dimensões já definidas por cada componente.
- O enquadramento aprovado no perfil é mantido.
- Trocar entre os quatro retratos e os ícones de outras personagens reutiliza uma única moldura, sem empilhar recortes.

## Aplicar

Extrair Atualizacao-Correcao-Chibis.zip na raiz do projeto que já recebeu a versão 2026.10.22.4. Publicar os arquivos no GitHub conectado à Vercel. Não há novo SQL nesta correção; as regras de guildas e nicknames da atualização anterior são mantidas.

Build local preparado. Não foram realizados testes de navegação ou publicação online nesta entrega.
