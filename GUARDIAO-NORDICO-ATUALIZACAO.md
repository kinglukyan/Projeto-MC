# Guardião Nórdico — corpo inteiro e sinergia

## Regra atual

**Vontade do Norte:** Se houver outro Guardião Nórdico aliado na mesma fileira, o poder deste Guardião dobra.

- Poder base mantido: 2.
- Um Guardião sozinho: 2, sem outros bônus.
- Dois ou mais Guardiões aliados na mesma fileira: cada um tem o poder dobrado uma única vez. Sem outros bônus, cada um fica com 4.
- Guardiões de fileiras diferentes ou do adversário não ativam a sinergia.
- O bônus é recalculado ao mover, remover ou ressuscitar cartas. Não permanece após a rodada.
- Equipamentos continuam seguindo suas próprias regras. A duplicação considera o poder calculado com os demais modificadores.
- Efeitos desativados por Dionísio não concedem a sinergia.

O texto da carta, os catálogos e a lógica local foram atualizados. Para aplicar a regra nas partidas online, executar `supabase/migrations/202610170019_norse_guardian_synergy.sql` após as migrações anteriores. O SQL modifica o ponto de cálculo existente, preservando as demais regras e permissões, e interrompe a transação se encontrar uma definição desconhecida.

## Imagens

- Carta atualizada: `assets/cards-20261017/guardiao-nordico.png`.
- Holograma novo: `assets/holograms/guardiao-nordico-hologram.png`.
- Holograma de corpo inteiro, com as duas pernas e botas visíveis, cabelo/barba ruivos, escudo rúnico e machado; PNG com canal alfa.
- Criados com a ferramenta integrada de geração de imagens, usando a carta como identidade e os hologramas de Heimdall/Beowulf como referências de acabamento e enquadramento.
- Originais anteriores guardados na pasta externa `outputs/guardiao-nordico-backup`.

### Prompt final do holograma

Use case: stylized-concept. Create ONE production game character hologram sprite for Mythic Clash. Reference 1 is the identity reference: GUARDIÃO NÓRDICO from the card. References 2 and 3 are STYLE / FULL-BODY FRAMING references only, do not copy those characters or their weapons. Depict the Guardian from reference 1 as a COMPLETE standing head-to-toe warrior, entire boots and both legs visible, never a bust or waist-up crop. Preserve his mature rugged face, reddish-brown long braided hair and beard, thick fur mantle, weathered Norse knotwork iron and leather armor, engraved round shield with icy BLUE glowing runes carried on viewer left, and his single-handed engraved axe on viewer right. Extend his costume naturally into armored trousers, shin armor, and sturdy boots. Strong grounded three-quarter defensive stance, shield does not hide the face or all of the legs. Match the other sprites' realistic detailed cinematic fantasy illustration, sharp readable silhouette and convincing anatomy, polished metal, leather and fur, subtle cool blue rune highlights and restrained edge light. Portrait 2:3 composition, full character centered and filling most height with a small clear margin around head, boots, shield and axe. Asset must be a genuine RGBA TRANSPARENT BACKGROUND cutout, clean alpha edges; no scenery, no floor, no solid dark background, no opaque glow cloud. No frame, no card layout, no text, no pedestal, no watermark, no horned helmet. This will replace the cropped hologram and must match the scale and full-body framing of reference 2/3. One character only.

### Prompt final da edição da carta

Use case: text-localization. Edit ONLY the description text in the purple ability panel on this exact GUARDIÃO NÓRDICO card. Keep the whole existing card and all other text, entire character artwork, frame, name, purple Norse symbols, power 2, subtitle, ability title VONTADE DO NORTE, HABILIDADE capsule and bottom label unchanged. Replace the old sentence about Runas Nórdicas with this exact legible Portuguese rule, uppercase, centered and fitted neatly inside the same description region: "SE HOUVER OUTRO GUARDIÃO NÓRDICO ALIADO NA MESMA FILEIRA, O PODER DESTE GUARDIÃO DOBRA." Keep the cream lettering, spacing and original graphic layout, no new illustrations or ornament. Whole card flat front view, preserve portrait aspect ratio.

## Entrega

Publicar o pacote atualizado em conjunto, incluindo os scripts versionados e o manifesto de imagens, e atualizar a aba por F5. A migração não foi aplicada no Supabase remoto. Foram feitas conferências estáticas de sintaxe; não foram executados testes de partida.
