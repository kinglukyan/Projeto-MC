# Correção do SQL 052

O erro 42601 na função `_gc_pick_play` era causado por uma expressão CASE sem parênteses dentro de uma condição IF. O CASE foi delimitado por parênteses, preservando os limites de jogadas e o balanceamento do Atlas.

Execute novamente o arquivo completo `supabase/migrations/202610210052_progression_rewards_atlas.sql`. Depois, continue com 053 e 054, nessa ordem. Não é necessário reaplicar 050 e 051 se elas já foram concluídas.

A fonte mantida e os geradores também foram corrigidos para evitar a recriação do problema. Esta correção não foi executada no banco online.
