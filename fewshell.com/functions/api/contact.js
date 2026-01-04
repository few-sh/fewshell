export async function onRequestPost(context) {
  try {
    // Parse the incoming form data
    const formData = await context.request.formData();
    const name = formData.get("name");
    const email = formData.get("email");
    const message = formData.get("message");

    // Basic validation
    if (!name || !email || !message) {
      return new Response("Name, email, and message are required.", { status: 400 });
    }

    // Access the API key from environment variables for security
    const apiKey = context.env.RESEND_API_KEY;
    if (!apiKey) {
      console.error("Server configuration error: RESEND_API_KEY is missing");
      return new Response("Server configuration error.", { status: 500 });
    }

    // Construct the email payload for Resend
    const payload = {
      from: "Contact Form <contact@updates.few.sh>",
      to: ["support@few.sh"], // Send to your support email
      reply_to: email,
      subject: `New Contact Form Submission from ${name}`,
      html: `
        <p>You have a new contact form submission:</p>
        <ul>
          <li><strong>Name:</strong> ${name}</li>
          <li><strong>Email:</strong> ${email}</li>
        </ul>
        <p><strong>Message:</strong></p>
        <p>${message.replace(/\n/g, "<br>")}</p>
      `,
    };

    // Send the email via the Resend API
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    // Check for errors from the Resend API
    if (!res.ok) {
      const errorData = await res.text();
      console.error(`Failed to send email: ${errorData}`);
      return new Response(`Failed to send email: ${errorData}`, {
        status: 500,
      });
    }

    // Handle AJAX requests that explicitly request JSON
    const accept = context.request.headers.get("Accept");
    if (accept && accept.includes("application/json")) {
      return new Response(JSON.stringify({ success: true }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // Fallback for non-JS submissions (though our form relies on JS)
    const url = new URL(context.request.url);
    url.pathname = "/contact";
    url.searchParams.set("submitted", "true");
    return Response.redirect(url.toString(), 302);

  } catch (err) {
    console.error(`Internal Error: ${err.message}`);
    return new Response(`Internal Error: ${err.message}`, { status: 500 });
  }
}
