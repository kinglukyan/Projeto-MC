# Construtor de decks

## Publicação

1. Execute `supabase/migrations/202610170015_deck_builder_14_35.sql` no SQL Editor do Supabase, depois dos SQLs 013 e 014.
2. Publique os arquivos deste pacote na pasta do site, substituindo os de mesmo nome. Preserve os demais arquivos e imagens.
3. Atualize a página com F5. Os arquivos alterados têm novas versões para aproveitar o cache sem esconder a atualização.

O ZIP principal contém o site completo. O ZIP do construtor contém apenas os arquivos necessários para atualizar uma instalação que já tenha as atualizações anteriores.

## Como usar

Em **Baralhos**, clique em **Editar baralho** ou no botão destacado **Modo Construtor** para editar o baralho selecionado. O slot com **+** abre a mesa para criar outro baralho. Ele tem as mesmas dimensões dos demais e reaparece quando preenchido, até o limite de sete baralhos. O editor antigo foi retirado da tela.

Para habilitar **Excluir baralho**, execute também `supabase/migrations/202610170016_delete_builder_deck.sql`, após o SQL 015. A opção fica no painel do baralho selecionado, pede confirmação e preserva as cartas da coleção. Após excluir o último baralho, fica um slot vazio para montar outro. A exclusão é confirmada no servidor antes de atualizar a tela.

Execute também `supabase/migrations/202610170017_player_icons_seven_decks.sql` após o 016 para liberar os sete slots no banco, mostrar ícones dos amigos e identificar os participantes no campo de batalha. Os sete slots ficam disponíveis nesta versão; a compra de slots será incluída futuramente. Esta atualização corrige as bordas dos ícones Chibi sem baixar novas imagens e mantém a filtragem de mãos privadas das partidas.

- A mesa ocupa a tela inteira, cobrindo a barra lateral.
- A coleção mostra somente cartas jogáveis que a conta possui. Formas especiais de transformação não entram no baralho.
- A faixa inferior mostra apenas cartas com cópias livres. Quando todas as cópias estão na mesa, a carta desaparece da faixa; retirar uma cópia faz ela reaparecer.
- Selecione uma carta para vê-la na prévia. Clique na prévia para ampliá-la; no celular, use **Ampliar selecionada**.
- Arraste uma carta da coleção para a mesa ou use **+**. As quantidades respeitam as cópias disponíveis.
- Para retirar, use **−** ou arraste da mesa para a coleção. No celular, há também uma alça para arrastar da coleção.
- Use busca, facção e tipo para encontrar cartas.
- O baralho precisa ter **14 a 35 cartas**, contando todas as cópias.
- **Limpar mesa** pode ser revertido com **Desfazer**.
- **Salvar baralho** grava o slot e o baralho ativo juntos no servidor. Só fecha depois da confirmação.
- Ao sair com alterações, escolha continuar, descartar ou salvar. O rascunho também é recuperável na mesma sessão do navegador e conta.

O SQL 015 atualiza os limites das partidas individuais, em dupla e personalizadas, preservando as funções de habilidades existentes. Baralhos antigos com menos de 14 cartas precisam ser completados antes de entrar em uma partida. Presentes e expedições preservam o novo mínimo.

Não há imagens adicionais para baixar: a tela utiliza as cartas e texturas existentes. Clash Bit continua invisível.

## Conferência realizada

Os arquivos JavaScript passaram pela checagem de sintaxe. A geração do pacote confere a preservação da barra lateral, do trecho de combate e dos arquivos protegidos. A interface não foi verificada em navegador nesta entrega, e o SQL não foi executado no banco remoto. A publicação e a aplicação da migração continuam necessárias.
