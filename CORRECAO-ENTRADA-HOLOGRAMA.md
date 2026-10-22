# Sincronização da entrada dos hologramas

O holograma do campo ficava visível assim que a carta era jogada. Depois da apresentação ampliada, uma segunda imagem sobreposta executava o efeito de chegada. Isso produzia a aparição antecipada e duas representações do mesmo personagem.

A unidade agora fica oculta no mesmo ciclo de renderização que a insere no campo. Quando chega sua vez na sequência de efeitos, o próprio elemento do campo executa a entrada de 1,7 segundo. Ao terminar, ele permanece visível no mesmo lugar; nenhuma segunda cópia é criada.

A identificação da unidade também acompanha cada membro visível de uma formação de companheiros. Atualizações do campo reaplicam a fase da entrada ao elemento recriado. Ações e turnos aguardam a conclusão da chegada. A preferência de reduzir movimentos mantém a duração curta de 0,25 segundo.

O efeito genérico de posicionamento das cartas de personagem deixa de disparar uma segunda chegada antes da apresentação. Equipamentos, locais e demais cartas especiais conservam sua sequência de posicionamento.

Fontes alterados: `app.js`, `combat-fx.js` e `webapp-upgrade.css`. Os arquivos de publicação, identificador de versão e ZIP completo foram recompostos. Publique o pacote atualizado no GitHub/Vercel para aplicar a correção ao site online. Não há migração SQL nesta alteração.
