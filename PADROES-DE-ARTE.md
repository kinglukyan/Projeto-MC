# Padrões visuais de Mythic Clash

## Prompts de produção

Antes de criar artes, ler `prompts-de-arte/LEIA-ME.txt` e usar o arquivo correspondente: `01-CHIBIS.txt`, `02-BANNERS.txt` ou `03-PERSONAGENS-CARTAS.txt`. Esses modelos orientam as próximas gerações; os prompts antigos de grades servem como histórico de produção. Nos chibis, manter o tratamento visual constante e variar somente a cor da aura conforme a paleta do personagem, preservando sua identidade aprovada.

## Referências de identidade

- Carta: Afrodite, original em `assets/cards-20261017/afrodite.png`; versão de jogo em `assets/cards-remake/afrodite.webp`.
- Chibi: Afrodite, centro superior de `assets/avatars-chibi/portraits-04.png`.
- Banner: cena de Afrodite em `assets/universe/banner-03.png`; arquivo individual em `assets/universe/restaurados/afrodite.webp`.

## Carta

Fantasia cinematográfica com anatomia adulta, rosto e figurino consistentes, iluminação dramática, cenários próprios e materiais detalhados. A ilustração não deve incluir a interface nem os textos da carta. A carta final mantém proporção 5:7; os quatro arquivos finais recebidos possuem 1500 × 2100 pixels. Moldura, títulos, poder, classe, símbolo e habilidade pertencem ao compositor TCG. Não redesenhar cartas prontas para criar chibis ou banners.

## Chibi

Cabeça grande, busto pequeno, olhos grandes e expressivos; pintura dimensional detalhada. Cabelo, joias, armaduras, coroas e cores seguem o personagem da carta. Fundo roxo escuro, reflexos dourados e silhueta legível em tamanho pequeno. Um personagem por arquivo quadrado; elementos importantes devem caber no enquadramento.

Héstia: cabelo acobreado, véu marfim, chama e terracota. Hera: cabelo escuro, olhos verdes, coroa de pavão, violeta e esmeralda. Deméter: cabelo castanho, coroa de trigo e manto verde. Perseu: cabelo escuro curto, elmo alado dourado e capa azul.

## Banner e miniatura

A mesma cena deve aparecer no banner e na miniatura. Preservar a proporção da fonte e separar texto da imagem. Não usar `object-fit: fill`, alargar recortes ou converter uma cena de grade diretamente em uma imagem inteira. Esta revisão extrai as 38 cenas das grades originais, sem redimensionar e com WebP sem perdas. Cada cena disponível tem 887 × 443 pixels; isso conserva os detalhes existentes, mas não cria detalhe adicional de uma fonte Full HD.

## Preservação

PNGs originais dos novos chibis em `_manutencao/artes-originais/chibis`. Arquivos públicos em WebP sem perdas. As cartas e os hologramas existentes foram mantidos. O build recalcula o manifesto e a versão; não rodar compressões cumulativas sobre os arquivos já comprimidos.
