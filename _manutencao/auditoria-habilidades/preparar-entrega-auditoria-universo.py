from pathlib import Path
import shutil,json,re
root=Path(__file__).resolve().parents[1];site=root/'outputs/Mythic-Clash-Completo'
p=site/'supabase/migrations/202610200044_ability_interaction_audit.sql';s=p.read_text(encoding='utf-8')
a=" d:=replace(d,$a$a->>'cardId'='leonidas'$a$,$b$public._r_identity(a)='leonidas'$b$);execute d;"
b=" d:=replace(d,$a$a->>'cardId'='leonidas'$a$,$b$public._r_identity(a)='leonidas'$b$);\n d:=replace(d,$a$public._r_card(v->>'cardId')$a$,$b$public._r_card(public._r_identity(v))$b$);\n d:=replace(d,$a$v->>'cardId'='leonidas'$a$,$b$public._r_identity(v)='leonidas'$b$);execute d;"
if a in s:s=s.replace(a,b)
p.write_text(s,encoding='utf-8')
p=root/'work/ability-allied-identity.sql';s=p.read_text(encoding='utf-8');s=s.replace(a,b);p.write_text(s,encoding='utf-8')
out=site/'_manutencao/auditoria-habilidades';out.mkdir(exist_ok=True)
for n in ['ability-allied-identity.sql','ajustar-identidades-aliadas.py','preparar-entrega-auditoria-universo.py']:shutil.copy2(root/'work'/n,out/n)
(out/'LEIA-ME.md').write_text('''# Fontes da revisão

Os arquivos de aplicação já estão corrigidos. Os scripts desta pasta registram a edição realizada; não os execute novamente em sequência sobre o aplicativo pronto.

A atualização online está consolidada em `supabase/migrations/202610200044_ability_interaction_audit.sql`. Aplicar depois da 043, uma vez. Em instalações novas, aplicar todas as migrações em ordem até a 044.

Os ajustes nativos estão em `abilities-engine.js`, `abilities-ui.js`, `app.js` e `combat-fx.js`. Banners finais estão em `assets/universe/characters/`; o mapa editável está em `universe-banners.js`.
''',encoding='utf-8')
(site/'ATUALIZACAO-HABILIDADES-E-UNIVERSO.md').write_text('''# Atualização — habilidades e Universo

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
''',encoding='utf-8')
print('Delivery notes and maintenance sources prepared.')
