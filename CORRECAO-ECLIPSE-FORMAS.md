# Eclipse: formas humanas e lobisomens

## Regras aplicadas

- Solar: Alfa vira Mulher; Beta e Omega viram Homem.
- Lunar: lobisomens que foram transformados pelo Solar recuperam seu lobo original, inclusive Omega.
- Mulher e Homem jogados diretamente, **somente da facção Monstros**, viram Alfa e Beta durante o Lunar.
- Quando esse humano deixa de estar sob Lunar, recupera sua identidade original. Um humano de outra facção não recebe essa transformação.
- O poder é recalculado pela forma atual e pelas sinergias. O Lunar dobra o poder dos lobisomens; a transformação não acumula multiplicadores ao alternar repetidamente os Eclipses.
- Cada Homem fortalece os outros Homens, sem contar a si próprio. Mulher recebe a multiplicação pelos Homens aliados enquanto estiver na forma humana.
- A origem da carta é preservada para novas trocas de clima, proteção de fileira, silêncio e envio ao Submundo. Uma carta originalmente Homem não vira permanentemente um Beta; um Omega não perde sua identidade ao passar pela forma Homem.
- Partidas locais salvas são reconciliadas ao renderizar o combate. No servidor, o estado é reconciliado antes de processar ações e efeitos de início de turno.

## Instalação

Publique os arquivos da atualização e execute **supabase/migrations/202610180023_eclipse_monster_forms.sql** no Supabase, depois do SQL 022. Atualize a página para carregar as novas versões dos arquivos.

O SQL 023 atualiza as funções de transformação e as descrições de Homem/Mulher. Não foi executado no banco remoto nesta entrega.

## Verificações

Foram executados testes locais com as cartas reais do catálogo, jogando Eclipse com resultados Solar e Lunar controlados: alternância repetida das três espécies nos dois lados, humanos antes/depois da entrada do Lunar, restrição por facção, sinergia humana, silêncio, fim da rodada e recuperação da origem no Submundo. Também foram conferidas sintaxe e referências dos arquivos.

Exemplos sem outros bônus: dois Homens têm 2 de poder cada e Mulher acompanhada deles tem 8; no Lunar, um Alfa acompanhado de dois Betas tem 16, e cada Beta tem 4.

Os testes não incluem execução PostgreSQL ou uma partida online real.
