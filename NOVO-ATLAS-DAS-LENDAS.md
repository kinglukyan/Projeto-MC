# Novo Atlas das Lendas

## Interface

- Mapa mundial ilustrado, com emblemas selecionáveis, zoom e arraste. As posições foram ajustadas à geografia da ilustração; representam origens aproximadas das tradições.
- Painel do destino com símbolo, cenário, descrição, progresso e condição de desbloqueio. Destinos bloqueados podem ser consultados.
- Monstros ficam em um cartão separado, como lendas europeias de várias origens. Alyns continuam fora da campanha.
- Regiões organizadas em quatro áreas de cinco desafios, com setas laterais, abas, paginação e gesto horizontal no celular. A trilha não exige rolar para baixo para encontrar os demais desafios.
- Ícones chibi existentes, linha dourada conforme o avanço, indicação do próximo desafio, fases concluídas e marcos de tesouro.
- Baralho selecionável na própria região, histórico de tesouros e avanço ao próximo destino após concluir os vinte desafios.
- Layout específico para computadores, tablets e celulares; controles com foco de teclado e respeito à preferência por movimento reduzido.

## Artes

21 imagens novas foram geradas com a ferramenta integrada de criação de imagens: um mapa mundial, quatro cenários gregos, quatro egípcios, quatro nórdicos e um panorama para cada um dos oito outros destinos. Nas oito últimas regiões, as quatro áreas compartilham o panorama da sua mitologia com enquadramentos diferentes.

As imagens não contêm botões ou textos desenhados. Os controles e o progresso são elementos reais da interface. As artes estão em `assets/guardian-campaign/atlas/`, em WebP. O jogo carrega o cenário da área exibida e a prévia seguinte; não baixa a coleção inteira ao abrir a página.

As duas referências aprovadas e os prompts completos estão em `_manutencao/guardian-atlas/`. Essa pasta fica fora da publicação pública da Vercel e acompanha o ZIP para futuras atualizações.

## Publicação

Atualize os arquivos do repositório conectado à Vercel com o conteúdo da pasta `Mythic-Clash-Completo`. Esta mudança visual não exige uma migração SQL nova. A campanha continua dependendo da migração 045 e das correções posteriores já incluídas nesta entrega.

O catálogo, os IDs dos desafios, os baralhos dos adversários, a ordem de desbloqueio e os prêmios continuam vinculados à campanha existente. O progresso não é reiniciado.

## Conferências e limites

Foi realizada revisão do código e checagem de sintaxe JavaScript. Não foram executados testes de interface ou partidas. Os arquivos foram atualizados localmente; não houve publicação na Vercel nem aplicação no Supabase nesta sessão.

O mesmo arquivo `Mythic-Clash-Completo.zip` foi atualizado, junto com sua pasta completa.
