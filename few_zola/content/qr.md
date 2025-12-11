+++
title = "Configuration Generator"
date = 2025-01-01
template = "page.html"
[extra]
stylesheets = ["css/custom.css"]
+++

Generate a QR code to quickly configure your Fewshell mobile app. All data is processed locally in your browser and is never sent to any server.

<script src="/qrcodegen-v1.8.0-es6.js"></script>
<div class="form-section">
    <div class="form-group">
        <label class="form-label">Project Name (Optional)</label>
        <span class="form-hint">A friendly name to identify this environment on your phone.</span>
        <input type="text" id="projectName" class="form-input" placeholder="e.g. Production AWS" />
    </div>
    <div class="form-group">
        <label class="form-label">Host Connection (Optional)</label>
        <span class="form-hint">Format: user@ip-address or user@hostname</span>
        <input type="text" id="hostConnection" class="form-input" placeholder="e.g. ubuntu@192.168.1.50" />
    </div>
    <div class="form-group">
        <label class="form-label">LLM Provider (Optional)</label>
        <select id="llmProvider" class="form-select">
            <option value="">Select a provider...</option>
            <option value="anthropic">Anthropic (Claude)</option>
            <option value="openai">OpenAI (GPT)</option>
            <option value="google">Google (Gemini)</option>
        </select>
    </div>
    <div class="form-group">
        <label class="form-label">API Key (Optional)</label>
        <span class="form-hint">Your API key for the selected provider. Stored securely in your phone's keychain.</span>
        <input type="password" id="apiKey" class="form-input" placeholder="sk-..." />
    </div>
    <div class="form-group">
        <label class="form-label">SSH Private Key (Optional)</label>
        <span class="form-hint">Paste your private key (PEM/OpenSSH format). It will be compacted for the QR code.</span>
        <textarea id="sshKey" class="form-textarea" placeholder="-----BEGIN OPENSSH PRIVATE KEY-----..."></textarea>
    </div>
    <button id="generateBtn" class="btn-generate">Generate QR Code</button>
</div>
<div id="qr-result" style="display: none; text-align: center; margin-top: 4rem;">
    <h2>Scan with Fewshell</h2>
    <div id="qr-canvas-container" style="background: white; padding: 20px; border-radius: 8px; display: inline-block; margin: 2rem 0;">
        <canvas id="qrCanvas"></canvas>
    </div>
    <p class="subtitle">Open the Fewshell app and scan this code to import settings.</p>
</div>
<div id="qr-error" style="color: #ff7b72; margin-top: 1rem; display: none;"></div>
<script>
    function drawCanvas(qr, scale, border, lightColor, darkColor, canvas) {
        if (scale <= 0 || border < 0) throw new RangeError("Value out of range");
        const width = (qr.size + border * 2) * scale;
        canvas.width = width;
        canvas.height = width;
        let ctx = canvas.getContext("2d");
        for (let y = -border; y < qr.size + border; y++) {
            for (let x = -border; x < qr.size + border; x++) {
                ctx.fillStyle = qr.getModule(x, y) ? darkColor : lightColor;
                ctx.fillRect((x + border) * scale, (y + border) * scale, scale, scale);
            }
        }
    }
    document.getElementById("generateBtn").addEventListener("click", function () {
        const resultDiv = document.getElementById("qr-result");
        const errorDiv = document.getElementById("qr-error");
        const canvas = document.getElementById("qrCanvas");
        resultDiv.style.display = "none";
        errorDiv.style.display = "none";
        const projectName = document.getElementById("projectName").value.trim();
        const hostConnection = document.getElementById("hostConnection").value.trim();
        const llmProvider = document.getElementById("llmProvider").value;
        const apiKey = document.getElementById("apiKey").value.trim();
        let sshKey = document.getElementById("sshKey").value.trim();
        if (sshKey) {
            sshKey = sshKey
                .split("\n")
                .filter((line) => !line.startsWith("-----"))
                .map((line) => line.trim())
                .join("");
        }
        const data = {};
        if (projectName) data.n = projectName;
        if (hostConnection) data.i = hostConnection;
        if (llmProvider) data.l = llmProvider;
        if (apiKey) data.k = apiKey;
        if (sshKey) data.s = sshKey;
        if (Object.keys(data).length === 0) {
            errorDiv.innerText = "Please fill in at least one field to generate a QR code.";
            errorDiv.style.display = "block";
            return;
        }
        const jsonString = JSON.stringify(data);
        try {
            const QrCode = qrcodegen.QrCode;
            const qr = QrCode.encodeText(jsonString, QrCode.Ecc.MEDIUM);
            drawCanvas(qr, 5, 2, "#ffffff", "#000000", canvas);
            resultDiv.style.display = "block";
            resultDiv.scrollIntoView({ behavior: "smooth" });
        } catch (error) {
            console.error(error);
            errorDiv.innerText = "Error generating QR code: " + error.message;
            errorDiv.style.display = "block";
        }
    });
</script>
