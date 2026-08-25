// Optional high-quality AI visual creation through Apple's system Image Playground UI.
// No API key or developer-hosted image service. The person explicitly opens the system sheet.
(() => {
  if (window.__lifeRouteImagePlaygroundV1Loaded) return;
  window.__lifeRouteImagePlaygroundV1Loaded = true;

  const pending = new Map();
  let sequence = 0;
  const nativeHandler = () => window.webkit?.messageHandlers?.lifeRoute;
  const available = () => typeof nativeHandler()?.postMessage === "function";

  const fileToDataURL = file => new Promise(resolve => {
    if (!file) return resolve("");
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result || ""));
    reader.onerror = () => resolve("");
    reader.readAsDataURL(file);
  });

  const dataURLToFile = async (dataURL, name = "ai-visual.jpg") => {
    const response = await fetch(dataURL);
    const blob = await response.blob();
    return new File([blob], name, { type: blob.type || "image/jpeg", lastModified: Date.now() });
  };

  const open = async ({ label, file } = {}) => {
    if (!available()) return { success: false, reason: "native-only" };
    const requestId = `playground-${Date.now()}-${++sequence}`;
    const imageBase64 = file ? await fileToDataURL(file) : "";
    return new Promise(resolve => {
      const timeout = setTimeout(() => {
        pending.delete(requestId);
        resolve({ success: false, reason: "timeout" });
      }, 180000);
      pending.set(requestId, payload => {
        clearTimeout(timeout);
        pending.delete(requestId);
        resolve(payload || { success: false, reason: "empty" });
      });
      try {
        nativeHandler().postMessage({
          action: "openImagePlayground",
          requestId,
          label: String(label || "Visual support").trim().slice(0, 80),
          imageBase64
        });
      } catch (_) {
        clearTimeout(timeout);
        pending.delete(requestId);
        resolve({ success: false, reason: "bridge" });
      }
    });
  };

  const priorNativeEvent = window.lifeRouteNativeEvent;
  window.lifeRouteNativeEvent = function lifeRouteNativeEventWithImagePlayground(evt) {
    if (typeof priorNativeEvent === "function") priorNativeEvent(evt);
    if (evt?.type !== "imagePlaygroundResult") return;
    pending.get(String(evt.requestId || ""))?.(evt);
  };

  const installVisualToolButton = () => {
    if (!available()) return;
    const tool = document.getElementById("visualIconTool");
    if (!tool || document.getElementById("visualAIStudioButton")) return;
    const actions = tool.querySelector(".visualLabelRow");
    if (!actions) return;
    const button = document.createElement("button");
    button.id = "visualAIStudioButton";
    button.type = "button";
    button.className = "secondary";
    button.textContent = "AI image studio";
    button.title = "Create or refine this visual with Apple's Image Playground";
    actions.insertAdjacentElement("afterend", button);

    const note = document.createElement("div");
    note.className = "tiny lrAIStudioNote";
    note.textContent = "AI image studio uses Apple’s system Image Playground. You review the generated image before it returns to LifeRoute.";
    button.insertAdjacentElement("afterend", note);

    button.onclick = async () => {
      const label = String(document.getElementById("visualIconLabel")?.value || "Visual support").trim() || "Visual support";
      const input = document.getElementById("visualCameraInput");
      const file = input?.files?.[0] || null;
      button.disabled = true;
      button.textContent = "Opening AI studio…";
      try {
        const result = await open({ label, file });
        if (!result?.success || !result.dataURL) {
          if (typeof window.setStatus === "function") window.setStatus(result?.reason === "cancelled" ? "AI image studio closed" : "AI image studio is unavailable right now");
          return;
        }
        const generated = await dataURLToFile(result.dataURL, `${label.replace(/[^a-z0-9]+/gi, "-").slice(0, 30) || "visual"}-ai-playground.jpg`);
        if (!input) return;
        const transfer = new DataTransfer();
        transfer.items.add(generated);
        input.files = transfer.files;
        input.dispatchEvent(new Event("change", { bubbles: true }));
        if (typeof window.setStatus === "function") window.setStatus("AI image returned · LifeRoute is isolating and styling the subject");
      } finally {
        button.disabled = false;
        button.textContent = "AI image studio";
      }
    };
  };

  const style = document.createElement("style");
  style.id = "lifeRouteImagePlaygroundStyles";
  style.textContent = `#visualAIStudioButton{margin-top:8px;width:100%;border-color:color-mix(in srgb,var(--blue) 45%,var(--line));background:linear-gradient(135deg,color-mix(in srgb,var(--blue) 10%,var(--panel2)),color-mix(in srgb,var(--gold) 7%,var(--panel2)))}.lrAIStudioNote{margin-top:5px}`;
  document.head.appendChild(style);

  const install = () => installVisualToolButton();
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", install, { once: true });
  else install();

  window.LifeRouteImageStudio = { open, dataURLToFile, available, install, version: "1.0.0" };
})();
