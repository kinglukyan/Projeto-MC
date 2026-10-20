# Cartas Remake — 20/10/2026

## Conteúdo desta entrega

- 108 cartas recebidas: 70 novas e 38 atualizadas, com os poderes e textos lidos das imagens.
- 71 hologramas novos e 71 ícones chibi novos. As outras 37 imagens de cada tipo foram aproveitadas da coleção existente.
- O Soldado de Esparta recebeu novo holograma. Rei de Todos recebeu ícone próprio.
- Galerias: `cartas-hologramas.html` e `icones-chibi.html`.
- Uma carta virtual de Clone Macaco, com poder 2 e sem habilidade, para a invocação de Sun Wukong.
- Cartas para o site com largura de 1100 pixels, seguindo o tamanho usado antes. As cópias em resolução recebida ficam em `_manutencao/remake/cartas-resolucao-recebida/`.
- Hologramas e chibis produzidos pela ferramenta integrada de criação de imagens. Prompts e iterações: `_manutencao/remake/prompts-selecionados.json`.

## Publicar no jogo online

Esta pasta está atualizada localmente. O domínio da Vercel e o banco Supabase não foram atualizados nesta execução.

1. No Supabase, aplicar `supabase/migrations/202610200040_remake_character_collection.sql`, após a migração 039.
2. Aplicar `supabase/migrations/202610200041_remake_chibi_icons.sql`.
3. Publicar esta pasta na Vercel, usando seu `vercel.json`. O build existente exclui `_manutencao` da pasta pública.

Os IDs antigos e as coleções já obtidas foram preservados. Cartas novas seguem o preço atual de 1000 MC e ícones, 500 MC. Preços e pausas personalizados de itens existentes são preservados pela migração.

## Interações adotadas

- Efeitos de entrada atingem os alvos presentes naquele momento; auras acompanham entradas, saídas e mudanças de fileira.
- Silêncio individual desativa a habilidade da unidade, mantendo equipamentos e efeitos externos. Dionísio conserva seu silêncio global.
- Apenas efeitos com “pode” ou “até” oferecem a opção de concluir sem escolher um alvo, quando houver alvos válidos.
- Proteções de Heimdall, Durga, Vishnu, Curupira, Chang'e e Boitatá são consideradas pelos efeitos correspondentes.
- Reduções diretas são bloqueadas por Vishnu. Remover um equipamento ou uma fonte de aura continua sendo uma ação distinta.
- Erlang Shen remove modificadores positivos armazenados e suspende o poder dos equipamentos já anexados. Auras contínuas continuam dependendo de sua fonte ativa.
- Efeitos limitados por Round mantêm sua memória na ressurreição; equipamentos não voltam anexados.
- Clones são unidades temporárias: não entram no baralho nem na mão e desaparecem ao sair do campo ou ao encerrar o Round.
- Escolhas atribuídas ao adversário, como um empate de alvos de Shiva, usam a fila de efeitos com tempo limitado e sem revelar cartas privadas.

## Manutenção

O catálogo final está em `abilities-data.json`; as 70 regras novas, em `remake-rules.json`. O motor de treino está em `abilities-engine.js`, e sua versão de servidor, na migração 040. O compilador da pasta `_manutencao/remake` recompõe o SQL a partir desses dados.

Foram realizadas conferência visual dos arquivos e checagens de sintaxe. Não foram executadas partidas de teste nem migrações no banco remoto.
