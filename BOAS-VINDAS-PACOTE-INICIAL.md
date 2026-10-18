# Boas-vindas e primeiro pacotinho — 18/10/2026

## Experiência

1. Após autenticar uma conta nova, abrir uma apresentação de boas-vindas sem a barra lateral.
2. Escolher entre Mitologia Grega, Nórdica e Egípcia.
3. Receber um pacotinho com 14 cartas e 2 ícones, registrados uma única vez pelo servidor.
4. Abrir a embalagem: o lacre se desprende, o corpo do pacote desce e as cartas saem mostrando o verso. Todas viram e se abrem em leque.
5. Tocar numa carta para ampliar a arte e ler sua habilidade atual. No celular, os 14 itens formam dois leques de sete.
6. Usar **Montar deck** para abrir o construtor com o primeiro baralho de 14 cartas. O tutorial do Guardião continua sendo apresentado na primeira batalha.

Há opção de pular a animação e suporte a movimento reduzido. O som de revelação respeita a opção de efeitos do jogador. Os demais controles ficam bloqueados pelo diálogo durante as boas-vindas, e a conta pode ser encerrada pelo botão de saída.

## Presente inicial

- **10 unidades:** seis sorteadas da mitologia escolhida e quatro sorteadas entre as demais unidades disponíveis, sem repetir as seis primeiras.
- **4 cartas especiais comuns:** um Local e um Terreno da mitologia escolhida, mais duas cartas não-unidade. Equipamentos só entram no sorteio quando existe um portador compatível entre as unidades recebidas.
- Assim, pelo menos oito das 14 cartas pertencem à mitologia escolhida. As 14 cartas são distintas e cada uma é entregue com uma cópia.
- **2 ícones aleatórios:** o primeiro pertence à mitologia escolhida; o segundo pertence a uma das outras mitologias disponíveis. Não são duas escolhas fixas por mitologia.
- As formas especiais de Eclipse e Rei de Todos não são sorteadas como cartas independentes.

## Retomada e contas existentes

O recibo usa `player_starter_grants`. O progresso visual usa a tabela protegida `player_onboarding`. O servidor não aceita ID de outro jogador: as três operações públicas usam exclusivamente a conta autenticada.

A entrega ocorre em transação e bloqueia o perfil durante o resgate. Cliques repetidos, outro navegador, mudança de escolha e F5 devolvem o mesmo recibo, sem novos sorteios ou novas cópias. Se a página fechar durante a abertura, o próximo acesso retoma o pacotinho recebido. Ao finalizar e entrar no construtor, o progresso passa a concluído.

Contas que já possuem o presente inicial são preservadas e não repetem as boas-vindas. Administradores mantêm seu acesso ao catálogo completo. Compras e presentes anteriores não são removidos.

O primeiro baralho é salvo no slot 1 somente se esse slot ainda não existir. A abertura do pacote atualiza a coleção antes de liberar o construtor. A escolha não limita as mitologias que o jogador pode usar futuramente.

## Instalação

1. Executar `supabase/migrations/202610180026_welcome_starter_pack.sql` no Supabase **após o SQL 025 e antes de publicar os novos arquivos**.
2. Publicar o pacote atualizado do site.
3. Criar uma conta nova para acompanhar a sequência. Uma conta com presente já concedido continua entrando normalmente.

O SQL substitui a concessão automática inicial por uma concessão após a escolha. Não publicar apenas a interface antes da migração: o servidor antigo ainda distribui o presente aleatório antigo.

Nenhuma migração foi aplicada ao Supabase remoto e nenhuma publicação remota foi feita nesta entrega.

## Arte

A embalagem usa uma nova imagem RGBA com transparência, gerada pelo **ImageGen integrado**, baseada na concept art aprovada e na identidade do verso/logo do jogo.

- Asset integrado: `assets/onboarding/starter-pack.png`.
- Prompt e referência: `ONBOARDING-IMAGE-PROMPT.txt`.
- A arte de origem foi preservada. O movimento de abertura e o giro das cartas são feitos com camadas e animações do navegador.
- A embalagem e as artes sorteadas são carregadas para este fluxo; não há invalidação do cache de todas as imagens do jogo.

## Verificação realizada

- 13 cenários em PostgreSQL temporário: concessão antiga adiada, composição para as três mitologias, ícones da origem correta, repetição sem duplicação, variedade de sorteios, administrador, catálogo insuficiente com reversão, autenticação, permissões e reaplicação da migração.
- Navegador Chromium isolado: fluxo completo em 1440 × 1000, 390 × 844 e movimento reduzido em 1024 × 768. Foram verificados 14 cartões, dois ícones, ampliação, conclusão e ausência de transbordamento horizontal.
- Integração com a página completa: autenticação simulada, coleção real da interface, F5 antes da abertura, retomada do mesmo pacote e abertura do construtor real com 14 cartas. Contas antigas continuam sem a sequência.
- A autenticação e as respostas de rede da verificação de interface foram simuladas; a lógica de entrega foi executada separadamente no PostgreSQL. Nenhuma conta real foi usada.
- Revisão estática de JavaScript, JSON, HTML e SQL. Na integração, também foi corrigida uma consulta pública de histórias que usava sua configuração de campos antes de inicializá-la.

As capturas de tela e os relatórios de verificação estão em `outputs/welcome-update/`, fora do pacote publicado do jogo.
