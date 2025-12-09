document.addEventListener("DOMContentLoaded", () => {
  // Spotlight Effect
  const spotlight = document.querySelector(".spotlight");
  document.addEventListener("mousemove", (e) => {
    spotlight.style.setProperty("--x", `${e.clientX}px`);
    spotlight.style.setProperty("--y", `${e.clientY}px`);
  });

  // Scroll Observer for Fade-in
  const observerOptions = {
    root: null,
    rootMargin: "0px",
    threshold: 0.1,
  };

  const observer = new IntersectionObserver((entries, observer) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("visible");
        observer.unobserve(entry.target);
      }
    });
  }, observerOptions);

  document.querySelectorAll("section").forEach((section) => {
    observer.observe(section);
  });

  // Typing Effect for Hero
  const heroElement = document.querySelector(".hero h1");
  if (heroElement) {
    // Read the existing text content from the h1
    const heroText = heroElement.textContent.trim();

    // Clear the element and type it out
    heroElement.textContent = "";
    let i = 0;
    const typeWriter = () => {
      if (i < heroText.length) {
        heroElement.textContent += heroText.charAt(i);
        i++;
        setTimeout(typeWriter, 50 + Math.random() * 50);
      } else {
        heroElement.innerHTML += '<span class="cursor">_</span>';
      }
    };
    // Start typing after a short delay
    setTimeout(typeWriter, 500);
  }

  // Handle Signup Form
  const form = document.querySelector(".signup-form");
  if (form) {
    form.addEventListener("submit", async (e) => {
      e.preventDefault();
      const button = form.querySelector("button");
      const originalText = button.textContent;

      button.disabled = true;
      button.textContent = "Sending...";

      try {
        const response = await fetch(form.action, {
          method: form.method,
          headers: { Accept: "application/json" },
          body: new FormData(form),
        });

        if (response.ok) {
          form.innerHTML =
            '<div style="color: var(--accent-green); font-weight: bold;">Thanks for your interest!</div>';
        } else {
          throw new Error("Network response was not ok");
        }
      } catch (error) {
        console.error("Error:", error);
        button.textContent = "Error";
        setTimeout(() => {
          button.disabled = false;
          button.textContent = originalText;
        }, 2000);
      }
    });
  }
});
