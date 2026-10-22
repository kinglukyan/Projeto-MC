# Aquiles — encontro interativo antes do duelo

## O que entra nesta atualização

Ao escolher **Enfrentar Aquiles** no Atlas, o encontro abre com o cenário do Santuário dos Heróis, o personagem do tronco para cima e um balão de diálogo. Somente Aquiles recebeu este encontro nesta etapa. Os outros personagens mantêm o fluxo atual.

1. Aquiles: “Olá, soldado, você também viu aquela explosão gigantesca no céu?”
2. O jogador escolhe:
   - “Sim, eu vi, você sabe o que é?”
   - “Não vi não, mas onde estamos?”
3. Ambas as escolhas levam à pergunta: “Como assim, onde estamos? Peraí, você é um soldado meu ou...?”
4. O jogador escolhe:
   - “Sou um soldado seu sim” — Aquiles faz cara de bravo.
   - “Sou um viajante de passagem, buscando conhecimento” — Aquiles solta uma risada.
5. A reação fica visível durante 1,8 segundo, e o duelo começa automaticamente. Não há alteração de poder ou recompensa por escolher uma resposta.

As falas aparecem gradualmente. “Mostrar fala completa” revela o restante imediatamente. A alternância entre as duas imagens de fala para quando a frase termina; enquanto o jogador escolhe, Aquiles mantém a boca fechada. A preferência de redução de movimento é respeitada.

## Tempo da animação

O código de tempo **00:00:00:07** foi interpretado como **7 quadros a 30 fps**: cada imagem permanece por aproximadamente **233 ms**, formando um ciclo completo de aproximadamente **467 ms**. Os valores ficam no começo de `atlas-dialogue-data.js`, em `fps` e `frameHold`, para ajustar caso o material original tenha outra taxa de quadros.

## Artes incluídas no pacote

Todas as artes ficam em `assets/atlas-dialogue/`, sem depender de arquivos temporários ou de outras pastas:

- `aquiles-falando.png`: primeira imagem enviada nesta solicitação, boca aberta.
- `aquiles-normal.png`: segunda imagem enviada, boca fechada.
- `aquiles-bravo.png`: arte séria original de Aquiles, reaproveitada da pasta de expressões já criada para a animação.
- `aquiles-rindo.png`: arte original rindo, da mesma série de expressões.

As imagens foram copiadas integralmente, sem redução de resolução e sem gerar versões novas. Não houve geração de imagem nesta atualização, pois as reações originais foram encontradas no projeto.

## Início e retorno à partida

O servidor só recebe a solicitação de criação da partida depois da última escolha e da reação. Assim, ler os diálogos não consome o turno. Fechar a conversa antes da última resposta retorna à confirmação do desafio. Se a aba estiver escondida no fim da reação, o início espera a volta à aba. Trocar de conta ou de tela encerra a conversa.

Após começar o duelo, uma retomada de partida em andamento continua diretamente na mesa. Reenfrentar Aquiles pelo mapa abre a conversa novamente. Se a criação da partida falhar, a conversa fecha, o erro é informado e o jogador pode tentar novamente.

## Publicação

Esta atualização não exige SQL adicional. Mantenha as migrações anteriores, inclusive a **052** de XP, recompensas e dificuldade, e publique os arquivos atualizados pelo GitHub/Vercel. A pasta principal e o mesmo ZIP completo são atualizados.

Fontes: `atlas-dialogue-data.js`, `atlas-dialogue.js`, `atlas-dialogue.css` e a integração em `guardian-campaign.js`. Esses arquivos já participam da geração dos arquivos finais do jogo.

Compilação e sintaxe conferidas. Não foram executadas partidas ou validação no navegador; a interação fica para a validação do proprietário.
