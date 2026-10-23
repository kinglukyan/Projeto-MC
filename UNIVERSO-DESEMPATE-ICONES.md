# Universo, Desempate 1×1 e ícones épicos

## Universo

O banner principal tinha regras concorrentes para altura percentual, proporção automática e layout em grade, deixando a camada de imagem sem espaço próprio. A nova implementação usa uma imagem HTML dentro de uma área com proporção definida. O título e o botão ficam sobre essa área no desktop e abaixo dela em telas pequenas; a história permanece em sua própria área. As miniaturas usam os mesmos arquivos de arte.

## Desempate online 1×1

O modo independente passa a enfrentar dois jogadores reais, cada um usando um baralho salvo e suas próprias cópias de cartas. A fila possui busca, cancelamento e retomada. O servidor valida os baralhos, impede autoemparelhamento, calcula as mesmas puxadas para os dois participantes e guarda um único resultado. A regra permanece: o menor poder base vence; após cinco puxadas empatadas, o Eclipse decide.

A liberação administrativa já existente foi mantida, agora apresentada como “Liberar Desempate online 1×1”. Um resultado pendente pode ser consultado mesmo se a administração encerrar a disponibilidade de novas buscas. A confirmação ao terminar a apresentação evita que o mesmo resultado fique voltando depois de lido. Este modo usa um registro próprio de partidas; recompensas de moedas, XP ou rank específicas para ele não foram acrescentadas nesta atualização.

## Artes

Criadas pela ferramenta integrada image_gen, usando os emblemas dos modos existentes como referência:

- Um emblema para Desempate online: elmos, balança e Eclipse.
- Doze ícones de estratégia: Eclipse, Matilha, Pelotão, Submundo, Convergência, Realeza, Caos, Arsenal, Lunar, Proteção, Ofensiva e Combos.
- Quatro marcos: Primeira vitória, Dez vitórias, Vinte e cinco duelos e Cinco vitórias seguidas.

Os ícones mantêm os identificadores existentes; baralhos e personalizações salvos continuam apontando para a mesma estratégia. Os símbolos das facções continuam disponíveis. As condições e o progresso dos marcos foram preservados.

Os 17 PNGs originais transparentes estão em `_manutencao/artes-originais/epicos/`. As versões públicas usam WebP sem perdas, com transparência e resolução original preservadas. Os prompts exatos estão em `_manutencao/prompts-icones-epicos.json`. Prévia: `icones-epicos.html` e `_manutencao/PREVIA-ICONES-EPICOS.jpg`.

## Publicação

1. Se a revisão anterior já está publicada e os SQLs até 059 estão aplicados, executar apenas `supabase/migrations/202610220060_online_tiebreak_1v1.sql`.
2. Se ainda não aplicou 057–059, aplicá-los em ordem antes do 060.
3. Extrair o ZIP de atualização na raiz do projeto existente, mantendo a estrutura. Enviar os arquivos ao GitHub conectado à Vercel. O build já configurado atualiza os agrupamentos, a versão e o manifesto de cache.
4. Liberar “Desempate online 1×1” no painel administrativo quando desejar abrir a fila aos jogadores.

O site online não foi publicado por esta entrega. Não foram executadas partidas com duas contas, testes automatizados ou validação em dispositivos. O build do pacote foi preparado; a validação de duas contas no ambiente publicado permanece necessária após aplicar o SQL.
