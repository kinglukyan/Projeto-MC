# Escolhas de habilidades, cartas e ritmo do bot

## Publicação

1. Após a **053**, aplique `supabase/migrations/202610220054_ability_choices_and_bot_pacing.sql` no Supabase.
2. Publique os arquivos desta pasta pelo GitHub/Vercel. O servidor e o navegador precisam desta atualização juntos: o bot agora avança por etapas.
3. A pasta principal e o mesmo ZIP completo foram atualizados. Não houve publicação nem execução do SQL no banco online nesta entrega.

## Erros ao jogar cartas

Foram encontradas referências SQL ambíguas em `_x_options` e `_x_resolve`, incluindo o caminho de Ganesha quando existem aliados silenciados. As referências passam a usar nomes explícitos para os candidatos e registros do Submundo. A correção altera as definições existentes e conserva as regras, proteções e auditorias anteriores.

O PostgreSQL rejeita referências que possam designar tanto uma variável quanto uma coluna. [Documentação oficial](https://www.postgresql.org/docs/current/plpgsql-implementation.html#PLPGSQL-VAR-SUBST).

A mensagem genérica da captura não contém o erro original do servidor. Portanto, os pontos encontrados foram corrigidos, mas a causa exata de cada ocorrência do print não foi reproduzida no banco online.

Antes, uma solicitação processava a jogada do jogador e toda a resposta do bot. Se a habilidade do bot falhasse, a transação também desfazia a carta do jogador. Agora a jogada confirmada é preservada antes de processar a vez do bot em outra solicitação.

## Escolhas claras

- A janela identifica a carta que ativou a habilidade.
- As opções mostram arte, nome, facção, poder impresso e descrição da habilidade, quando correspondem a uma carta.
- Alvos presentes na mesa mostram equipe e fileira.
- Merlin informa quando a escolha coloca uma carta na mão e quando ordena as demais no fundo do baralho.
- A janela não contém “Desistir”. A desistência fica indisponível enquanto há uma escolha pendente e volta a ser oferecida após resolvê-la.
- As escolhas não aguardam a animação cinematográfica geral para aparecer. O resultado continua sujeito à confirmação do servidor.
- As opções legais recebem nome e arte no estado privado do próprio jogador; as cartas do baralho e as escolhas privadas não são expostas ao oponente ou a espectadores.

## Ritmo e resposta

No Atlas, o servidor agenda **2 segundos antes de cada jogada do bot**. Quando uma habilidade dele pede escolha, agenda **mais 1 segundo por escolha**, inclusive em habilidades com várias etapas. Não se usa uma espera bloqueante no banco. Atrasos de rede podem aumentar o tempo percebido.

O navegador só solicita o avanço: cartas, alvos e escolhas do bot continuam decididos pelo servidor, que impede antecipar o prazo. Atualizar ou retomar a partida recupera a etapa em andamento. Se uma etapa falhar repetidamente, aparece “Tentar novamente”, sem refazer a jogada já confirmada do jogador.

O Guardião de treinamento local também espera 2 segundos antes de jogar e 1 segundo por escolha. Partidas PvP continuam aguardando os jogadores humanos normalmente.

As animações foram encurtadas e a mesma habilidade não reinicia sua apresentação completa a cada subescolha. Não foi adicionada jogada otimista que pudesse colocar uma carta rejeitada na mesa.

## Efeitos e alvos

- Efeitos de roubo apontam para a equipe do alvo original.
- A onda de Poseidon usa a fileira zero da equipe adversária, correspondente à fileira afetada pela habilidade.
- Elementos ocultos da mesa não substituem a posição visível de um alvo na captura das coordenadas.
- Unidades novas podem usar sua posição atual quando não existiam no quadro anterior.
- Eventos com equipe inválida são ignorados visualmente, em vez de serem direcionados por padrão ao lado adversário.

## Verificação realizada

**121 cenários passaram no motor JavaScript local, sem falhas.** Incluem entrada e resolução inicial dos personagens disponíveis, além de testes específicos de:

- Ganesha com e sem aliados silenciados;
- Merlin, escolha da carta e ordem das restantes no fundo;
- Tiamat com e sem aliado elegível e com alvos em outras fileiras;
- Afrodite, equipe original do alvo e destino da carta roubada;
- Poseidon, equipe e fileira que recebem a redução;
- as duas perspectivas de equipe nesses testes específicos.

O relatório está em `_manutencao/auditoria-habilidades/RESULTADO-ESCOLHAS-054.json`. Para repetir: execute `node _manutencao/auditoria-habilidades/verificar-escolhas-054.cjs` a partir da pasta do jogo.

Esses testes não cobrem todas as combinações entre cartas, a renderização real em navegadores, a latência da hospedagem ou a execução do PostgreSQL. A migração e o ritmo no Atlas ainda precisam de validação no Supabase após a publicação. Os testes não usaram contas, partidas reais ou recompensas.
