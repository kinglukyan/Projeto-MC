# Revisão do Projeto MC — 2026.10.22.2

## Base usada

Esta entrega parte do ZIP **Projeto MC.zip enviado pelo proprietário**, não do pacote anterior. Foram inventariados os 1.459 arquivos do projeto, excluindo apenas o histórico interno `.git` do arquivo compactado. A leitura automatizada catalogou 409 arquivos de texto e 997 imagens, incluindo fontes, migrações, configuração e referências de arte. As referências visuais de Afrodite e das quatro cartas novas foram inspecionadas diretamente. O inventário original e os relatórios estão em `_manutencao/revisao-20261022`.

## Alterações

1. Quatro chibis novos: Héstia, Perseu, Hera e Deméter. Integração pelos mesmos caminhos usados no perfil, loja e Atlas.
2. Cabeçalho mobile: margem interna de área segura do iOS, botões separados em duas linhas e alvos de toque de 44 pixels. O menu lateral abre com um gesto horizontal a partir da margem esquerda e fecha com um gesto para a esquerda. A rolagem vertical normal é preservada.
3. Entrada por QR Code na tela de login, com confirmação explícita no aparelho já conectado. Código de comparação, validade de três minutos, cancelamento e limite de criação. Senha e sessão não são colocadas no QR. O servidor usa a autenticação oficial do Supabase.
4. Guildas: criação/código/busca para quem não tem guilda; painel de membros e atividades para quem tem. Convites por código de amigo, candidatura em guildas públicas, aceitação/recusa e controle de visibilidade pelo líder.
5. Comunidade: publicar baralho da conta, ver todas as cartas e perfil público do autor, votar e retirar voto, favoritar e desfavoritar, buscar, ordenar e paginar. Copiar diretamente para um espaço de baralho exige confirmar a substituição e possuir as cópias; faltas são informadas e a estratégia pode ser favoritada.
6. Banners: 38 cenas originais extraídas em arquivos individuais sem perdas, incluindo os 37 personagens únicos solicitados e a Convergência. Beta apareceu duas vezes na lista e foi tratado como um único personagem. Corrigida a proporção do banner principal e das miniaturas.
7. Replay retirado da barra superior. Bloco próprio nas configurações junto aos grupos de áudio e conta; inclui acesso à biblioteca de vídeos.
8. Desempate solo independente contra o Guardião do Destino. Oculto por padrão; liberação pela administração. Reutiliza o algoritmo de puxadas, menor poder base e decisão por Eclipse. Não interfere no resultado de outra partida nem atribui recompensas que não foram definidas para esse modo.

## Arquitetura preservada

O cliente autenticado continua centralizado em `online.js`. Novas telas usam RPCs; convites, votos, favoritos e disponibilidade são validados no servidor. O compositor TCG, as habilidades, os poderes e as cartas finais existentes não foram regravados. A publicação continua usando o build já configurado na Vercel.

## O que depende da publicação

O site online não foi alterado automaticamente. Aplicar SQLs 057, 058 e 059, configurar as variáveis privadas de QR na Vercel e enviar os arquivos ao GitHub. Consulte `PUBLICAR-ESTA-REVISAO.md`.

Não foram executadas partidas reais, testes de contas múltiplas, testes no iPhone nem testes automatizados nesta entrega. Os comportamentos acima foram implementados e revisados nos fontes; a validação no ambiente publicado continua necessária após configurar o servidor.

## Referências técnicas consultadas

- Supabase generateLink: https://supabase.com/docs/reference/javascript/auth-admin-generatelink
- Autenticação e isolamento do servidor: https://supabase.com/docs/guides/functions/auth
- Gerador QR local com licença MIT: https://www.nayuki.io/page/qr-code-generator-library
