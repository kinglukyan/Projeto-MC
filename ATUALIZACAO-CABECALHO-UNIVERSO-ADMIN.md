# Cabeçalho, Universo e administração — 18/10/2026

## Alterações

- Cabeçalho roxo com 30 px de espaço nas laterais e 22 px na vertical, com adaptação para celular.
- Contorno claro uniforme nos botões de ação, removendo a faixa mais grossa à esquerda.
- Seção Universo no hall anterior ao login: Convergência, mitologias, Reino de Alyn, Lukyan e Butter.
- Botão **Gestão do jogo** junto aos botões já existentes da Administração. Usuários, telemetria, pausa de cartas e administradores só aparecem ao abrir essa área.
- Atribuição de administrador por código gerado no servidor e vinculado à conta destinatária.

## Instalação

1. Se ainda não foram executados, aplicar os SQL 026, 027 e 028, nessa ordem.
2. Executar `supabase/migrations/202610180029_admin_role_codes.sql` no editor SQL do Supabase.
3. Publicar o conteúdo completo do novo ZIP na hospedagem. Os arquivos HTML já apontam para as novas versões dos scripts e estilos.

## Como atribuir um administrador

1. Na conta principal, abrir **Administração → Gestão do jogo → Administradores**.
2. Informar o e-mail de uma conta cadastrada, com e-mail confirmado, e gerar o código.
3. Compartilhar o código diretamente com o titular da conta escolhida.
4. O destinatário entra nessa conta e abre **Configurações → Acesso administrativo**, informa o código e ativa o acesso.

O código expira em 24 horas e só pode ser usado uma vez pela conta escolhida. Gerar outro código para a mesma conta invalida o anterior ainda não utilizado. São permitidas cinco tentativas por intervalo de 15 minutos. Apenas a conta principal pode gerar códigos; novos administradores não podem promover outras pessoas. O banco guarda somente o resumo criptográfico do código e registra emissão e ativação na auditoria.

O administrador recebe os acessos e o inventário administrativo já previstos no jogo. Nenhuma conta real foi promovida durante esta atualização.

## Conferências realizadas

- Sintaxe dos dois scripts alterados.
- Compilação dos SQL 026–029 em PostgreSQL temporário local.
- Prévia visual local com contas e respostas simuladas: cabeçalho, botões, hall e navegação administrativa.
- Nenhuma publicação remota ou execução de SQL no banco real. As prévias não substituem a conferência da integração após aplicar a migração na hospedagem.
