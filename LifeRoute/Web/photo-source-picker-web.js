// Web-preview photo source chooser for the visual icon maker.
(() => {
  if (window.__lifeRoutePhotoSourcePickerLoaded) return;
  window.__lifeRoutePhotoSourcePickerLoaded = true;

  const STYLE_ID = "lifeRoutePhotoSourcePickerStyles";

  const addStyles = () => {
    if (document.getElementById(STYLE_ID)) return;
    const style = document.createElement("style");
    style.id = STYLE_ID;
    style.textContent = `
      .lrPhotoSourceOverlay{position:fixed;inset:0;z-index:22000;display:none;align-items:flex-end;justify-content:center;padding:16px calc(14px + env(safe-area-inset-right)) calc(16px + env(safe-area-inset-bottom)) calc(14px + env(safe-area-inset-left));background:rgba(3,8,16,.58);backdrop-filter:blur(12px);-webkit-backdrop-filter:blur(12px)}
      .lrPhotoSourceOverlay.show{display:flex}
      .lrPhotoSourceSheet{width:min(100%,520px);border-radius:24px;padding:14px;background:color-mix(in srgb,var(--panel) 96%,#07111f);border:1px solid color-mix(in srgb,var(--gold) 28%,var(--line));box-shadow:0 28px 90px rgba(0,0,0,.46)}
      .lrPhotoSourceTitle{font-size:17px;font-weight:950;margin:2px 4px 4px}.lrPhotoSourceMeta{font-size:10px;color:var(--muted);margin:0 4px 12px}
      .lrPhotoSourceActions{display:grid;gap:8px}.lrPhotoSourceActions button{min-height:54px;text-align:left;padding:12px 14px;border-radius:15px;background:var(--panel2);color:var(--text);border:1px solid var(--line)}
      .lrPhotoSourceActions button b{display:block;font-size:13px}.lrPhotoSourceActions button span{display:block;font-size:9px;color:var(--muted);margin-top:2px}.lrPhotoSourceCancel{margin-top:8px;width:100%;min-height:46px;background:transparent!important;text-align:center!important;color:var(--muted)!important}
    `;
    document.head.appendChild(style);
  };

  const ensureSheet = () => {
    let overlay = document.getElementById("lifeRoutePhotoSourcePicker");
    if (overlay) return overlay;
    addStyles();
    overlay = document.createElement("div");
    overlay.id = "lifeRoutePhotoSourcePicker";
    overlay.className = "lrPhotoSourceOverlay";
    overlay.innerHTML = `
      <div class="lrPhotoSourceSheet" role="dialog" aria-modal="true" aria-label="Choose photo source">
        <div class="lrPhotoSourceTitle">Add a visual photo</div>
        <div class="lrPhotoSourceMeta">Choose where the image should come from.</div>
        <div class="lrPhotoSourceActions">
          <button type="button" id="lifeRouteUseCamera"><b>📷 Camera</b><span>Take a new photo now</span></button>
          <button type="button" id="lifeRouteUseLibrary"><b>🖼️ Photo Library</b><span>Choose an existing photo from your iPhone</span></button>
        </div>
        <button type="button" class="lrPhotoSourceCancel" id="lifeRoutePhotoSourceCancel">Cancel</button>
      </div>`;
    document.body.appendChild(overlay);

    const close = () => overlay.classList.remove("show");
    const pick = source => {
      const input = document.getElementById("visualCameraInput");
      if (!input) return close();
      input.value = "";
      if (source === "camera") input.setAttribute("capture", "environment");
      else input.removeAttribute("capture");
      close();
      setTimeout(() => input.click(), 30);
    };

    overlay.querySelector("#lifeRouteUseCamera")?.addEventListener("click", () => pick("camera"));
    overlay.querySelector("#lifeRouteUseLibrary")?.addEventListener("click", () => pick("library"));
    overlay.querySelector("#lifeRoutePhotoSourceCancel")?.addEventListener("click", close);
    overlay.addEventListener("click", event => { if (event.target === overlay) close(); });
    return overlay;
  };

  const retitle = () => {
    const button = document.getElementById("visualCameraButton");
    if (!button || button.dataset.lifeRoutePhotoPicker === "1") return !!button;
    button.dataset.lifeRoutePhotoPicker = "1";
    const bold = button.querySelector("b");
    const small = button.querySelector("span");
    if (bold) bold.textContent = "Add photo";
    if (small) small.textContent = "Camera or Photo Library";
    return true;
  };

  document.addEventListener("click", event => {
    const button = event.target.closest?.("#visualCameraButton");
    if (!button) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    ensureSheet().classList.add("show");
  }, true);

  let attempts = 0;
  const timer = setInterval(() => {
    attempts += 1;
    if (retitle() || attempts > 120) clearInterval(timer);
  }, 100);
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", retitle, { once: true });
  else retitle();
})();