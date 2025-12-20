export interface Env {
}

export default {
	async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
		// Handle CORS preflight requests
		if (request.method === "OPTIONS") {
			return new Response(null, {
				headers: {
					"Access-Control-Allow-Origin": "*",
					"Access-Control-Allow-Methods": "POST, OPTIONS",
					"Access-Control-Allow-Headers": "Content-Type",
				},
			});
		}

		const url = new URL(request.url);

		if (request.method === "POST" && url.pathname === "/submit") {
			try {
				const formData = await request.formData();
				
				// Log the received data for now
				console.log("Received feedback submission:");
				for (const [key, value] of formData.entries()) {
					if (value instanceof File) {
						console.log(`${key}: File(name="${value.name}", size=${value.size})`);
					} else {
						console.log(`${key}: ${value}`);
					}
				}

				return new Response("Feedback received", {
					status: 200,
					headers: {
						"Access-Control-Allow-Origin": "*",
					},
				});
			} catch (e) {
				console.error("Error processing request:", e);
				return new Response("Error processing request", { 
					status: 400,
					headers: {
						"Access-Control-Allow-Origin": "*",
					},
				});
			}
		}

		return new Response("Not Found", { status: 404 });
	},
};
