# Loja — atualização 2026.10.23.2

## Instalação
1. Aplique `supabase/migrations/202610230064_store_accounting_and_admin_test.sql` depois da 063. Não reaplique migrações antigas por cima desta atualização.
2. Substitua os arquivos do projeto pelo conteúdo do ZIP, mantendo as pastas. O pacote é incremental e exige a atualização de pacotinhos/Trixx Coins anterior.
3. Publique no GitHub/Vercel pelo fluxo habitual. O projeto local já contém as alterações; o site público não é atualizado automaticamente por este pacote.

## Saldos e recarga
- Removidos da apresentação os dois painéis grandes de saldo da loja.
- Mythic Coins e Trixx Coins ficam juntas na barra do jogador, com “+” ao lado das Trixx Coins.
- O “+” abre a informação de recargas em breve. A integração de pagamento continua pendente da escolha do provedor.
- O saldo premium é consultado no servidor e atualizado após compras ou resgates.

## Recompensas administrativas
- Ajuste direto de Trixx Coins, Mythic Coins e XP na seção Jogadores. Ajustes de moedas são limitados a ±5.000 por envio; saldos não podem ficar negativos.
- Trixx Coins disponíveis no criador de códigos presente, inclusive em presentes mistos. Cada código mantém seu limite de usos e só entrega uma vez por jogador.
- Créditos administrativos e presentes são classificados como ajuste/recompensa, sem serem tratados como pagamento real.

## Contabilidade
Administração → Loja → Contabilidade e modo teste.
- Totais por moeda e tipo: compras, créditos, recompensas e ajustes.
- Data, jogador, produto e valor por operação; filtros de período e moeda; páginas de 50 registros.
- Compras normais em Mythic Coins são registradas a partir desta atualização. Inventário antigo não permite distinguir compra de presente, por isso esse histórico não é inventado.
- Os registros premium existentes de créditos e compras de pacotes são importados sem duplicação.
- Valores representam moedas do jogo, não faturamento em reais. Créditos de serviço não comprovam pagamento por si só; o futuro provedor deverá validar pagamentos no servidor.
- As tabelas não permitem leitura ou escrita direta pelo cliente. Consultas e ajustes administrativos exigem autorização no servidor.

## Modo teste do administrador
- Ativação individual na seção Loja da administração. A loja exibe um aviso enquanto estiver ativo. A escolha fica salva para esta conta.
- Permite simular todos os produtos ativos da loja, inclusive cartas e cosméticos já adquiridos/equipados e pacotes sem saldo suficiente.
- Os pacotes usam a mesma animação de abertura e revelação carta por carta. O avanço simulado fica somente na tela e se perde ao fechá-la; não vira pacote pendente.
- Produtos avulsos mostram uma apresentação ampliada com animação, sem equipar o item.
- O servidor confirma o modo antes da compra; a simulação não altera saldo, inventário, cópias, compras nem contabilidade. Mudanças do modo invalidam confirmações antigas.
- Ativação/desativação pode gerar auditoria de segurança, separada da contabilidade comercial. Não há venda simulada nos totais.
- Ao desativar, as compras voltam a ter efeitos reais e exigir saldo. Perder o acesso administrativo impede o uso do modo teste.

## Validação desta entrega
Montagem dos arquivos públicos e checagem de sintaxe JavaScript. Sem executar compras, migrações no banco online ou testes de partidas. As interações e a migração devem ser conferidas no ambiente do jogo antes da publicação definitiva.
