# Carregamento, atualizações e desempenho — 21/10/2026

## O que mudou

- O primeiro acesso ao hall, o login, a criação de conta e a recuperação da última tela usam a mesma apresentação da entrada em partida: cenário, estrela, título e indicador animado.
- O indicador acompanha tarefas reais. Não existe um tempo mínimo artificial: a interface é liberada quando os dados necessários estão disponíveis.
- Perfil, coleção e baralhos ficam prontos antes da entrada na conta. Pedidos simultâneos pelo mesmo perfil compartilham a consulta.
- Falhas de conexão oferecem uma forma de tentar novamente. Uma falha ao carregar o perfil no login mostra **Tentar carregar meus dados**, sem exigir outro login.
- Atualizar a página recupera a tela anterior de uma sessão conectada. Sair da conta e entrar novamente continua abrindo a **Arena**.

## Publicar no GitHub e na Vercel

Envie os arquivos desta pasta ao repositório conectado à Vercel, incluindo `_manutencao`, `assets` e `vercel.json`. A Vercel executa `node _manutencao/preparar-publicacao.cjs` e publica `site-publico`.

O processo agora agrupa os scripts, calcula a versão de todos os arquivos de código e atualiza o identificador da publicação automaticamente. Não é necessário editar números de versão à mão. A mesma fonte produz a mesma versão em builds repetidos.

Depois que a publicação da Vercel estiver pronta:

- HTML, identificador de versão e service worker não usam uma cópia antiga do cache HTTP.
- O site verifica novas versões a cada **45 segundos enquanto a aba está visível**, e também ao voltar à aba ou recuperar a conexão.
- Em telas seguras, a atualização pode recarregar a página. Durante uma partida ou outra atividade protegida, aparece um aviso e a recarga automática é adiada.
- O cadastro, a sessão e os dados de jogadores não são apagados para atualizar o site.

O tempo de build/publicação da Vercel e o tempo sem internet continuam dependendo desses serviços. A checagem de 45 segundos começa depois que a nova publicação está disponível; não é uma promessa de publicar em 45 segundos.

**Esta entrega foi preparada localmente. Ela precisa ser enviada ao GitHub para chegar ao site público. Não exige uma nova migração SQL para estas mudanças de carregamento. As migrações das funcionalidades anteriores continuam necessárias quando ainda não aplicadas.**

## Redução de carregamento

- **52 scripts agrupados** em um arquivo de execução, com o SDK do Supabase incluído localmente. O login deixa de depender de baixar um script de outro servidor.
- **38 folhas de estilo agrupadas**, fontes separadas e imagens fora da área visível carregadas sob demanda.
- **100 imagens adicionais otimizadas:** de 222.761.051 para 38.678.410 bytes, redução de **82,6%** para essas versões de exibição. Os originais foram preservados.
- **156 mapeamentos de imagens** disponíveis no conjunto, contando otimizações anteriores.
- A coleção e as histórias deixam de reconstruir todo o conteúdo escondido durante a entrada.
- Imagens em cache continuam disponíveis entre versões; código alterado recebe outra identificação.

Esses números descrevem arquivos e requisições evitadas. Não são uma medição de tempo de abertura em internet móvel real, nem significam que todo o site ficou 82,6% mais rápido.

## Compatibilidade verificada

Testes locais com conta, autenticação, inventário e consultas simuladas, sem criar contas reais nem alterar dados de jogadores. A política de segurança da publicação foi aplicada nos testes de navegação, com a exceção necessária para o endereço HTTP local.

| Navegador ou motor | Resultado |
| --- | --- |
| Chromium 151.0.7922.34 | 19 verificações concluídas; sem erros de aplicação ou arquivos ausentes nos fluxos testados |
| Brave 155.0.8059.85 | 19 verificações concluídas; sem erros de aplicação ou arquivos ausentes nos fluxos testados |
| WebKit 26.5 | 19 verificações concluídas; um aviso de chamada de presença cancelada durante recarga com interceptação foi registrado separadamente |
| Firefox | O processo encerrou antes de abrir o site neste ambiente; não validado |
| Microsoft Edge | O processo instalado encerrou antes de abrir o site neste ambiente; não validado |

Foram verificados hall, Arena, baralhos, loja, perfil, personalizada, Guardião e universo em larguras de **375, 768 e 1440 pixels**, além de login, cadastro com confirmação de e-mail, cadastro com sessão, erro de senha, restauração após atualização e retorno à Arena após novo login. Não houve transbordamento horizontal global nessas larguras.

Testes adicionais confirmaram o cache do código versionado, detecção da nova versão, proteção de uma partida ativa contra recarga, atualização em tela segura, alternativas para diálogo/popover/UUID e recuperação após falha ao carregar o perfil.

Há alternativas por capacidade para janelas, UUID, altura útil do celular e agendamento de tarefas; estilos incluem prefixos para máscaras e transparências. Movimento reduzido e economia de dados são respeitados nas apresentações aplicáveis.

**WebKit de teste não substitui Safari em um iPhone real.** Não foi executada uma partida completa nem testado todo navegador antigo. Relatório detalhado: `_manutencao/RELATORIO-COMPATIBILIDADE.json`.

## Manutenção

- Fontes de execução: `_manutencao/runtime-fontes.json`.
- Fontes de estilos: `_manutencao/interface-fontes.json`.
- Gerar interface e versões: `node _manutencao/gerar-interface.cjs`.
- Preparar a publicação: `node _manutencao/preparar-publicacao.cjs`.
- Atualizar o mesmo ZIP completo: `python _manutencao/atualizar-mesmo-zip.py`.
- A otimização de imagens já está pronta; para gerar outras, o script opcional `_manutencao/otimizar-imagens.py` exige Python com Pillow.
- Testes opcionais em `_manutencao/verificar-navegadores.cjs` e `_manutencao/verificar-atualizacoes.cjs` exigem Playwright e os motores instalados. Não são dependências para rodar ou publicar o jogo.
- SDK local: Supabase JS 2.118.0, com licença em `assets/vendor/SUPABASE-LICENSE.txt`.

Os arquivos `game-runtime.js`, `entry-bootstrap.js`, `entry-optimized.css`, `release.json` e `asset-manifest.json` são gerados. Faça alterações nas fontes e execute o gerador para que a publicação mantenha as versões consistentes.
