(() => {
  const viewNames = {
    arena: "Arena",
    collection: "Coleção",
    decks: "Meus baralhos",
    lore: "O universo",
  };

  const views = [...document.querySelectorAll(".view")];
  const navButtons = [...document.querySelectorAll(".nav-item[data-view]")];
  const breadcrumb = document.querySelector("#breadcrumb-current");
  const modalBackdrop = document.querySelector("#modal-backdrop");
  const modalTitle = document.querySelector("#modal-title");
  const modalCopy = document.querySelector("#modal-copy");
  const modalKicker = document.querySelector("#modal-kicker");
  const modalAction = document.querySelector("#modal-action");
  const inviteRow = document.querySelector("#invite-code-row");
  const joinField = document.querySelector("#join-code-field");
  const toast = document.querySelector("#toast");
  let modalMode = "invite";
  let activeFilter = "all";
  let toastTimer;

  function showView(name) {
    if (!viewNames[name]) return;
    views.forEach((view) => {
      const active = view.id === `view-${name}`;
      view.hidden = !active;
      view.classList.toggle("active", active);
    });
    navButtons.forEach((button) => {
      const active = button.dataset.view === name;
      button.classList.toggle("active", active);
      if (active) button.setAttribute("aria-current", "page");
      else button.removeAttribute("aria-current");
    });
    breadcrumb.textContent = viewNames[name];
    document.title = `Mythic Clash — ${viewNames[name]}`;
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  document.addEventListener("click", (event) => {
    const target = event.target.closest("[data-view]");
    if (target) showView(target.dataset.view);
  });

  document.querySelectorAll(".lore-story-toggle").forEach((button) => {
    button.addEventListener("click", () => {
      const story = document.getElementById(button.getAttribute("aria-controls"));
      const isOpen = button.getAttribute("aria-expanded") === "true";
      button.setAttribute("aria-expanded", String(!isOpen));
      story.hidden = isOpen;
      button.innerHTML = isOpen ? 'Ler história <span>＋</span>' : 'Fechar história <span>−</span>';
    });
  });
  function openModal(mode) {
    modalMode = mode;
    const isJoin = mode === "join";
    const isHelp = mode === "help";
    modalKicker.textContent = isHelp ? "PROTÓTIPO LOCAL" : isJoin ? "ENTRAR EM UMA SALA" : "SALA PRIVADA";
    modalTitle.textContent = isHelp
      ? "Um universo em construção"
      : isJoin
        ? "Entre com um código"
        : "Convide alguém para a arena";
    modalCopy.textContent = isHelp
      ? "Esta é uma base visual para moldarmos juntos. Partidas online, regras, contas e salvamento ainda não estão conectados."
      : isJoin
        ? "Cole o código de convite recebido para simular a entrada em uma sala."
        : "Crie um código de demonstração para compartilhar com seu oponente.";
    inviteRow.hidden = isJoin || isHelp;
    joinField.hidden = !isJoin;
    modalAction.textContent = isHelp ? "Entendi" : isJoin ? "Continuar" : "Sala pronta";
    if (!isJoin && !isHelp) {
      document.querySelector("#invite-code").textContent = `MYTH-${Math.floor(1000 + Math.random() * 9000)}`;
    }
    modalBackdrop.hidden = false;
    if (isJoin) window.setTimeout(() => document.querySelector("#join-code-input").focus(), 20);
    else modalAction.focus();
  }

  function closeModal() {
    modalBackdrop.hidden = true;
  }

  function showToast(message) {
    toast.textContent = message;
    toast.classList.add("show");
    window.clearTimeout(toastTimer);
    toastTimer = window.setTimeout(() => toast.classList.remove("show"), 2600);
  }

  document.querySelector("#create-match").addEventListener("click", () => openModal("invite"));
  document.querySelector("#invite-friend").addEventListener("click", () => openModal("invite"));
  document.querySelector("#join-match").addEventListener("click", () => openModal("join"));
  document.querySelector("#help-button").addEventListener("click", () => openModal("help"));
  document.querySelector("#modal-close").addEventListener("click", closeModal);
  modalBackdrop.addEventListener("click", (event) => {
    if (event.target === modalBackdrop) closeModal();
  });
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && !modalBackdrop.hidden) closeModal();
  });

  modalAction.addEventListener("click", () => {
    if (modalMode === "join") {
      const code = document.querySelector("#join-code-input").value.trim();
      if (!code) {
        showToast("Digite um código para continuar.");
        return;
      }
      closeModal();
      showToast("Entrada demonstrativa registrada. A conexão online será adicionada depois.");
      return;
    }
    if (modalMode === "help") {
      closeModal();
      return;
    }
    closeModal();
    showToast("Sala de demonstração criada. Compartilhe o código de convite.");
  });

  document.querySelector("#copy-code").addEventListener("click", async () => {
    const code = document.querySelector("#invite-code").textContent;
    try {
      await navigator.clipboard.writeText(code);
      showToast("Código copiado.");
    } catch {
      const helper = document.createElement("textarea");
      helper.value = code;
      helper.style.position = "fixed";
      helper.style.opacity = "0";
      document.body.appendChild(helper);
      helper.select();
      document.execCommand("copy");
      helper.remove();
      showToast("Código copiado.");
    }
  });

  function filterCollection() {
    const query = document.querySelector("#card-search").value.trim().toLocaleLowerCase("pt-BR");
    const cards = [...document.querySelectorAll(".collection-card")];
    let visibleCount = 0;
    cards.forEach((card) => {
      const matchesFilter = activeFilter === "all" || card.dataset.category.split(" ").includes(activeFilter);
      const matchesSearch = !query || card.dataset.name.includes(query);
      const visible = matchesFilter && matchesSearch;
      card.hidden = !visible;
      if (visible) visibleCount += 1;
    });
    document.querySelector("#add-card-tile").hidden = activeFilter !== "all" || Boolean(query);
    document.querySelector("#empty-search").hidden = visibleCount > 0 || activeFilter === "all" && !query;
  }

  document.querySelectorAll(".filter-tab").forEach((button) => {
    button.addEventListener("click", () => {
      document.querySelectorAll(".filter-tab").forEach((tab) => tab.classList.toggle("active", tab === button));
      activeFilter = button.dataset.filter;
      filterCollection();
    });
  });
  document.querySelector("#card-search").addEventListener("input", filterCollection);

  ["#add-card", "#add-card-tile", "#new-deck"].forEach((selector) => {
    document.querySelector(selector).addEventListener("click", () => {
      showToast("O editor será uma das próximas partes que vamos moldar.");
    });
  });
})();


if ('serviceWorker' in navigator && location.protocol !== 'file:') {
  window.addEventListener('load', () => navigator.serviceWorker.register('./sw.js').catch(() => {}));
}
