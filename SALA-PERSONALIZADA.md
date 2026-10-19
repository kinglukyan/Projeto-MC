# Sala personalizada

## Fluxo atualizado

- A entrada mostra somente as regras de criação e um campo de código.
- O código abre uma janela com **Jogar** e **Observar**. Nenhuma vaga é ocupada antes da escolha.
- Criar ou entrar abre o lobby. Cada lado possui duas vagas.
- Um jogador por lado permite **1 × 1**. Duas equipes completas permitem **2 × 2**. Equipes desiguais não iniciam.
- O anfitrião clica no **+** da vaga para convidar. O seletor é o mesmo das partidas normais e ranqueadas: nick, ícone, elo e presença, com online primeiro.
- Convites chegam numa janela flutuante que acompanha a navegação. Ela pode ser arrastada; o cabeçalho também aceita as setas do teclado.
- Tanto os convites normais quanto os personalizados usam a camada superior do navegador para aparecer à frente dos painéis.
- Há uma vaga de observador; a transmissão mantém o atraso de segurança de 60 segundos.
- O anfitrião pode encerrar a sala. Os demais podem sair. O início e o vínculo da partida são gravados na mesma transação.
- O limite de cartas se aplica ao baralho embaralhado de cada jogador; não aumenta uma coleção menor. Os controles de propriedade e disponibilidade de cartas continuam ativos.

## Aplicação

1. Aplicar as migrações pendentes na ordem de `_manutencao/ORDEM-DAS-MIGRACOES.txt`, incluindo **202610190038_custom_room_lobby.sql**, depois da 037.
2. Publicar o cliente atualizado junto com a migração. Os antigos comandos de criação/entrada/início deixam de ser públicos, pois não conhecem as novas posições no lobby.

A migração adiciona posições às salas existentes, convites privados e operações que verificam conta ativa, limites de solicitações, amizade, anfitrião e ocupação. Mãos e baralhos de duplas continuam privados por jogador. O servidor impede início com participantes em outra fila/sala de dupla e mantém a proteção contra duas partidas ativas por pessoa.

## Escopo desta entrega

Arquivos locais e pacote atualizados. O SQL não foi executado no Supabase e o site online não foi publicado por esta entrega. Partidas reais entre contas dependem dessas etapas. As imagens de revisão local utilizam participantes ilustrativos, sem contas reais.
