# Cenários das boas-vindas e página pública

## O que muda

- Escolha de mitologia com os símbolos de Grécia, Nórdicos, Egípcios e Alyn.
- Cenários enviados aplicados atrás dos símbolos: templo grego, reino nórdico e templo egípcio. A moldura recorta a imagem, que recebe leve desfoque e sombra para manter os textos legíveis.
- Alyn usa a cidadela como cenário enquanto não houver uma arte própria de seu reino.
- A última imagem enviada aparece ao fundo da página pública em uma camada de opacidade exatamente 0,5. O filtro roxo é outra camada acima da imagem.
- Leque ampliado dos presentes: cartas vizinhas clicáveis, arraste para a esquerda/direita, botões e setas do teclado.
- Todas as referências de JavaScript e CSS passam a usar um resumo do conteúdo real do arquivo na URL. Alterar um arquivo muda sua URL na próxima geração do pacote, evitando reutilizar código antigo sob o mesmo número manual de versão.
- O cache das imagens existentes e a autenticação são preservados. As quatro imagens novas foram exportadas em WebP para reduzir o download.

## Publicar

Substituir os arquivos do site pelo conteúdo do pacote completo atualizado, incluindo `index.html`, `welcome.js`, `portal-upgrade.js`, `portal-upgrade.css`, `sw.js` e as novas imagens de `assets/onboarding/`. Substituir apenas arquivos SQL não atualiza a interface.

Depois de publicar, usar F5 para obter o novo HTML e suas referências de código. Este ajuste visual não tem um SQL novo; as migrações 027 e 028 da entrega anterior continuam sendo os pré-requisitos das funcionalidades de Alyn e administração.

O comportamento de cache por conteúdo é aplicado pelo gerador `outputs/package-concept-rework.py`. Manter esse processo nas próximas entregas evita reutilizar manualmente os mesmos números de versão.

## Revisão

Prévia local da página pública, escolha de mitologia e ampliação em computador e celular, com autenticação simulada. As capturas estão em `outputs/welcome-scenes-update`, fora do site publicado. Nenhuma publicação remota ou modificação de presentes/contas foi realizada.
