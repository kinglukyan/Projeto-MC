# Elenco grego do Atlas

## Ordem atual

| Nível | Adversário |
| --- | --- |
| 1 | Aquiles |
| 2 | Hércules |
| 3 | Hermes |
| 4 | Minotauro |
| 5 | Soldado de Esparta |
| 6 | Afrodite |
| 7 | Dionísio |
| 8 | Personagem misterioso — aguardando definição |
| 9 | Personagem misterioso — aguardando definição |
| 10 | Apolo |
| 11 | Medusa |
| 12 | Hefestos |
| 13 | Personagem misterioso — aguardando definição |
| 14 | Personagem misterioso — aguardando definição |
| 15 | Athena |
| 16 | Ártemis |
| 17 | Ares |
| 18 | Poseidon |
| 19 | Hades |
| 20 | Zeus |

Os níveis 8, 9, 13 e 14 usam a mesma silhueta chibi preta com interrogação dourada. Continuam jogáveis com decks gregos provisórios, sem atribuir a identidade de um personagem aos seus adversários. Nenhuma carta fictícia foi adicionada à coleção ou à loja. Os futuros personagens substituirão essas reservas quando forem enviados.

O Soldado de Esparta usa seu ícone chibi existente no nível 5. O diálogo de Aquiles no nível 1 foi preservado. O progresso já registrado, os tesouros e o histórico das contas não são reiniciados.

## Publicação

Após a 052, aplique `supabase/migrations/202610210053_greek_roster_placeholders.sql` no Supabase e publique os arquivos atualizados pelo GitHub/Vercel. O catálogo local e o servidor precisam da atualização para mostrar os mesmos nomes no mapa, na partida e no resumo.

## Arte e manutenção

Ícone: `assets/guardian-campaign/atlas/mystery-chibi.png`. Imagem criada com a ferramenta integrada de geração de imagens, com fundo transparente. O prompt completo está em `_manutencao/guardian-atlas/personagem-misterioso-prompt.json`.

Fontes de dados: `_manutencao/guardian-campaign/catalogo-servidor.json` e `guardian-campaign-data.js`. O script `_manutencao/guardian-campaign/gerar-elenco-053.py` sincroniza os dados públicos e gera a migração 053 a partir do catálogo servidor.

Compilação e sintaxe conferidas. Não houve publicação, execução de SQL no banco online ou testes de partidas.
