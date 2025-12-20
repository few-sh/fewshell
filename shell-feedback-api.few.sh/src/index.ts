import JSZip from "jszip";

export interface Env {
	FEWSHELL_BUCKET: R2Bucket;
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
				const zip = new JSZip();
				let feedbackText = "";
				let feedbackType = "feedback";
				
				console.log("Received feedback submission:");
				for (const [key, value] of formData.entries()) {
					if (value instanceof File) {
						console.log(`${key}: File(name="${value.name}", size=${value.size})`);
						// Add logs file to zip if present
						if (key === 'logs') {
							zip.file(value.name, await value.arrayBuffer());
						}
					} else {
						console.log(`${key}: ${value}`);
						feedbackText += `${key}: ${value}\n`;
						
						if (key === 'type') {
							feedbackType = value as string;
							if (feedbackType === 'feature') {
								feedbackType = 'feature-request';
							}
						}
					}
				}

				// Add the text summary
				zip.file("feedback.txt", feedbackText);

				// Generate zip file
				const zipContent = await zip.generateAsync({ type: "uint8array" });
				
				// Generate unique filename
				const filename = `${feedbackType}-${Date.now()}-${crypto.randomUUID()}.zip`;

				// Upload to R2
				await env.FEWSHELL_BUCKET.put(filename, zipContent);
				console.log(`Uploaded ${filename} to R2`);

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
