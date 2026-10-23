# Loja de pacotinhos e Trixx Coins — 2026.10.23.1

## Publicar

1. Aplicar `supabase/migrations/202610220063_basic_packs_trixx_coins.sql` inteiro, depois do SQL 062.
2. Extrair o ZIP de atualização na raiz do projeto atual, substituindo os arquivos correspondentes, e publicar pelo GitHub conectado à Vercel.
3. A aba **Pacotinhos** aparecerá na loja e a carteira exibirá **Trixx Coins**. A recarga permanece desativada, conforme combinado: o motor de pagamentos será escolhido posteriormente.

## Pacotes básicos — edição I

Cada compra entrega uma cópia de cada carta listada naquela edição, sem sorteio. Cartas que o jogador já possui recebem mais uma cópia. Unidades, equipamentos, locais, terrenos e demais cartas distribuíveis da própria facção estão incluídos. Tokens e transformações geradas por habilidades não são vendidos como cartas próprias; cartas Universais não pertencem a uma mitologia.

| Mitologia / facção | Cartas por pacote | Preço em Trixx Coins |
|---|---:|---:|
| Grécia | 25 | 1.000 |
| Egito | 11 | 1.000 |
| Nórdicos | 13 | 1.000 |
| Celtas | 10 | 1.000 |
| Mesopotâmica | 10 | 1.000 |
| Hindu | 10 | 1.000 |
| Chinesa | 10 | 1.000 |
| Japonesa | 10 | 1.000 |
| Asteca | 10 | 1.000 |
| Brasil | 10 | 1.000 |
| Monstros | 5 | 1.000 |
| Alyns | 2 | 1.000 |

O conteúdo da edição Básico I é uma lista literal fixa, guardada em `_manutencao/PACOTES-BASICOS-EDICAO-I.json`, no arquivo público de apresentação e no SQL. Depois de semeada, a edição é fechada no banco: a proteção impede inserir, remover ou trocar cartas de seu conteúdo. Adicionar cartas ao catálogo geral do jogo não as inclui nestes pacotes. Para futuras cartas, criar outra edição/SKU; não reconstruir ou abrir a lista da edição I.

## Apresentação e abertura

- Frente inclinada para um lado e verso para o outro.
- Ao passar o mouse ou focar os controles, os ângulos se invertem e os pacotes recebem uma ampliação suave.
- A loja informa todas as cartas e o preço antes da compra. Há confirmação explícita.
- O pacote adquirido aparece ampliado em uma janela sobre o restante da tela desfocado. “Abrir pacote” rompe o selo superior; a embalagem se afasta e cada carta surge individualmente.
- O botão de guardar revela a próxima carta. O jogador pode continuar depois e retomar pelo bloco “Seus pacotes para abrir”.
- A preferência de redução de movimento é respeitada. Os controles funcionam por toque e teclado.

## Segurança da compra e entrega

O servidor valida a conta, o SKU, o preço esperado, o catálogo fechado e o saldo. Débito de Trixx Coins, comprovante, registro de gasto e entrega das cópias acontecem na mesma transação. O preço ou conteúdo enviados pelo navegador não determinam a entrega.

O identificador de solicitação evita cobranças duplicadas em tentativas repetidas. Uma compra ainda não aberta do mesmo SKU é retomada em vez de gerar novo débito. O progresso de revelação é salvo de forma idempotente no servidor. Fechar o navegador ou interromper a animação não perde cartas: todas já foram entregues na confirmação da compra. Animar ou repetir a revelação não concede novas cópias.

A carteira premium existente é reaproveitada; o campo legado interno mantém seu nome para preservar compatibilidade. A interface passa a usar exclusivamente Trixx Coins. O saldo de Mythic Coins das partidas é separado e não é convertido nem consumido por estes pacotes.

## Recarga por dinheiro real — futura

Nenhum checkout, preço em reais, crédito gratuito ou pagamento simulado foi criado. O botão informa “Recarga em breve”. O novo ponto `credit_trixx_coins_service` é executável somente por `service_role`, reutilizando o registro idempotente já existente. O futuro webhook deverá verificar o pagamento real no provedor escolhido e só depois chamar esse ponto com uma referência única de pagamento. Chaves de serviço nunca devem ir para o navegador.

## Imagens e desempenho

A logo de Trixx Coins foi gerada com image_gen: aro de platina/prata, centro de safira azul e Trixx dourada de quatro pontas, distinguindo-a das Mythic Coins. O PNG original e os 24 PNGs dos pacotes estão em `_manutencao/artes-originais/pacotes`. As versões públicas WebP são sem perdas, com resolução e transparência preservadas. O prompt da moeda está em `_manutencao/TRIXX-COINS-PROMPT.txt`.

As artes dos pacotes são carregadas ao abrir a loja e não entram no download obrigatório antes de jogar, evitando aumentar o tempo de entrada das partidas. Continuam sendo armazenadas normalmente pelo cache de mídia ao serem usadas.

## Estado da entrega

Build local preparado. Esta entrega não aplicou o SQL no Supabase nem publicou o site online. Não foram executadas compras reais, testes automatizados ou partidas. O pagamento permanece desativado até a escolha e integração do provedor. Para conferir depois de publicar: catálogo, inclinações, saldo, compra com saldo válido, retomada da abertura, saldo insuficiente e lista de cartas da coleção.
