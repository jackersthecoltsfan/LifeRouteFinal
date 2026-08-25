// Local subject-focus preprocessing for user-supplied visual-support photos.
// No network calls: the selected image is analyzed and cleaned with Canvas on-device before visual-tools.js sees it.
(() => {
  if (window.__lifeRouteVisualObjectFocusV2Loaded) return;
  window.__lifeRouteVisualObjectFocusV2Loaded = true;

  const style = document.createElement("style");
  style.id = "lifeRouteVisualObjectFocusV2Styles";
  style.textContent = `
    .visualDraftCard.lrSubjectProcessing:after{content:"Focusing subject…";position:absolute;inset:auto 10px 10px;z-index:4;padding:6px 9px;border-radius:999px;background:rgba(8,15,26,.78);color:#fff;font-size:9px;font-weight:900;text-align:center;backdrop-filter:blur(10px);-webkit-backdrop-filter:blur(10px)}
    .visualDraftCard{position:relative}.visualDraftCard img{transform-origin:center;transition:filter .25s ease}
    .visualDraftCard.lrSubjectReady img{animation:lrVisualDraftLiving 6.5s ease-in-out infinite alternate;filter:saturate(1.06) contrast(1.03)}
    @keyframes lrVisualDraftLiving{from{transform:scale(1.005) translate3d(-.25%,.1%,0)}to{transform:scale(1.03) translate3d(.35%,-.25%,0)}}
    @media(prefers-reduced-motion:reduce){.visualDraftCard.lrSubjectReady img{animation:none!important}}
  `;
  document.head.appendChild(style);

  const loadImage = file => new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const image = new Image();
    image.onload = () => { URL.revokeObjectURL(url); resolve(image); };
    image.onerror = error => { URL.revokeObjectURL(url); reject(error); };
    image.src = url;
  });

  const clamp = (value, min, max) => Math.max(min, Math.min(max, value));

  const subjectCrop = image => {
    const maxSide = 192;
    const scale = Math.min(1, maxSide / Math.max(image.naturalWidth, image.naturalHeight));
    const width = Math.max(32, Math.round(image.naturalWidth * scale));
    const height = Math.max(32, Math.round(image.naturalHeight * scale));
    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext("2d", { willReadFrequently: true });
    ctx.drawImage(image, 0, 0, width, height);
    const pixels = ctx.getImageData(0, 0, width, height).data;
    const lum = new Float32Array(width * height);

    for (let y = 0; y < height; y += 1) {
      for (let x = 0; x < width; x += 1) {
        const p = (y * width + x) * 4;
        const r = pixels[p], g = pixels[p + 1], b = pixels[p + 2];
        lum[y * width + x] = .2126 * r + .7152 * g + .0722 * b;
      }
    }

    const samples = [];
    let sum = 0, sumSq = 0, count = 0;
    for (let y = 2; y < height - 2; y += 2) {
      for (let x = 2; x < width - 2; x += 2) {
        const index = y * width + x;
        const dx = Math.abs(lum[index + 1] - lum[index - 1]);
        const dy = Math.abs(lum[index + width] - lum[index - width]);
        const p = index * 4;
        const max = Math.max(pixels[p], pixels[p + 1], pixels[p + 2]);
        const min = Math.min(pixels[p], pixels[p + 1], pixels[p + 2]);
        const saturation = max - min;
        const score = dx + dy + saturation * .28;
        samples.push([x, y, score]);
        sum += score; sumSq += score * score; count += 1;
      }
    }

    const mean = count ? sum / count : 0;
    const variance = count ? Math.max(0, sumSq / count - mean * mean) : 0;
    const threshold = mean + Math.sqrt(variance) * .62;
    let total = 0, sx = 0, sy = 0;
    const weighted = [];
    samples.forEach(([x, y, score]) => {
      if (score < threshold) return;
      const nx = (x / width - .5) * 2;
      const ny = (y / height - .5) * 2;
      const centerBias = .72 + .28 * (1 - Math.min(1, Math.hypot(nx, ny) / 1.25));
      const weight = Math.max(0.001, score - threshold + 1) * centerBias;
      weighted.push([x, y, weight]);
      total += weight; sx += x * weight; sy += y * weight;
    });

    const cx = total ? sx / total : width / 2;
    const cy = total ? sy / total : height / 2;
    let vx = 0, vy = 0;
    weighted.forEach(([x, y, weight]) => {
      vx += (x - cx) * (x - cx) * weight;
      vy += (y - cy) * (y - cy) * weight;
    });
    vx = total ? Math.sqrt(vx / total) : width * .16;
    vy = total ? Math.sqrt(vy / total) : height * .16;

    const originalX = cx / width * image.naturalWidth;
    const originalY = cy / height * image.naturalHeight;
    const spread = Math.max(vx / width * image.naturalWidth, vy / height * image.naturalHeight);
    const minSide = Math.min(image.naturalWidth, image.naturalHeight);
    const side = clamp(spread * 5.6, minSide * .52, minSide * .94);
    const left = clamp(originalX - side / 2, 0, Math.max(0, image.naturalWidth - side));
    const top = clamp(originalY - side / 2, 0, Math.max(0, image.naturalHeight - side));
    return { left, top, side, focusX: originalX, focusY: originalY };
  };

  const roundRect = (ctx, x, y, width, height, radius) => {
    const r = Math.min(radius, width / 2, height / 2);
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + width, y, x + width, y + height, r);
    ctx.arcTo(x + width, y + height, x, y + height, r);
    ctx.arcTo(x, y + height, x, y, r);
    ctx.arcTo(x, y, x + width, y, r);
    ctx.closePath();
  };

  const preprocess = async file => {
    const image = await loadImage(file);
    const crop = subjectCrop(image);
    const canvas = document.createElement("canvas");
    canvas.width = 1024;
    canvas.height = 1024;
    const ctx = canvas.getContext("2d");

    ctx.fillStyle = "#fff";
    ctx.fillRect(0, 0, 1024, 1024);

    // Quiet, bright context layer so clutter does not compete with the subject.
    ctx.save();
    ctx.filter = "blur(28px) saturate(.62) contrast(.9) brightness(1.1)";
    ctx.globalAlpha = .42;
    ctx.drawImage(image, crop.left, crop.top, crop.side, crop.side, -42, -42, 1108, 1108);
    ctx.restore();
    ctx.fillStyle = "rgba(255,255,255,.56)";
    ctx.fillRect(0, 0, 1024, 1024);

    // Sharp subject-forward crop with a soft white frame; visual-tools applies the final bold style afterward.
    const inset = 58;
    ctx.save();
    roundRect(ctx, inset, inset, 1024 - inset * 2, 1024 - inset * 2, 54);
    ctx.clip();
    ctx.filter = "saturate(1.13) contrast(1.08) brightness(1.02)";
    ctx.drawImage(image, crop.left, crop.top, crop.side, crop.side, inset, inset, 1024 - inset * 2, 1024 - inset * 2);
    ctx.restore();

    const vignette = ctx.createRadialGradient(512, 470, 250, 512, 512, 690);
    vignette.addColorStop(0, "rgba(255,255,255,0)");
    vignette.addColorStop(.72, "rgba(255,255,255,.04)");
    vignette.addColorStop(1, "rgba(255,255,255,.42)");
    ctx.fillStyle = vignette;
    ctx.fillRect(0, 0, 1024, 1024);

    const blob = await new Promise(resolve => canvas.toBlob(resolve, "image/jpeg", .93));
    if (!blob) return file;
    const base = String(file.name || "visual").replace(/\.[^.]+$/, "") || "visual";
    return new File([blob], `${base}-subject.jpg`, { type: "image/jpeg", lastModified: Date.now() });
  };

  document.addEventListener("change", event => {
    const input = event.target;
    if (!(input instanceof HTMLInputElement) || input.id !== "visualCameraInput") return;
    if (input.dataset.lrObjectFocusBypass === "1") return;
    const file = input.files?.[0];
    if (!file || !String(file.type || "").startsWith("image/")) return;

    event.preventDefault();
    event.stopImmediatePropagation();
    const card = document.querySelector(".visualDraftCard");
    card?.classList.add("lrSubjectProcessing");
    if (typeof setStatus === "function") setStatus("Focusing the main subject…");

    preprocess(file).then(processed => {
      const transfer = new DataTransfer();
      transfer.items.add(processed);
      input.files = transfer.files;
      input.dataset.lrObjectFocusBypass = "1";
      input.dispatchEvent(new Event("change", { bubbles: true }));
      queueMicrotask(() => delete input.dataset.lrObjectFocusBypass);
      card?.classList.remove("lrSubjectProcessing");
      card?.classList.add("lrSubjectReady");
      if (typeof setStatus === "function") setStatus("Main subject focused · ready to label");
    }).catch(() => {
      input.dataset.lrObjectFocusBypass = "1";
      input.dispatchEvent(new Event("change", { bubbles: true }));
      queueMicrotask(() => delete input.dataset.lrObjectFocusBypass);
      card?.classList.remove("lrSubjectProcessing");
      if (typeof setStatus === "function") setStatus("Photo ready");
    });
  }, true);

  window.LifeRouteVisualObjectFocus = { preprocess };
})();
