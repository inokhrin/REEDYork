
(function () {
  function ensurePopup() {
    let popup = document.getElementById('note-popup');
    if (!popup) {
      popup = document.createElement('div');
      popup.id = 'note-popup';
      popup.className = 'note-popup';
      popup.hidden = true;
      popup.innerHTML = '<div class="note-popup-title"></div><div class="note-popup-body"></div>';
      document.body.appendChild(popup);
    }
    return popup;
  }

  function showPopup(button) {
    const popup = ensurePopup();
    popup.querySelector('.note-popup-title').textContent = button.dataset.noteLabel || 'Note';
    popup.querySelector('.note-popup-body').textContent = button.dataset.noteContent || '';
    popup.hidden = false;
    const rect = button.getBoundingClientRect();
    const top = window.scrollY + rect.bottom + 8;
    const left = Math.min(window.scrollX + rect.left, window.scrollX + document.documentElement.clientWidth - popup.offsetWidth - 16);
    popup.style.top = top + 'px';
    popup.style.left = Math.max(window.scrollX + 8, left) + 'px';
  }

  function hidePopup() {
    const popup = document.getElementById('note-popup');
    if (popup) popup.hidden = true;
  }

  document.addEventListener('click', function (event) {
    const btn = event.target.closest('.note-ref');
    if (btn) {
      event.preventDefault();
      showPopup(btn);
      return;
    }
    if (!event.target.closest('#note-popup')) {
      hidePopup();
    }
  });

  document.addEventListener('mouseover', function (event) {
    const btn = event.target.closest('.note-ref');
    if (btn) showPopup(btn);
  });

  document.addEventListener('focusin', function (event) {
    const btn = event.target.closest('.note-ref');
    if (btn) showPopup(btn);
  });

  document.addEventListener('keydown', function (event) {
    if (event.key === 'Escape') hidePopup();
  });
})();
    