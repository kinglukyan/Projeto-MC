# Atualização 2026.10.22

## Publicação

1. Aplique a migração 055 completa após a 054.
2. Aplique a migração 056 completa.
3. Publique a pasta atualizada pelo GitHub/Vercel, incluindo assets, scripts e estilos.

Os arquivos novos são:

- `supabase/migrations/202610220055_unique_atlas_and_greek_characters.sql`
- `supabase/migrations/202610220056_store_code_redemption.sql`

As migrações não foram executadas no banco online nesta entrega. A parte SQL e a interface devem ser publicadas juntas: a versão anterior ainda pressupõe 20 desafios por mitologia.

## Animações

A apresentação de personagens passa de 0,6 para 2,2 segundos. A imagem precisa estar carregada antes da exibição. Há uma entrada adicional no campo de 1,7 segundo. O bot do Atlas aguarda o término da apresentação antes da próxima ação. A preferência de reduzir movimentos do dispositivo continua sendo respeitada.

O problema observado no código era o descarte muito rápido da apresentação; não foi demonstrado que a compactação do pacote causou a falha.

## Download de recursos

Após carregar o perfil, o jogo verifica os recursos da versão e os salva no navegador antes de liberar o acesso. A tela usa o mesmo carregamento do jogo e apresenta porcentagem real de 0 a 100, quantidade de arquivos e MB. A conclusão de 100% só acontece depois de todos os arquivos terem sido confirmados no armazenamento.

Em novas versões, os arquivos que já têm a revisão correta são reaproveitados. Versões antigas dos recursos são removidas desse cache para liberar espaço. Imagens com versões otimizadas usam a mesma versão consumida pelo jogo; originais de produção das novas artes não são publicados nem baixados novamente.

Se faltar conexão ou armazenamento, o progresso não é informado como concluído: a tela explica o problema e oferece nova tentativa. O navegador controla a quota e pode remover caches posteriormente; armazenamento persistente é solicitado quando suportado. A primeira preparação pode baixar muitos arquivos, e a interface apresenta o tamanho real.

## Controles e navegação

- Gamepads com mapeamento padrão: direcional/analógico para navegar, A/✕ para selecionar, B/○ para voltar e LB/RB para alternar o foco entre controles.
- Textos, mensagens e códigos continuam usando o teclado do dispositivo.
- O botão de replay fica na barra superior e abre a biblioteca de vídeos.
- Seletores de baralhos passam a usar o ícone escolhido, preservando os eventos e bloqueios de seleção existentes.
- A versão instalada como webapp respeita as áreas seguras superior e laterais do iPhone. Botões superiores têm área de toque mínima de 44 px.
- Os 12 emblemas próprios dos decks e as quatro medalhas do perfil permanecem integrados.

O reconhecimento do controle depende do navegador. Esta entrega não incluiu testes em um gamepad físico ou iPhone.

## Códigos da conta

A seção de ativação foi retirada das configurações. O campo comum da loja aceita os códigos e o servidor determina a elegibilidade. A rotina de ativação não é chamada ou identificada no JavaScript público. Os códigos mantêm vínculo com a conta destinatária, validade, uso único e limites de tentativa. O acesso direto à rotina antiga é revogado.

O formulário relacionado à emissão dos códigos e suas instruções também são fornecidos somente após autorização do servidor. O painel de administração existente continua protegido por permissões no servidor. Ocultar uma seção não substitui essa proteção.

## Atlas

São 108 desafios, sem repetição de adversários nas trilhas atuais:

| Região | Desafios |
|---|---:|
| Grécia | 20 |
| Egito | 7 |
| Nove Reinos | 6 |
| Terras Celtas | 10 |
| Mesopotâmia | 10 |
| Caminhos Hindus | 10 |
| Reino Celestial | 10 |
| Ilhas do Sol | 10 |
| Terras Astecas | 10 |
| Lendas do Brasil | 10 |
| Lendas Europeias | 5 |

As áreas mostram somente os desafios existentes, incluindo áreas finais com menos de cinco adversários. O desbloqueio considera o tamanho real da região anterior. O progresso anterior é convertido para os adversários distintos já vencidos; históricos e recompensas entregues são preservados. Batalhas ativas contra personagens repetidos são vinculadas ao desafio correspondente, sem reiniciar a batalha.

Na Grécia: Perseu no 8, Héstia no 9, Deméter no 13 e Hera no 14. Os demais níveis conservam a ordem aprovada. Veja a sequência completa em `ATLAS-SEM-REPETICOES.md`.

## Novos personagens

| Personagem | Classe | Poder | Habilidade |
|---|---|---:|---|
| Hera | Deusa | 6 | +1 para outras unidades gregas na fileira; não acumula com outra Hera |
| Deméter | Deusa | 4 | Compra uma carta e concede +2 a outra unidade grega na mesma fileira |
| Héstia | Deusa | 4 | Protege outras unidades gregas na fileira contra reduções de poder por habilidades |
| Perseu | Herói | 5 | Destrói uma unidade inimiga de até 4 de poder atual na fileira oposta |

As regras usam operações já existentes no motor, com os mesmos filtros de alvos e proteções. Não houve testes de partidas reais nesta entrega.

Cada personagem recebe ilustração principal, carta montada na moldura grega, holograma, chibi, banner do Universo e emblema individual. As imagens foram criadas com a ferramenta integrada de geração de imagens; o conjunto de prompts fica em `_manutencao/novos-gregos-prompts.json`.

Cartas em PNG 1500 × 2100: `novos-personagens/cartas/`. Originais das ilustrações: `assets/new-greeks/`. Versões usadas pelo jogo: `assets/cards-remake/`, `assets/holograms/`, `assets/avatars-chibi/` e `assets/universe/characters/`. Emblemas: `assets/character-emblems/`.
