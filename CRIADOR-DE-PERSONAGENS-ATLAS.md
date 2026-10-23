# Criador de personagens do Atlas — 2026.10.23.4

## Instalação
1. Usar esta versão revisada do SQL `supabase/migrations/202610230065_atlas_character_creator.sql`, após o SQL 064. O SQL 065 anterior foi substituído. Não executar primeiro a versão rejeitada.
2. Publicar os arquivos atualizados do jogo juntos, incluindo as artes em `assets/atlas-creator/kael/`.
3. O SQL também pode ser reaplicado caso a primeira versão tenha sido executada. Fichas antigas voltam ao criador para serem salvas no catálogo novo.

## Entrega atual
- 80 combinações de artes completas: seis partes superiores, três calças, três botas e três cortes. Os 54 looks de cabelo médio estão disponíveis; curto e longo estão disponíveis nos looks já concluídos.
- Cabelo castanho original e pele bronzeada, conforme as pranchas prontas. As amostras isoladas de outras cores não são aplicadas a roupas sem artes concluídas.
- Combinações ausentes ficam desabilitadas. Não há substituição silenciosa ao selecionar uma opção.
- Nome, altura (140–220 cm) e idade (18–100) salvos na ficha. Altura é informação da ficha e não deforma as artes.
- Três retratos: normal, falando e rindo, recortados das mesmas artes da aparência selecionada.
- Salvamento na conta e entrada no mapa; botão Meu personagem para editar. Nenhum recurso da composição modular rejeitada é carregado pelo criador novo.
- Prévia independente em `criador-atlas-previa.html`: salva apenas neste navegador, sem entrar em uma conta ou iniciar partidas.

## Adicionar artes depois
Adicionar a WebP da prancha completa (layout canônico 1536 × 1024) à pasta kael; incluir a entrada em atlas-creator-data.js e a linha correspondente no catálogo do banco via nova migração. Regerar os arquivos agrupados com `_manutencao/gerar-interface.cjs`. Cores futuras precisam também de campos e validações próprios, sem máscaras de trabalho ou filtros globais na arte final.

## Limites da entrega
Arquivos preparados localmente. Não foi aplicado SQL no servidor nem feita publicação online nesta tarefa. Não foram executados testes automatizados ou de partidas.
