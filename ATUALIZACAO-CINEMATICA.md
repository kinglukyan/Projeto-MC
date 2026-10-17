# Atualização visual e de combate

## Universo e perfil

- Os 37 personagens têm banners com sua imagem, cenário, cor, símbolo e frase próprios. A Convergência mantém sua apresentação.
- Foram gerados 37 ícones Chibi a partir das cartas, preservando rostos, cabelos, tons de pele, espécies e detalhes do pescoço.
- Os ícones aparecem no seletor de perfil após aplicar a migração 012. Esta coleção inicial é disponibilizada sem cobrança.
- A galeria `icones-chibi.html` permite ver os ícones sem entrar em uma conta.
- Os prompts usados pelo gerador integrado estão em `assets/avatars-chibi/PROMPTS.json`. Os novos recortes de Guardião Nórdico e Loki também são usados nos banners e hologramas.

## Interface e celular

- As áreas azuis da interface recebem a paleta de carvão e violeta e a textura da barra lateral.
- Ajustados tamanhos, espaçamentos, colunas, controles de toque e cartas ampliadas em telas pequenas.
- VS centralizado nas telas de fila normal/ranqueada, personalizada e desafio.
- A coleção abre a carta em tamanho grande.
- O botão de jogar tem posição estável e não acompanha animações da carta ampliada.
- Hologramas ficam ancorados às cartas, acompanhando o próprio campo durante rolagem e redimensionamento.
- Companheiros na mesma fileira formam um montinho. Seus hologramas aparecem lado a lado; o botão de quantidade abre a pilha para selecionar as cartas.

## Moedas

- Mythic Coins continuam sendo ganhas por partidas, com um novo ícone de moeda.
- Clash Bit tem ícone, configuração e estrutura de saldo/créditos preparados, mas está invisível e sem recargas habilitadas.
- O saldo premium não pode ser creditado diretamente pelo navegador. A função de crédito foi reservada ao serviço do servidor, com referência única por crédito.

## Combate

- Zeus: raios nos alvos destruídos.
- Medusa: efeito de petrificação e campo afetado em cinza.
- Afrodite: corações no alvo escolhido.
- Poseidon: onda de água na ativação do Tsunami.
- Ártemis: flechas nos monstros efetivamente atingidos, até dois de cada lado. Se houver menos alvos, são usadas menos flechas.
- Destruição: brilho, desintegração e partículas indo ao Submundo.
- Trixx: explosão da estrela perdida.
- Entre rodadas: pausa de dois segundos com o vencedor da rodada e, em seguida, “Vamos pra próxima”. No online, o servidor também impede jogadas durante a pausa.
- Todos os efeitos são limpos na mudança de rodada, inclusive Dionísio e o progresso de Hércules, conforme solicitado. Equipamentos, cópias de Loki, bônus e petrificações não passam à rodada seguinte.

## Para atualizar

1. Atualize os arquivos do site com o conteúdo do ZIP.
2. Depois das migrações anteriores até 011, execute `supabase/migrations/202610170012_cinematic_arcane_update.sql`.
3. Comece partidas novas para usar o estado de combate atualizado.

## Revisão realizada

Foi feita revisão de código e validação de sintaxe dos arquivos JavaScript alterados. Não foram executados testes de partidas, navegador, celular ou banco de dados. A migração não foi aplicada ao Supabase remoto e o site não foi publicado nesta entrega.
