# Atualização 2026.10.22.4 — Guildas, ícones e nicknames

## Instalação

1. Esta atualização pressupõe que as migrações até 060 já foram aplicadas. Execute o arquivo inteiro `supabase/migrations/202610220061_guild_levels_unique_nicknames.sql` no SQL Editor do Supabase. O script usa uma transação: se houver erro, as alterações não são aplicadas parcialmente.
2. Extraia o pacote de atualização na raiz do projeto, substituindo os arquivos correspondentes. Publique pelo GitHub conectado à Vercel. O pacote completo também está disponível.
3. O build configurado prepara os arquivos públicos e atualiza a versão do cache. A aplicação do SQL e a publicação online não foram realizadas nesta entrega.

## Ícones

Héstia, Hera, Deméter e Perseu recebem enquadramento próprio dentro dos círculos, com aproximação do rosto para acompanhar o padrão dos chibis existentes. O ajuste acompanha perfil, barra lateral, seleção de ícones e demais imagens destes quatro arquivos. Os arquivos originais e os outros ícones são preservados. Ao trocar o ícone, o enquadramento anterior é removido.

## Nicknames exclusivos

O banco impede nomes iguais considerando maiúsculas/minúsculas e espaços excedentes. “Lukyan”, “LUKYAN” e “ Lukyan ” representam o mesmo nickname. A regra vale para cadastro e alteração de perfil, com índice único para impedir duplicações mesmo em solicitações simultâneas. O cadastro consulta a disponibilidade e exibe uma mensagem em português.

Para permitir instalar a restrição em contas existentes, o nome mais antigo é preservado em cada grupo de duplicados. Somente os demais nomes repetidos recebem um sufixo baseado no identificador da conta. As contas, coleções e progresso são mantidos. Não há mudança de nicknames que já são exclusivos.

## Níveis das guildas

Todas começam no nível 1, com 0 XP, e já concedem +10%. A progressão nova vale para participações concluídas após a aplicação do SQL; não recalcula partidas antigas.

| Nível | XP acumulado necessário | XP para subir ao próximo | Bônus de XP e moedas |
|---|---:|---:|---:|
| 1 | 0 | 10.000 | +10% |
| 2 | 10.000 | 20.000 | +20% |
| 3 | 30.000 | 35.000 | +30% |
| 4 | 65.000 | 55.000 | +40% |
| 5 | 120.000 | 80.000 | +50% |
| 6 | 200.000 | 110.000 | +60% |
| 7 | 310.000 | 145.000 | +70% |
| 8 | 455.000 | 185.000 | +80% |
| 9 | 640.000 | 230.000 | +90% |
| 10 | 870.000 | Máximo | +100% |

Cada membro contribui com 100 XP por participação em uma partida concluída. Em uma dupla da mesma guilda, cada integrante contribui com 200 XP: 400 XP da dupla por partida. Vitórias e derrotas contribuem. Modo teste, abrir fila, cancelar busca, login e resgates não geram XP de guilda. As metas exigem 8.700 participações individuais, ou 4.350 participações em dupla da mesma guilda, para chegar ao nível máximo.

## Recompensas

O bônus é somado à recompensa base já calculada pelo modo e pelo resultado. Uma dupla da mesma guilda recebe +100% adicional, somado ao bônus do nível. No nível 10: recompensa base × 3. Exemplo: vitória normal de 100 moedas e 40 XP vira 300 moedas e 120 XP. No nível 1, a mesma vitória em dupla vira 210 moedas e 84 XP. Derrotas mantêm a base reduzida do modo antes da aplicação do bônus. Frações são arredondadas para baixo.

O servidor congela a guilda e o nível no primeiro registro do resultado, para os quatro participantes receberem o bônus do mesmo nível. O nível conquistado com essa partida passa a valer nas seguintes. O bônus e a contribuição são registrados uma vez por participante; resolver um empate altera o valor final sem somar outra participação de guilda.

Os modos Atlas, normal, ranqueada e personalizada usam suas recompensas base existentes. O Desempate independente online passa a registrar histórico e usa a base da personalizada: vitória 50 moedas e 20 XP, derrota 25 moedas e 10 XP, com o bônus da guilda. A decisão de um empate dentro de uma partida não cria uma segunda recompensa.

O painel da guilda mostra nível, XP acumulado, barra de progresso, meta seguinte, bônus atual e a tabela dos dez níveis. A busca de guildas também mostra o nível.

## Entrega e validação

Foi preparado o build local de distribuição. Não foram executados testes automatizados ou partidas reais, conforme a preferência de você testar depois. A migração não foi executada no banco online. Para conferir após publicar: trocar os quatro ícones, tentar repetir nickname em cadastro/perfil, concluir partidas solo e dupla da mesma guilda e conferir histórico, saldo e progressão da guilda.
