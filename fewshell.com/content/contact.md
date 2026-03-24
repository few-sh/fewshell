+++
title = "Contact Us"
template = "page.html"
[extra]
stylesheets = ["css/custom.css"]
+++

Have questions or want to get in touch? We'd love to hear from you.

<form class="contact-form" action="/api/contact" method="POST">
    <div class="form-group">
        <label class="form-label" for="name">Name</label>
        <input type="text" id="name" name="name" class="form-input" placeholder="Your name" required />
    </div>
    <div class="form-group">
        <label class="form-label" for="email">Email</label>
        <input type="email" id="email" name="email" class="form-input" placeholder="your.email@example.com" required />
    </div>
    <div class="form-group">
        <label class="form-label" for="message">Message</label>
        <textarea id="message" name="message" class="form-textarea" placeholder="Tell us what's on your mind..." rows="6" required></textarea>
    </div>
    <button type="submit" class="signup-button" style="width: 100%; padding: 1rem 2rem;">Send Message</button>
</form>

<script src="/js/custom.js"></script>
