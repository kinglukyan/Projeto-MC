# Atualização 2026.10.23.5 — administração e loja

## Instalação
Aplicar o SQL 066 (`supabase/migrations/202610230066_admin_game_modes.sql`) após o SQL 065 revisado do criador de Kael. Publicar os arquivos do projeto juntos. O pacote inclui também a atualização anterior do criador e o SQL 065 revisado, para instalações que ainda estão na 064.

## Alterações
- Atlas: botão **Editar personagem** acessível tanto no mapa mundial quanto dentro dos destinos. Usa o catálogo atual de aparências e salva as alterações na conta.
- Administração: **Contabilidade** em aba própria, com filtros, lançamentos das duas moedas e modo teste.
- Pacotes: clicar ou tocar diretamente no pacote inicia a abertura; também há botão acessível por teclado. Painel de fundo removido da abertura, mantendo o desfoque sobre a loja.
- **Criador de cartas**: arte, nome, habilidade, facção, poder para personagens, modelos especiais sem poder, cores da frente/painel/moldura, zoom e posição da imagem. Prévia e PNG em 1500 × 2100. Rascunhos por conta neste navegador e projetos exportáveis/importáveis em JSON, incluindo a imagem. A opção de imagem de carta completa recorta a ilustração para evitar carta dentro de carta.
- **Modos de jogo**: Atlas, treinamento livre, normal, ranqueada, personalizada, torneios e desempate. Ocultação no menu e bloqueio das entradas no servidor, com exceção do treinamento local cujo início é bloqueado na interface. Filas de normal/ranqueada são canceladas ao desativar; resultados e partidas já iniciadas continuam preservados.

## Limites
Os projetos de carta são rascunhos visuais. Não publicam novas cartas jogáveis, nem transformam textos de habilidade em regras. Rascunhos ficam no navegador e na conta usados; exporte o JSON para levar a outro dispositivo. Para disponibilizar novos personagens e habilidades no jogo, é preciso cadastrar e implementar as respectivas regras.

Arquivos preparados localmente. SQL não aplicado no servidor e site não publicado nesta tarefa. Não foram executados testes automatizados nem partidas.
