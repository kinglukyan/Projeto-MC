(() => {
  const toggle = document.getElementById('missions-menu-toggle');
  const submenu = document.getElementById('missions-submenu');
  const preview = document.getElementById('missions-preview');
  const source = document.getElementById('community-missions');
  const dialog = document.getElementById('missions-dialog');
  if (!toggle || !submenu || !preview || !source || !dialog) return;

  function refresh() {
    document.dispatchEvent(new CustomEvent('mythic-missions-refresh'));
  }
  function renderPreview() {
    const rows = [...source.querySelectorAll('.mission-step')];
    const active = rows.filter(row => !row.classList.contains('complete'));
    const selected = (active.length ? active : rows).slice(0, 3);
    preview.replaceChildren();
    if (!selected.length) {
      const message = document.createElement('p');
      message.className = 'missions-preview-empty';
      message.textContent = source.textContent.trim() || 'Sem missões ativas.';
      preview.append(message);
      return;
    }
    for (const row of selected) {
      const item = document.createElement('button');
      item.type = 'button';
      item.className = 'missions-preview-item';
      const title = document.createElement('b');
      title.textContent = row.querySelector('b')?.textContent || 'Missão';
      const details = document.createElement('small');
      details.textContent = row.querySelector('small')?.textContent || '';
      const state = document.createElement('span');
      const claim = row.querySelector('[data-claim-mission]');
      state.textContent = row.classList.contains('complete') ? '✓ Concluída' : row.classList.contains('locked') ? '🔒 Bloqueada' : claim && !claim.disabled ? '✦ Recompensa disponível' : 'Em andamento';
      item.append(title, details, state);
      item.addEventListener('click', () => {
        openAll();
        row.scrollIntoView({block:'nearest', behavior:'auto'});
      });
      preview.append(item);
    }
  }
  function openAll() {
    if (window.MythicOnline?.requireLogin && !window.MythicOnline.requireLogin()) return;
    if (!dialog.open) dialog.showModal();
    refresh();
  }
  toggle.addEventListener('click', () => {
    const open = submenu.hidden;
    submenu.hidden = !open;
    toggle.setAttribute('aria-expanded', String(open));
    toggle.classList.toggle('active', open);
    if (open) { renderPreview(); refresh(); }
  });
  document.getElementById('missions-more').addEventListener('click', openAll);
  document.getElementById('missions-dialog-close').addEventListener('click', () => dialog.close());
  dialog.addEventListener('click', event => {
    if (event.target !== dialog) return;
    const box = dialog.getBoundingClientRect();
    if (event.clientX < box.left || event.clientX > box.right || event.clientY < box.top || event.clientY > box.bottom) dialog.close();
  });
  window.addEventListener('mythic-open-view', event => {
    if (event.detail?.view === 'missions') openAll();
  });
  new MutationObserver(renderPreview).observe(source, {childList:true, subtree:true, characterData:true, attributes:true, attributeFilter:['disabled','class']});
  renderPreview();
})();
