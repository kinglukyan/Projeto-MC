# Cartas e hologramas — edição 17/10/2026

## Entregue no projeto principal

- 29 PNGs originais das cartas, sem recorte ou alteração dos textos impressos.
- 29 hologramas associados às cartas, incluindo Lukyan em duas versões e Alfa, Beta e Omega separados.
- Hologramas antigos de Medusa, Poseidon, Zeus e Hades substituídos pelos novos.
- Athena e Lobisomem Alfa conservam os IDs anteriores e as posições nos baralhos.
- Catálogo com 40 cartas: 13 anteriores e 27 novas. As 27 novas estão como prévias na coleção e no Universo; não entram nos decks nem recebem cópias fictícias.
- Hologramas usados na projeção da batalha e nas ilustrações do Universo.
- Galeria `cartas-hologramas.html` com as 29 associações lado a lado.
- O holograma da feiticeira com serpentes está reservado, sem carta correspondente recebida.
- Cache atualizado para esta edição.

## Publicação

1. Aplicar no Supabase a migração `supabase/migrations/202610170002_card_art_holograms.sql`, depois das migrações anteriores.
2. Aplicar `supabase/migrations/202610170003_corrected_cards.sql`, que também atualiza os três registros caso a edição anterior já tenha sido aplicada.
3. Enviar os arquivos do ZIP principal para a hospedagem.

A migração é necessária para impedir que o catálogo antigo do banco restaure a arte anterior e para sincronizar Athena/Alfa no PvP. Foi preparada localmente; não foi aplicada no servidor remoto. Preserva histórias, músicas e HQs já cadastradas. Atualiza os campos de arte/nome/poder/habilidade desta edição.

## Regras e pendências

O pedido de artes/hologramas está integrado. Esta entrega não implementa os efeitos das 27 cartas novas; elas estão identificadas como “Em preparação”. Seus textos conhecidos estão cadastrados para a próxima etapa.

Ragnar, Beowulf e Ártemis receberam as cartas corrigidas fornecidas pelo usuário. Ragnar move uma carta aliada de baixo poder de outra fileira para a sua; Ártemis tem 5 de poder e Tiro Preciso, que elimina duas cartas Monstros de cada lado; Beowulf ganha +3 de poder na entrada se houver alguma carta da facção Monstros na mesa. Os três hologramas anteriores continuam associados aos mesmos personagens.

Athena foi atualizada para poder 4 e +2 às outras cartas aliadas da mesma fileira. O Alfa foi atualizado para +2 por Beta aliado em campo, removendo seu antigo +1 na entrada. A migração acompanha essas duas alterações de regras existentes. Os custos das cartas novas não foram inventados; não aparecem nas imagens fornecidas.

Antes da liberação das novas cartas é preciso definir os efeitos, implementar a mesma regra no Guardião e no servidor e liberar os IDs na validação dos baralhos. Também é necessário resolver a duração em “rodadas” de Hércules/Dionísio, pois o duelo atual tem duas rodadas e uma terceira somente no empate; a carta de Hércules menciona doze.

## Arquivos de referência

- `card-expansion.js`: dados visuais, estados de prévia e associações.
- `card-hologram-map.json`: manifest completo com nomes dos arquivos originais.
- `assets/cards-20261017/`: cartas completas originais.
- `assets/holograms/`: hologramas transparentes.

Não foram executados testes de navegador, partidas nem SQL remoto. Menu lateral e estrutura visual do combate preservados; regras de Athena/Alfa ajustadas conforme descrito acima.
