export async function onRequestPost(context) {
  try {
    const formData = await context.request.formData();
    const email = formData.get("email");

    if (!email) {
      return new Response("Email is required", { status: 400 });
    }

    // Access the API key from environment variables for security
    const apiKey = context.env.RESEND_API_KEY;

    if (!apiKey) {
      return new Response(
        "Server configuration error: RESEND_API_KEY is missing",
        { status: 500 },
      );
    }

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "Fewshell Signup <signups@updates.few.sh>",
        to: ["support@few.sh"],
        reply_to: email,
        subject: `New Signup: ${email}`,
        html: `<p>A new user has signed up for the waiting list:</p><p><strong>${email}</strong></p>`,
      }),
    });

    if (!res.ok) {
      const errorData = await res.text();
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

    // Fallback: Redirect back to home for standard form submissions
    // (or AJAX requests that follow redirects)
    const url = new URL(context.request.url);
    url.pathname = "/";
    url.searchParams.set("signed_up", "true");

    return Response.redirect(url.toString(), 302);
  } catch (err) {
    return new Response(`Internal Error: ${err.message}`, { status: 500 });
  }
}
