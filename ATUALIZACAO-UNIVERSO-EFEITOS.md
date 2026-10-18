# Universo, efeitos e presença dos amigos

## Instalação

1. Publique os arquivos do pacote atualizado no mesmo diretório do site.
2. No Supabase, depois da migração 019, execute **202610170020_replace_zones.sql** e depois **202610170021_friend_presence.sql**, disponíveis em `supabase/migrations/`.
3. Atualize a página. As versões dos arquivos alterados foram incrementadas e o manifesto de imagens foi atualizado. Os caches existentes continuam aproveitados.

As migrações 020 e 021 não foram executadas no banco remoto nesta entrega. A aplicação das regras em partidas online e o status dos amigos dependem delas. Elas pressupõem as migrações anteriores, inclusive 019.

## Interface e Universo

- Ajustes de espaçamento no progresso de XP, caminho de navegação, filtros e campo de pesquisa.
- Ao clicar no personagem ou em “Ler história”, a história passa a ocupar a parte inferior do próprio banner, com altura livre para o texto.
- 37 personagens e a Convergência receberam ilustrações próprias. São 10 arquivos de imagens com quatro cenas independentes cada; o navegador mostra somente a cena correspondente. Duas cenas extras ficam reservadas, sem adicionar personagens ao Universo.
- As aparências seguem as referências existentes das cartas e hologramas. As imagens de história são carregadas quando utilizadas, sem baixar todos os banners na entrada do site.
- Lukyan e Butter seguem a história informada pelo criador. Os lobisomens e suas formas humanas têm contos originais. Ragnar é apresentado como figura das sagas nórdicas; Beowulf é identificado como herói da poesia anglo-saxônica.
- As histórias mitológicas são recontos, com referências acessíveis no próprio leitor. Textos personalizados pelo administrador continuam tendo prioridade sobre os textos locais quando não são apenas descrições de habilidades.
- A troca de histórias também preserva o controle da trilha do personagem, sem perder o elemento de áudio ao reconstruir a leitura.

## Regras e animações

- Local substitui Local; Terreno substitui Terreno. Cartas da zona de Clima podem substituir o clima atual, respeitando a proteção de Clima/Evento.
- Um clima comum não substitui Clima/Evento. O Eclipse e seus resultados são reconhecidos como Clima/Evento; novas cartas podem declarar `climateClass: "event"` ou `isClimateEvent: true` no catálogo do cliente e do servidor.
- Quando o Eclipse Solar sai da área de clima, as unidades transformadas recuperam a identidade original do lobisomem. Sob Eclipse Lunar, o cálculo volta a aplicar o poder dobrado.
- Cada entrada de carta possui um evento visual próprio, inclusive equipamentos, locais e terrenos. Ressurreições e novas invocações deixam de depender apenas do nome da carta para exibir a animação.
- Um novo Eclipse que sorteie o mesmo resultado na mesma rodada também pode repetir a revelação.
- Transformações de lobisomem usam a imagem da forma anterior, a nova forma e quadros ilustrados de energia solar ou lunar. A transformação de Lukyan mantém sua apresentação própria.
- Os hologramas dos lobisomens sob Eclipse Lunar ganham mais 25% de escala, ancorada na base.
- Novas sequências ilustradas transparentes para tsunami de Poseidon, raios de Zeus e corações de Afrodite, integradas às animações de impacto e destruição existentes.
- As preferências de redução de movimento são respeitadas. Os efeitos são visuais: não alteram o sorteio ou a resolução autoritativa do servidor.

## Amigos

- Online: página visível e atividade recente.
- Ausente: página em segundo plano ou três minutos sem interação.
- Offline: encerramento informado ou ausência de atualização por cerca de 90 segundos.
- Atualização a cada 30 segundos, com identificação por aba para evitar que uma aba fechada derrube uma sessão ainda aberta.
- Apenas amigos aceitos podem consultar o estado. A tabela não tem leitura ou escrita direta liberada aos jogadores; as funções usam a identidade autenticada.
- A atualização do indicador preserva o menu de ações do amigo aberto.

## Arquivos de arte e verificações

As imagens foram geradas com a ferramenta integrada **image_gen**, em modo de geração com referências das artes existentes. Os cinco conjuntos de efeitos têm transparência real. Os prompts finais estão em `image-generation-prompts.json`.

Foram conferidos estaticamente a sintaxe JavaScript, JSON, referências locais, IDs HTML, blocos CSS, integridade dos recursos e estrutura lexical dos arquivos SQL. Isso não equivale à execução das funções em PostgreSQL ou à validação de uma partida online. A tentativa de abrir a prévia pelo navegador integrado não alcançou o servidor local; não foi possível confirmar visualmente o layout nesse navegador.

## Sugestões futuras

- Disponibilizar controle de intensidade das animações dentro das configurações do jogo.
- Criar uma área de edição das histórias originais com publicação por versão.
- Gerar versões WebP/AVIF dos banners, mantendo os PNG originais como arquivos de arte.
- Se as animações passarem a durar mais tempo, coordenar uma pausa de apresentação no servidor para preservar o tempo de jogada dos dois participantes.
