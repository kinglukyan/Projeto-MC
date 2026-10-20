# Atualização — habilidades e Universo

## O que foi entregue

- Revisão das 128 cartas/formas do catálogo em `REVISAO-HABILIDADES.md`.
- Correções locais e online de proteção, movimentação, escolhas, recuperação de cartas, silêncio, identidade copiada e cálculos de poder.
- Registro separado de bônus e reduções, para as limpezas de Brigid, Nüwa, Utu e Erlang funcionarem quando há efeitos que se anulam.
- 70 banners individuais para os novos personagens Celtas, Japoneses, Hindus, Chineses, Astecas, Mesopotâmicos e Brasileiros.
- Integração dos banners ao Universo e aos destaques do hall, mantendo o conteúdo e as histórias existentes.
- Galeria em `banners-universo.html`. Imagens finais em `assets/universe/characters/`; conjunto de prompts em `_manutencao/banners-universo/prompts.json`. Foram gerados pela ferramenta de criação de imagens integrada, usando os personagens existentes como referência.

## Para colocar online

1. Com as migrações anteriores até a 043 aplicadas, execute `supabase/migrations/202610200044_ability_interaction_audit.sql` no banco do jogo. Para banco novo, siga toda a sequência até 044.
2. Atualize o repositório conectado à Vercel com os arquivos desta pasta. A publicação recompila o pacote de estilos pelo processo já configurado.
3. Confira as interações em partidas de homologação antes de liberar partidas ranqueadas com a nova versão do servidor. Não reaplique somente a migração 040 depois de instalar a 044.

## Limites da entrega

A conferência realizada foi de código, sintaxe, correspondência entre motores e artes. Não houve execução do SQL no banco de produção nem testes de partidas reais. A publicação na Vercel e a aplicação da migração não foram realizadas nesta sessão.

Partidas já iniciadas guardam apenas o saldo de alguns efeitos antigos. Não é possível reconstruir bônus e penalidades que se anularam antes desta atualização, nem identificar com segurança o dono de uma zona antiga sem registro. Partidas novas registram essas informações.

## Arquivo completo

A pasta e o arquivo `Mythic-Clash-Completo.zip` continuam sendo os pontos de entrega. Esta atualização não cria outro ZIP numerado. Preserve esta pasta completa para futuras alterações.

## Correção de compatibilidade da migração 044

O erro “Validação de escolhas incompatível; nenhuma alteração aplicada” vinha de uma busca por um trecho literal do código antigo do banco. A 044 corrigida usa a interface da função e conserva a implementação anterior, incluindo suas validações, sem exigir o mesmo texto interno. O tratamento de ressurreições também passou a usar um manipulador explícito, evitando outra dependência de texto antigo.

Se a 044 anterior falhou, execute novamente **o arquivo completo da 044 corrigida**. O arquivo usa uma transação; a execução que falhou não confirmou as alterações. Se o editor informar que a transação está abortada, execute `ROLLBACK;` antes de rodar o arquivo completo. Não é necessário reaplicar 040–043 para corrigir este erro.

O arquivo foi revisado localmente; não foi executado no seu banco nesta sessão.
