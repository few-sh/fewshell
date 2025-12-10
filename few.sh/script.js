document.addEventListener("DOMContentLoaded", () => {
  // Keyboard Navigation
  const focusableElements = 'a, button, input, textarea, [tabindex]:not([tabindex="-1"])';
  const focusableEvents = document.querySelectorAll(focusableElements);

  document.addEventListener('keydown', (e) => {
    if (e.key === 'ArrowDown' || e.key === 'ArrowRight') {
      e.preventDefault();
      focusNextElement();
    } else if (e.key === 'ArrowUp' || e.key === 'ArrowLeft') {
      e.preventDefault();
      focusPreviousElement();
    }
  });

  function focusNextElement() {
    const focusable = Array.from(document.querySelectorAll(focusableElements));
    const index = focusable.indexOf(document.activeElement);
    const nextIndex = (index + 1) % focusable.length;
    focusable[nextIndex].focus();
  }

  function focusPreviousElement() {
    const focusable = Array.from(document.querySelectorAll(focusableElements));
    const index = focusable.indexOf(document.activeElement);
    const prevIndex = (index - 1 + focusable.length) % focusable.length;
    focusable[prevIndex].focus();
  }

  // Typing Effect for specific terminal lines
  const typeWriterElements = document.querySelectorAll('.type-writer');
  typeWriterElements.forEach((el, index) => {
    const text = el.getAttribute('data-text') || el.textContent;
    el.textContent = '';
    setTimeout(() => {
      typeText(el, text);
    }, index * 1000 + 500); // Stagger text
  });

  function typeText(element, text) {
    let i = 0;
    const interval = setInterval(() => {
      if (i < text.length) {
        element.textContent += text.charAt(i);
        i++;
      } else {
        clearInterval(interval);
      }
    }, 30); // Speed
  }
});
