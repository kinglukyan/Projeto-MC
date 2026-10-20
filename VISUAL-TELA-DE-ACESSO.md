# Apresentação da tela de acesso

A tela de login e cadastro ganhou uma composição visual para ocupar a área que estava vazia:

- Cidadela do jogo ao fundo, com um filtro roxo e sombra sob o formulário.
- Identidade Mythic Clash e a frase “Mitologias se encontram. Lendas entram em combate.”
- Cartas de Odin, Zeus e Rá em leque, acompanhadas pelos símbolos nórdico, grego e egípcio.
- Uma apresentação curta sobre baralhos, habilidades, Rounds e o pacote inicial.

No computador, o formulário fica à esquerda e a apresentação ocupa a área à direita. Em celulares e tablets estreitos, a apresentação vira um cabeçalho compacto; os campos permanecem acessíveis e a página permite rolagem quando necessário, inclusive durante o cadastro.

Foram reutilizadas as imagens WebP já existentes e as prévias leves das cartas. Os identificadores dos campos e os eventos de autenticação foram preservados. A observação técnica sobre o provedor da senha foi substituída por uma mensagem sobre a conta do jogador.

## Publicação

Atualize os arquivos do projeto no GitHub conectado à Vercel. A geração da interface já inclui `auth-entry.css` no pacote de estilos. A alteração usa HTML, CSS e imagens existentes.

As mudanças foram preparadas localmente. Não houve publicação na Vercel nem execução de testes de autenticação ou de navegador nesta sessão.
