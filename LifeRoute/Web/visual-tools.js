// LifeRoute visual-support tools: automatic camera icon styling, visual First/Then, and choice boards.
// Images stay on-device/in-browser in localStorage. No upload service is used.
(() => {
  const STORE = "liferoute_visual_tools_v2";
  const MAX_ICONS = 18;
  let state = {
    icons: [],
    firstIconId: "",
    thenIconId: "",
    firstMode: "auto",
    thenMode: "auto",
    firstThenVisual: true,
    boardSelection: []
  };

  try {
    const saved = JSON.parse(localStorage.getItem(STORE) || "{}");
    state.icons = Array.isArray(saved.icons) ? saved.icons : [];
    state.firstIconId = String(saved.firstIconId || "");
    state.thenIconId = String(saved.thenIconId || "");
    state.firstMode = ["text","auto","saved"].includes(saved.firstMode) ? saved.firstMode : "auto";
    state.thenMode = ["text","auto","saved"].includes(saved.thenMode) ? saved.thenMode : "auto";
    state.firstThenVisual = saved.firstThenVisual !== false;
    state.boardSelection = Array.isArray(saved.boardSelection) ? saved.boardSelection : [];
  } catch (_) {}

  const save = () => {
    try {
      localStorage.setItem(STORE, JSON.stringify(state));
      return true;
    } catch (_) {
      if (typeof setStatus === "function") setStatus("Icon library is full · remove an older icon");
      return false;
    }
  };

  const safe = value => typeof esc === "function"
    ? esc(String(value || ""))
    : String(value || "").replace(/[&<>"']/g, char => ({
        "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#039;"
      }[char]));

  const getIcon = id => state.icons.find(item => item.id === id) || null;

  const toolsView = () => document.getElementById("tools");

  const ensureTools = () => {
    const view = toolsView();
    const grid = view?.querySelector(".toolGrid");
    if (!view || !grid || document.getElementById("visualIconTool")) return false;

    const iconTool = document.createElement("div");
    iconTool.className = "card toolCard";
    iconTool.id = "visualIconTool";
    iconTool.innerHTML = `
      <div class="toolHead"><div class="toolIcon">◫</div><div class="grow"><div class="title">Visual support icon maker</div><div class="meta">Take a photo and LifeRoute automatically turns it into your clean visual-support style. Add a label before saving.</div></div></div>
      <div class="visualCaptureLayout">
        <button class="visualCameraTile" id="visualCameraButton" type="button">
          <div class="visualCameraGlyph">⌁</div>
          <b>Take photo</b>
          <span>or choose a photo</span>
        </button>
        <div class="visualDraftCard">
          <img id="visualDraftImage" alt="" hidden>
          <div id="visualDraftEmpty"><b>No photo yet</b><span>Photograph the object, activity, person, or place you want represented.</span></div>
        </div>
      </div>
      <input id="visualCameraInput" type="file" accept="image/*" capture="environment" hidden>
      <div class="toolInline visualLabelRow">
        <input id="visualIconLabel" maxlength="28" placeholder="Label · e.g. Outside">
        <button class="goldButton" id="createVisualIcon" type="button">Save visual</button>
      </div>
      <div class="tiny">Automatic style: white card, bold graphic edges, bright high-contrast color, centered square image, and a clear sans-serif label. Photos are processed locally and are not uploaded.</div>
      <div class="visualLibraryHead"><b>Visual library</b><span id="visualIconCount" class="tiny">0 icons</span></div>
      <div id="visualIconLibrary" class="visualIconLibrary"></div>
    `;

    const boardTool = document.createElement("div");
    boardTool.className = "card toolCard";
    boardTool.id = "choiceBoardTool";
    boardTool.innerHTML = `
      <div class="toolHead"><div class="toolIcon">▦</div><div class="grow"><div class="title">Choice board creator</div><div class="meta">Build a visual board from your saved visual support icons. Default layout matches an 8-choice, 2 × 4 board.</div></div></div>
      <div class="grid2">
        <div><label>Board title</label><input id="choiceBoardTitle" value="Choices" maxlength="36"></div>
        <div><label>Layout</label><select id="choiceBoardLayout"><option value="2">2 columns · up to 8</option><option value="3">3 columns · up to 9</option></select></div>
      </div>
      <div class="visualLibraryHead"><b>Choose icons</b><span id="choiceBoardCount" class="tiny">0 / 8 selected</span></div>
      <div id="choiceBoardPicker" class="choiceBoardPicker"></div>
      <div class="toolActions"><button class="goldButton" id="showChoiceBoard" type="button">Show board</button><button class="secondary" id="exportChoiceBoard" type="button">Create board image</button><button class="secondary" id="clearChoiceBoard" type="button">Clear</button></div>
    `;

    const firstThen = document.getElementById("firstThenTool");
    if (firstThen) {
      firstThen.insertAdjacentHTML("beforeend", `
        <div class="visualFirstThenControls">
          <div class="row"><div><b>Board display</b><div class="tiny">LifeRoute can create the visual automatically from whatever you type.</div></div><span class="badge green">SMART</span></div>
          <div class="grid2 visualFirstThenSelects">
            <div>
              <label>First display</label>
              <select id="firstThenFirstMode">
                <option value="auto">Text + auto visual</option>
                <option value="text">Text only</option>
                <option value="saved">Text + saved visual</option>
              </select>
              <div class="savedVisualField" id="firstThenFirstSavedWrap"><label>Saved visual</label><select id="firstThenFirstIcon"></select></div>
            </div>
            <div>
              <label>Then display</label>
              <select id="firstThenThenMode">
                <option value="auto">Text + auto visual</option>
                <option value="text">Text only</option>
                <option value="saved">Text + saved visual</option>
              </select>
              <div class="savedVisualField" id="firstThenThenSavedWrap"><label>Saved visual</label><select id="firstThenThenIcon"></select></div>
            </div>
          </div>
          <div class="tiny">Auto visual is the default. No icon setup is required before using First / Then.</div>
        </div>
      `);
    }

    if (firstThen?.nextSibling) grid.insertBefore(iconTool, firstThen.nextSibling);
    else grid.appendChild(iconTool);
    grid.insertBefore(boardTool, iconTool.nextSibling);
    return true;
  };

  const styles = document.createElement("style");
  styles.id = "visualToolStyles";
  styles.textContent = `
    .visualCaptureLayout{display:grid;grid-template-columns:150px 1fr;gap:9px;margin-bottom:9px}.visualCameraTile{min-height:145px;border:1px dashed color-mix(in srgb,var(--blue) 44%,var(--line));background:color-mix(in srgb,var(--blue) 5%,var(--panel2));color:var(--text);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:3px}.visualCameraTile span{font-size:9px;color:var(--muted)}.visualCameraGlyph{font-size:28px;color:var(--blue);margin-bottom:4px}.visualDraftCard{min-height:145px;border-radius:14px;border:1px solid var(--line);background:#fff;overflow:hidden;display:grid;place-items:center}.visualDraftCard img{width:100%;height:145px;object-fit:cover}.visualDraftCard #visualDraftEmpty{color:#243348;text-align:center;padding:18px;display:grid;gap:4px}.visualDraftCard #visualDraftEmpty span{font-size:9px;color:#66768b;line-height:1.4}.visualLabelRow{margin-top:8px}.visualLibraryHead{display:flex;justify-content:space-between;align-items:center;margin:12px 0 7px}.visualIconLibrary,.choiceBoardPicker{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:7px}.visualLibraryItem,.choicePick{position:relative;border:1px solid var(--line);border-radius:12px;padding:6px;background:color-mix(in srgb,var(--panel2) 76%,transparent);text-align:center;color:var(--text);overflow:hidden}.visualLibraryItem img,.choicePick img{width:100%;aspect-ratio:1;object-fit:cover;border-radius:8px;background:white}.visualLibraryItem b,.choicePick b{display:block;font-size:9px;margin-top:4px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.visualDelete{position:absolute;right:3px;top:3px;width:24px;height:24px;padding:0;border-radius:999px;background:rgba(8,15,26,.82);color:white;font-size:13px}.choicePick.selected{border-color:var(--gold);box-shadow:inset 0 0 0 1px var(--gold);background:color-mix(in srgb,var(--gold) 8%,var(--panel2))}.choicePick.selected:after{content:"✓";position:absolute;top:5px;right:5px;width:21px;height:21px;border-radius:999px;display:grid;place-items:center;background:var(--gold);color:var(--bg);font-size:11px;font-weight:950}.visualFirstThenControls{margin-top:10px;padding-top:10px;border-top:1px solid var(--line)}.visualFirstThenSelects{margin-top:8px}.savedVisualField{display:none;margin-top:7px}.savedVisualField.show{display:block}.autoVisualBadge{display:inline-flex;align-items:center;gap:5px;font-size:8px;font-weight:950;letter-spacing:.06em;text-transform:uppercase;color:#10213a;background:#f1ce74;border-radius:999px;padding:4px 7px;margin-bottom:8px}
    .firstThenVisualImage{width:min(46vw,390px);max-height:48vh;object-fit:contain;border-radius:24px;background:white;border:0;box-shadow:0 16px 48px rgba(0,0,0,.18);margin-bottom:0}.firstThenPanel.visualReady .firstThenValue{display:none}
    .choiceBoardOverlay{position:fixed;inset:0;z-index:12500;display:none;background:#f8fafc;color:#10213a;padding:calc(12px + env(safe-area-inset-top)) 14px calc(14px + env(safe-area-inset-bottom));overflow:auto}.choiceBoardOverlay.show{display:block}.choiceBoardTop{max-width:900px;margin:0 auto 12px;display:flex;justify-content:space-between;align-items:center}.choiceBoardTop button{background:#e9eff7;color:#10213a}.choiceBoardTitle{font-size:clamp(24px,5vw,42px);font-weight:950;text-align:center;margin:5px 0 18px}.choiceBoardGrid{--choice-columns:2;max-width:900px;margin:auto;display:grid;grid-template-columns:repeat(var(--choice-columns),minmax(0,1fr));gap:12px}.choiceBoardCell{min-height:190px;background:white;border:3px solid #10213a;border-radius:20px;padding:10px;display:flex;flex-direction:column;align-items:center;justify-content:center;box-shadow:0 10px 28px rgba(16,33,58,.08)}.choiceBoardCell img{width:100%;max-height:260px;aspect-ratio:1;object-fit:contain}.choiceBoardCell b{font:900 clamp(18px,4vw,32px)/1.05 system-ui,-apple-system,sans-serif;margin-top:8px;text-align:center}.choiceBoardEmpty{grid-column:1/-1;text-align:center;color:#66768b;padding:30px}
    @media(max-width:680px){.visualCaptureLayout{grid-template-columns:115px 1fr}.visualCameraTile,.visualDraftCard{min-height:118px}.visualDraftCard img{height:118px}.visualIconLibrary,.choiceBoardPicker{grid-template-columns:repeat(3,minmax(0,1fr))}.choiceBoardCell{min-height:150px;border-width:2px;border-radius:16px;padding:8px}.firstThenVisualImage{width:min(78vw,360px);max-height:32vh;margin-bottom:0}}
  `;
  document.head.appendChild(styles);

  let draftFile = null;
  let draftURL = "";
  let draftGeneratedURL = "";
  let draftGenerationToken = 0;
  let labelDebounce = 0;

  const renderIconSelectors = () => {
    const options = ['<option value="">Text only / no icon</option>']
      .concat(state.icons.map(item => `<option value="${safe(item.id)}">${safe(item.label)}</option>`))
      .join("");
    const first = document.getElementById("firstThenFirstIcon");
    const then = document.getElementById("firstThenThenIcon");
    if (first) {
      first.innerHTML = options;
      first.value = getIcon(state.firstIconId) ? state.firstIconId : "";
    }
    if (then) {
      then.innerHTML = options;
      then.value = getIcon(state.thenIconId) ? state.thenIconId : "";
    }
    const firstMode = document.getElementById("firstThenFirstMode");
    const thenMode = document.getElementById("firstThenThenMode");
    if (firstMode) firstMode.value = state.firstMode || "auto";
    if (thenMode) thenMode.value = state.thenMode || "auto";
    document.getElementById("firstThenFirstSavedWrap")?.classList.toggle("show", state.firstMode === "saved");
    document.getElementById("firstThenThenSavedWrap")?.classList.toggle("show", state.thenMode === "saved");
  };

  const renderLibraries = () => {
    state.boardSelection = state.boardSelection.filter(id => !!getIcon(id));
    const lib = document.getElementById("visualIconLibrary");
    const picker = document.getElementById("choiceBoardPicker");
    const count = document.getElementById("visualIconCount");
    const boardCount = document.getElementById("choiceBoardCount");
    const max = Number(document.getElementById("choiceBoardLayout")?.value || 2) === 3 ? 9 : 8;

    if (count) count.textContent = `${state.icons.length} icon${state.icons.length === 1 ? "" : "s"}`;
    if (boardCount) boardCount.textContent = `${state.boardSelection.length} / ${max} selected`;

    if (lib) {
      lib.innerHTML = state.icons.length ? state.icons.map(item => `
        <div class="visualLibraryItem">
          <img src="${item.dataURL}" alt="${safe(item.label)}">
          <b>${safe(item.label)}</b>
          <button class="visualDelete" type="button" data-delete-visual="${safe(item.id)}" aria-label="Delete icon">×</button>
        </div>
      `).join("") : '<div class="tiny" style="grid-column:1/-1;padding:8px 0">No visuals yet. Take a photo above to make your first one.</div>';
      lib.querySelectorAll("[data-delete-visual]").forEach(button => {
        button.onclick = () => {
          const id = button.dataset.deleteVisual;
          state.icons = state.icons.filter(item => item.id !== id);
          state.boardSelection = state.boardSelection.filter(value => value !== id);
          if (state.firstIconId === id) state.firstIconId = "";
          if (state.thenIconId === id) state.thenIconId = "";
          save();
          renderAllVisual();
        };
      });
    }

    if (picker) {
      picker.innerHTML = state.icons.length ? state.icons.map(item => `
        <button class="choicePick ${state.boardSelection.includes(item.id) ? "selected" : ""}" type="button" data-choice-visual="${safe(item.id)}">
          <img src="${item.dataURL}" alt="${safe(item.label)}"><b>${safe(item.label)}</b>
        </button>
      `).join("") : '<div class="tiny" style="grid-column:1/-1;padding:8px 0">Create visuals first, then choose them for the board.</div>';
      picker.querySelectorAll("[data-choice-visual]").forEach(button => {
        button.onclick = () => {
          const id = button.dataset.choiceVisual;
          const selected = state.boardSelection.includes(id);
          if (selected) state.boardSelection = state.boardSelection.filter(value => value !== id);
          else if (state.boardSelection.length < max) state.boardSelection.push(id);
          else if (typeof setStatus === "function") setStatus(`Choice board limit · ${max} icons`);
          save();
          renderLibraries();
        };
      });
    }
  };

  const renderAllVisual = () => {
    renderIconSelectors();
    renderLibraries();
  };

  const loadImage = file => new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const image = new Image();
    image.onload = () => {
      URL.revokeObjectURL(url);
      resolve(image);
    };
    image.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error("Could not read image"));
    };
    image.src = url;
  });

  const drawCover = (ctx, image, x, y, width, height) => {
    const ratio = Math.max(width / image.naturalWidth, height / image.naturalHeight);
    const w = image.naturalWidth * ratio;
    const h = image.naturalHeight * ratio;
    ctx.drawImage(image, x + (width - w) / 2, y + (height - h) / 2, w, h);
  };

  const posterize = (imageData, width, height) => {
    const original = new Uint8ClampedArray(imageData.data);
    const data = imageData.data;
    const lum = index => .299 * original[index] + .587 * original[index + 1] + .114 * original[index + 2];
    const step = 42;

    for (let y = 1; y < height - 1; y += 1) {
      for (let x = 1; x < width - 1; x += 1) {
        const i = (y * width + x) * 4;
        const left = i - 4;
        const right = i + 4;
        const up = i - width * 4;
        const down = i + width * 4;
        const edge = Math.abs(lum(left) - lum(right)) + Math.abs(lum(up) - lum(down));

        let r = (original[i] - 128) * 1.18 + 128;
        let g = (original[i + 1] - 128) * 1.18 + 128;
        let b = (original[i + 2] - 128) * 1.18 + 128;
        const avg = (r + g + b) / 3;
        r = avg + (r - avg) * 1.18;
        g = avg + (g - avg) * 1.18;
        b = avg + (b - avg) * 1.18;

        if (edge > 92) {
          data[i] = 28; data[i + 1] = 34; data[i + 2] = 40;
        } else {
          data[i] = Math.max(0, Math.min(255, Math.round(r / step) * step));
          data[i + 1] = Math.max(0, Math.min(255, Math.round(g / step) * step));
          data[i + 2] = Math.max(0, Math.min(255, Math.round(b / step) * step));
        }
        data[i + 3] = 255;
      }
    }
    return imageData;
  };

  const makeVisualIcon = async (file, label) => {
    const image = await loadImage(file);
    const canvas = document.createElement("canvas");
    canvas.width = 512;
    canvas.height = 512;
    const ctx = canvas.getContext("2d", { willReadFrequently: true });
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, 512, 512);

    const x = 24, y = 24, w = 464, h = 368;
    ctx.save();
    ctx.beginPath();
    ctx.roundRect(x, y, w, h, 18);
    ctx.clip();
    drawCover(ctx, image, x, y, w, h);
    ctx.restore();

    try {
      const pixels = ctx.getImageData(x, y, w, h);
      ctx.putImageData(posterize(pixels, w, h), x, y);
    } catch (_) {}

    ctx.strokeStyle = "#172231";
    ctx.lineWidth = 6;
    ctx.beginPath();
    ctx.roundRect(x, y, w, h, 18);
    ctx.stroke();

    ctx.fillStyle = "#101820";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    const cleanLabel = String(label || "Icon").trim().slice(0, 28);
    let fontSize = 48;
    ctx.font = `900 ${fontSize}px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif`;
    while (ctx.measureText(cleanLabel).width > 440 && fontSize > 28) {
      fontSize -= 2;
      ctx.font = `900 ${fontSize}px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif`;
    }
    ctx.fillText(cleanLabel, 256, 452);

    return canvas.toDataURL("image/jpeg", .90);
  };


  const generateDraftVisual = async () => {
    if (!draftFile) return "";
    const token = ++draftGenerationToken;
    const labelField = document.getElementById("visualIconLabel");
    const label = String(labelField?.value || "").trim() || "Visual";
    const saveButton = document.getElementById("createVisualIcon");
    if (saveButton) {
      saveButton.disabled = true;
      saveButton.textContent = "Generating…";
    }
    try {
      const generated = await makeVisualIcon(draftFile, label);
      if (token !== draftGenerationToken) return "";
      draftGeneratedURL = generated;
      const img = document.getElementById("visualDraftImage");
      const empty = document.getElementById("visualDraftEmpty");
      if (img) {
        img.src = generated;
        img.hidden = false;
      }
      if (empty) empty.style.display = "none";
      if (typeof setStatus === "function") {
        setStatus(labelField?.value?.trim()
          ? "Visual generated automatically · ready to save"
          : "Visual generated automatically · add a label to save");
      }
      return generated;
    } catch (_) {
      if (token === draftGenerationToken) {
        draftGeneratedURL = "";
        if (typeof setStatus === "function") setStatus("Could not generate visual from that photo");
      }
      return "";
    } finally {
      if (token === draftGenerationToken && saveButton) {
        saveButton.disabled = false;
        saveButton.textContent = "Save visual";
      }
    }
  };

  const chooseDraft = file => {
    if (!file) return;
    draftFile = file;
    if (draftURL) URL.revokeObjectURL(draftURL);
    draftURL = URL.createObjectURL(file);
    const img = document.getElementById("visualDraftImage");
    const empty = document.getElementById("visualDraftEmpty");
    if (img) {
      img.src = draftURL;
      img.hidden = false;
    }
    if (empty) empty.style.display = "none";
    generateDraftVisual();
    const labelField = document.getElementById("visualIconLabel");
    if (labelField && !labelField.value.trim()) setTimeout(() => labelField.focus(), 80);
  };

  const createIcon = async () => {
    const label = String(document.getElementById("visualIconLabel")?.value || "").trim();
    if (!draftFile) {
      alert("Take or choose a photo first.");
      return;
    }
    if (!label) {
      alert("Add the word you want printed under the icon.");
      return;
    }
    const button = document.getElementById("createVisualIcon");
    if (button) {
      button.disabled = true;
      button.textContent = "Creating…";
    }
    try {
      const dataURL = draftGeneratedURL || await generateDraftVisual() || await makeVisualIcon(draftFile, label);
      const item = {
        id: `visual-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
        label,
        dataURL,
        createdAt: new Date().toISOString()
      };
      state.icons.push(item);
      if (state.icons.length > MAX_ICONS) {
        const protectedIds = new Set([state.firstIconId, state.thenIconId, ...state.boardSelection]);
        const removable = state.icons.find(icon => !protectedIds.has(icon.id) && icon.id !== item.id);
        if (removable) state.icons = state.icons.filter(icon => icon.id !== removable.id);
      }
      if (!save()) {
        state.icons = state.icons.filter(icon => icon.id !== item.id);
        return;
      }
      document.getElementById("visualIconLabel").value = "";
      draftFile = null;
      draftGeneratedURL = "";
      const img = document.getElementById("visualDraftImage");
      const empty = document.getElementById("visualDraftEmpty");
      if (img) {
        img.hidden = true;
        img.removeAttribute("src");
      }
      if (empty) empty.style.display = "";
      renderAllVisual();
      if (typeof setStatus === "function") setStatus(`${label} visual support icon created`);
    } catch (_) {
      alert("LifeRoute could not process that photo. Try another image.");
    } finally {
      if (button) {
        button.disabled = false;
        button.textContent = "Save visual";
      }
    }
  };


  // ----- Automatic First / Then visuals -----
  // These are intentionally illustrated cards rather than emoji tiles. The
  // visual language matches LifeRoute's established visual-support cards:
  // white background, thick rounded black border, bold line art, bright
  // natural colors, one clear concept, and a large readable label.
  const AUTO_VISUALS = [
    { terms:["table work","work","worksheet","desk","school work"], scene:"tableWork" },
    { terms:["magna tiles","magna-tiles","magnet tiles","magnetic tiles"], scene:"magnaTiles" },
    { terms:["outside","outdoors","play outside","yard","park"], scene:"outside" },
    { terms:["eat","food","snack","lunch","dinner","breakfast"], scene:"eat" },
    { terms:["play","toy","toys"], scene:"play" },
    { terms:["bathroom","toilet","potty"], scene:"bathroom" },
    { terms:["drink","water"], scene:"drink" },
    { terms:["swing"], scene:"swing" },
    { terms:["pool","swim","swimming","water play"], scene:"pool" },
    { terms:["bubbles"], scene:"bubbles" },
    { terms:["ipad","tablet","phone","screen"], scene:"tablet" },
    { terms:["music","song","sing"], scene:"music" },
    { terms:["break","rest","calm","quiet"], scene:"break" },
    { terms:["home","go home"], scene:"home" },
    { terms:["car","drive","ride"], scene:"car" },
    { terms:["walk","walking"], scene:"walk" },
    { terms:["help"], scene:"help" },
    { terms:["more"], scene:"more" },
    { terms:["hug"], scene:"hug" },
    { terms:["mom","mother"], scene:"person" },
    { terms:["dad","father"], scene:"person" },
    { terms:["grandma","grandmother"], scene:"person" },
    { terms:["draw","drawing","color","coloring"], scene:"drawing" },
    { terms:["blocks","lego","tiles"], scene:"blocks" },
    { terms:["book","read","reading"], scene:"book" },
    { terms:["sleep","nap","bed"], scene:"sleep" }
  ];
  const autoVisualCache = new Map();

  const svgEsc = value => String(value || "").replace(/[&<>"']/g, char => ({
    "&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;"
  }[char]));

  const resolveAutoVisual = text => {
    const raw = String(text || "").trim().toLowerCase().replace(/[–—]/g, "-");
    for (const item of AUTO_VISUALS) {
      if (item.terms.some(term => raw.includes(term))) return item.scene;
    }
    return "generic";
  };

  const sceneTableWork = () => `
    <g stroke="#111923" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <ellipse cx="245" cy="289" rx="153" ry="58" fill="#1772cf"/>
      <path d="M126 316v72M364 316v72" fill="none" stroke="#1260ad" stroke-width="20"/>
      <rect x="339" y="191" width="69" height="116" rx="16" fill="#1975cf"/>
      <circle cx="302" cy="180" r="43" fill="#d89755"/>
      <path d="M263 166q18-49 79-22q3 28-10 50" fill="#20242b"/>
      <path d="M273 213q32 16 55 0l22 88h-91z" fill="#4fa63d"/>
      <path d="M270 236q-22 22-47 43M335 240q15 26 35 43" fill="none" stroke="#d89755" stroke-width="18"/>
      <rect x="174" y="252" width="46" height="37" rx="6" fill="#fff"/><circle cx="197" cy="270" r="8" fill="#ef4343"/>
      <rect x="225" y="250" width="46" height="37" rx="6" fill="#fff"/><path d="M238 273l10-14 10 14z" fill="#f2cf3d"/>
      <rect x="276" y="248" width="46" height="37" rx="6" fill="#fff"/><rect x="288" y="258" width="22" height="15" rx="5" fill="#5aa76a"/>
      <rect x="115" y="221" width="75" height="61" rx="8" fill="#1673c6"/>
      <path d="M127 222h50v-22h-50z" fill="#fff"/><circle cx="152" cy="211" r="9" fill="#ef3e36"/>
    </g>`;

  const sceneOutside = () => `
    <g stroke="#111923" stroke-width="4.5" stroke-linejoin="round">
      <rect x="54" y="72" width="404" height="260" rx="24" fill="#6bc4f2"/>
      <path d="M54 200h404v132H54z" fill="#d8d0bd"/>
      <path d="M54 213L176 128L279 221L363 145L458 218V72H54z" fill="#79b957" opacity=".98"/>
      <rect x="70" y="160" width="128" height="67" fill="#bd5f43"/><path d="M65 160l69-51 70 51z" fill="#555d68"/>
      <rect x="91" y="180" width="23" height="47" fill="#fff"/><rect x="142" y="179" width="30" height="25" fill="#bfe6f6"/>
      <path d="M253 225v-95" stroke="#6d462c" stroke-width="18"/><circle cx="254" cy="118" r="76" fill="#4b9a39"/>
      <path d="M69 260h380" stroke="#31373e" stroke-width="7"/><path d="M85 231v90M131 231v90M177 231v90M223 231v90M269 231v90M315 231v90M361 231v90M407 231v90" stroke="#31373e" stroke-width="4"/>
      <path d="M96 299h64l-8 48H104z" fill="#fff"/><path d="M112 299v-28h34v28" fill="none"/>
      <path d="M351 297h64l-8 48h-48z" fill="#1d5f9f"/><path d="M365 297v-30h35v30" fill="none"/>
    </g>`;

  const sceneMagnaTiles = () => `
    <g stroke="#111923" stroke-width="5" stroke-linejoin="round">
      <rect x="141" y="161" width="73" height="73" rx="6" fill="#ef302c"/>
      <rect x="219" y="161" width="73" height="73" rx="6" fill="#ef302c"/>
      <rect x="297" y="161" width="73" height="73" rx="6" fill="#ef302c"/>
      <rect x="141" y="239" width="73" height="73" rx="6" fill="#ef302c"/>
      <rect x="219" y="239" width="73" height="73" rx="6" fill="#ef302c"/>
      <rect x="297" y="239" width="73" height="73" rx="6" fill="#ef302c"/>
      <path d="M141 156l37-70 36 70z" fill="#65c92f"/>
      <path d="M219 156l36-59 37 59z" fill="#278be7"/>
      <path d="M297 156l36-70 37 70z" fill="#65c92f"/>
      <path d="M141 317h73v73h-73zM297 317h73v73h-73z" fill="#ef302c"/>
      <path d="M219 317h73v73h-73z" fill="#fff"/>
      <path d="M219 390l36-36 37 36z" fill="#2d96ef"/>
      <path d="M103 302l34-63 31 63zM372 302l33-63 31 63z" fill="#ffd52d"/>
      <g fill="#fff" stroke-width="3"><circle cx="151" cy="172" r="6"/><circle cx="204" cy="172" r="6"/><circle cx="151" cy="224" r="6"/><circle cx="204" cy="224" r="6"/><circle cx="229" cy="172" r="6"/><circle cx="282" cy="172" r="6"/><circle cx="307" cy="172" r="6"/><circle cx="360" cy="172" r="6"/></g>
    </g>`;

  const sceneEat = () => `
    <g stroke="#111923" stroke-width="5" stroke-linejoin="round">
      <ellipse cx="250" cy="298" rx="130" ry="54" fill="#f4f0e8"/>
      <circle cx="250" cy="296" r="78" fill="#fff"/>
      <path d="M211 293q38-48 78 0q-39 57-78 0z" fill="#ef493f"/>
      <path d="M249 247q10-24 28-29" fill="none" stroke="#5b7d30" stroke-width="9"/>
      <ellipse cx="285" cy="224" rx="20" ry="10" fill="#74a83d"/>
      <path d="M131 237v123M112 237v64q0 28 19 28q19 0 19-28v-64" fill="none" stroke="#8e98a3" stroke-width="9"/>
      <path d="M365 237v123M348 237q17 25 17 52q0-27 17-52" fill="none" stroke="#8e98a3" stroke-width="9"/>
    </g>`;

  const scenePlay = () => `
    <g stroke="#111923" stroke-width="5" stroke-linejoin="round">
      <circle cx="245" cy="202" r="53" fill="#c48b55"/>
      <circle cx="202" cy="161" r="23" fill="#c48b55"/><circle cx="288" cy="161" r="23" fill="#c48b55"/>
      <ellipse cx="245" cy="294" rx="76" ry="77" fill="#c48b55"/>
      <circle cx="225" cy="193" r="5" fill="#111923"/><circle cx="266" cy="193" r="5" fill="#111923"/>
      <ellipse cx="245" cy="220" rx="21" ry="16" fill="#e7b879"/><circle cx="245" cy="216" r="5" fill="#111923"/>
      <path d="M175 274q-47 36-30 88M315 274q47 36 30 88" fill="none" stroke="#c48b55" stroke-width="27"/>
      <rect x="102" y="326" width="67" height="62" rx="6" fill="#f04442"/><rect x="177" y="337" width="61" height="51" rx="6" fill="#317ddd"/><rect x="246" y="318" width="68" height="70" rx="6" fill="#f1ca2e"/>
    </g>`;

  const sceneBathroom = () => `
    <g stroke="#111923" stroke-width="5" stroke-linejoin="round">
      <rect x="142" y="128" width="228" height="53" rx="18" fill="#ecf1f6"/>
      <path d="M165 182h184v113q0 67-92 67t-92-67z" fill="#f8fbfd"/>
      <ellipse cx="257" cy="253" rx="69" ry="35" fill="#cfe6f2"/>
      <rect x="187" y="340" width="140" height="31" rx="14" fill="#d7e4ea"/>
      <circle cx="337" cy="154" r="8" fill="#8a98a3"/>
    </g>`;

  const sceneDrink = () => `
    <g stroke="#111923" stroke-width="5" stroke-linejoin="round">
      <path d="M178 143h162l-17 205q-3 31-64 31q-61 0-64-31z" fill="#d9f2ff"/>
      <path d="M192 226h132l-10 122q-2 18-55 18q-53 0-55-18z" fill="#59b7ec"/>
      <path d="M294 144l48-76" fill="none" stroke="#ef5a5a" stroke-width="12"/>
      <ellipse cx="259" cy="144" rx="82" ry="19" fill="#edf8fd"/>
    </g>`;

  const sceneSwing = () => `
    <g stroke="#111923" stroke-width="6" stroke-linejoin="round">
      <path d="M116 380l91-252M396 380l-91-252M171 221h169" fill="none" stroke="#315f91" stroke-width="17"/>
      <path d="M222 221v96M290 221v96" fill="none" stroke="#545b63" stroke-width="5"/>
      <path d="M210 317h92l-10 37h-72z" fill="#efb735"/>
      <circle cx="256" cy="125" r="18" fill="#75c65c"/>
    </g>`;

  const scenePool = () => `
    <g stroke="#111923" stroke-width="5" stroke-linejoin="round">
      <rect x="91" y="165" width="330" height="207" rx="25" fill="#55b9ee"/>
      <path d="M91 234q55-24 110 0q55 24 110 0q55-24 110 0M91 282q55-24 110 0q55 24 110 0q55-24 110 0" fill="none" stroke="#e9fbff" stroke-width="11"/>
      <path d="M124 150v180M124 170h53M177 150v180" fill="none" stroke="#f3f5f6" stroke-width="12"/>
      <circle cx="330" cy="198" r="34" fill="#f1a654"/><path d="M297 247q33-37 67 0" fill="none" stroke="#e95c49" stroke-width="24"/>
    </g>`;

  const sceneBubbles = () => `
    <g stroke="#111923" stroke-width="4">
      <circle cx="151" cy="237" r="58" fill="#9be3f4" fill-opacity=".72"/>
      <circle cx="279" cy="177" r="79" fill="#c5a9f1" fill-opacity=".68"/>
      <circle cx="360" cy="291" r="64" fill="#f6a8c6" fill-opacity=".67"/>
      <circle cx="229" cy="334" r="39" fill="#8bdcc9" fill-opacity=".72"/>
      <path d="M133 218q19-21 40-20M252 145q28-29 56-26M340 267q20-23 39-22" fill="none" stroke="#fff" stroke-width="11" stroke-linecap="round"/>
    </g>`;

  const sceneTablet = () => `
    <g stroke="#111923" stroke-width="7" stroke-linejoin="round">
      <rect x="143" y="112" width="226" height="260" rx="26" fill="#27313d"/>
      <rect x="163" y="139" width="186" height="192" rx="12" fill="#6ec1ee"/>
      <circle cx="256" cy="353" r="9" fill="#9da7b3"/>
      <path d="M198 265l41-56l31 35l28-31l43 52z" fill="#6fb85b" stroke-width="4"/>
      <circle cx="298" cy="185" r="24" fill="#ffd257" stroke-width="4"/>
    </g>`;

  const sceneMusic = () => `
    <g fill="#6d7ce8" stroke="#111923" stroke-width="6" stroke-linejoin="round">
      <path d="M222 117v180q-17-10-38-5q-36 8-31 38q6 31 47 24q41-8 42-49V172l111-25v117q-18-10-39-4q-35 9-29 39q7 31 47 22q40-9 41-50V89z"/>
    </g>`;

  const sceneBreak = () => `
    <g stroke="#111923" stroke-width="5" stroke-linejoin="round">
      <path d="M124 276q0-67 59-67q20-57 82-38q43-54 91 0q54 7 54 67q0 66-82 66H185q-61 0-61-28z" fill="#dbe8f2"/>
      <path d="M176 326h169" stroke="#8b9cab" stroke-width="12"/>
      <path d="M204 354h113" stroke="#a6b3bf" stroke-width="9"/>
    </g>`;

  const sceneHome = () => `
    <g stroke="#111923" stroke-width="6" stroke-linejoin="round">
      <path d="M105 229l151-123l151 123v153H105z" fill="#e6a061"/>
      <path d="M83 235l173-145l173 145" fill="none" stroke="#5e6672" stroke-width="19"/>
      <rect x="221" y="287" width="70" height="95" fill="#8f5c39"/>
      <rect x="137" y="258" width="57" height="55" fill="#bfe3f4"/><rect x="317" y="258" width="57" height="55" fill="#bfe3f4"/>
    </g>`;

  const sceneCar = () => `
    <g stroke="#111923" stroke-width="6" stroke-linejoin="round">
      <path d="M114 284l38-84q10-22 37-22h133q27 0 39 22l38 84v65H114z" fill="#357fce"/>
      <path d="M174 203h164l23 61H151z" fill="#bfe4f6"/>
      <circle cx="172" cy="349" r="34" fill="#2b3035"/><circle cx="342" cy="349" r="34" fill="#2b3035"/>
      <rect x="130" y="287" width="54" height="25" rx="10" fill="#ffd45a"/><rect x="328" y="287" width="54" height="25" rx="10" fill="#ffd45a"/>
    </g>`;

  const sceneWalk = () => `
    <g stroke="#111923" stroke-width="7" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="255" cy="121" r="43" fill="#d99a5a"/>
      <path d="M255 167v113M255 204l-67 64M255 207l67 53M255 280l-54 102M255 280l74 93" fill="none" stroke="#3577b9" stroke-width="24"/>
      <path d="M183 268l-30 24M326 261l34 21" fill="none" stroke="#d99a5a" stroke-width="16"/>
    </g>`;

  const sceneHelp = () => `
    <g stroke="#111923" stroke-width="5" stroke-linejoin="round">
      <path d="M173 336V188q0-22 18-22q18 0 18 22v65V149q0-22 18-22q18 0 18 22v96V139q0-22 18-22q18 0 18 22v111V162q0-21 18-21q18 0 18 21v125q0 93-77 93q-67 0-97-44z" fill="#dda064"/>
      <circle cx="365" cy="145" r="35" fill="#f0c445"/><path d="M365 125v40M345 145h40" stroke-width="8"/>
    </g>`;

  const sceneMore = () => `
    <g stroke="#111923" stroke-width="7" stroke-linejoin="round">
      <circle cx="256" cy="254" r="122" fill="#72c88a"/>
      <path d="M256 176v156M178 254h156" stroke="#fff" stroke-width="34" stroke-linecap="round"/>
    </g>`;

  const sceneHug = () => `
    <g stroke="#111923" stroke-width="5" stroke-linejoin="round">
      <circle cx="204" cy="166" r="43" fill="#d99b5c"/><circle cx="307" cy="166" r="43" fill="#b77c4e"/>
      <path d="M165 217q40-28 81 13l9 113q-86 46-126-25z" fill="#5c8fd9"/>
      <path d="M346 217q-40-28-81 13l-9 113q86 46 126-25z" fill="#67ad65"/>
      <path d="M182 246q75 89 150 0M330 246q-75 89-150 0" fill="none" stroke="#d99b5c" stroke-width="18"/>
    </g>`;

  const scenePerson = () => `
    <g stroke="#111923" stroke-width="5" stroke-linejoin="round">
      <circle cx="256" cy="171" r="68" fill="#d89a5a"/>
      <path d="M190 163q8-80 77-78q61 8 61 80q-45-29-138-2z" fill="#332822"/>
      <path d="M151 380q18-120 105-120q88 0 106 120z" fill="#5d8fd7"/>
      <circle cx="232" cy="173" r="5" fill="#111923"/><circle cx="281" cy="173" r="5" fill="#111923"/>
      <path d="M237 207q20 13 39 0" fill="none"/>
    </g>`;

  const sceneDrawing = () => `
    <g stroke="#111923" stroke-width="5" stroke-linejoin="round">
      <rect x="124" y="118" width="264" height="246" rx="16" fill="#fff"/>
      <path d="M164 308l55-75l48 53l38-40l45 62z" fill="#72b65c"/>
      <circle cx="309" cy="182" r="28" fill="#ffd04d"/>
      <path d="M115 371l188-188l42 42l-188 188z" fill="#ef6c53"/>
      <path d="M115 371l-13 55l55-13z" fill="#f0c8a0"/>
    </g>`;

  const sceneBlocks = () => `
    <g stroke="#111923" stroke-width="5" stroke-linejoin="round">
      <rect x="127" y="256" width="88" height="88" rx="7" fill="#ef4a45"/>
      <rect x="220" y="256" width="88" height="88" rx="7" fill="#3484d8"/>
      <rect x="313" y="256" width="72" height="88" rx="7" fill="#f2ce3b"/>
      <rect x="173" y="163" width="88" height="88" rx="7" fill="#6dbd58"/>
      <rect x="266" y="163" width="88" height="88" rx="7" fill="#ef6f42"/>
      <circle cx="171" cy="300" r="11" fill="#fff"/><circle cx="264" cy="300" r="11" fill="#fff"/><circle cx="349" cy="300" r="11" fill="#fff"/>
    </g>`;

  const sceneBook = () => `
    <g stroke="#111923" stroke-width="6" stroke-linejoin="round">
      <path d="M82 151q88-33 174 28v202q-83-58-174-29z" fill="#5a93da"/>
      <path d="M430 151q-88-33-174 28v202q83-58 174-29z" fill="#74b66a"/>
      <path d="M256 179v202" fill="none"/>
      <path d="M111 203q57-15 113 20M111 245q57-15 113 20M401 203q-57-15-113 20M401 245q-57-15-113 20" fill="none" stroke="#e9f0f5" stroke-width="8"/>
    </g>`;

  const sceneSleep = () => `
    <g stroke="#111923" stroke-width="5" stroke-linejoin="round">
      <rect x="101" y="248" width="310" height="118" rx="18" fill="#6b8fc5"/>
      <rect x="116" y="227" width="113" height="59" rx="20" fill="#f2f4f7"/>
      <path d="M219 250q55-52 124 4q38 30 52 78H180z" fill="#8fb4e1"/>
      <path d="M333 98q-11 87 69 100q-93 21-119-64q-9-30 50-36z" fill="#f2d55b"/>
      <path d="M130 181l12-26l12 26l27 12l-27 12l-12 27l-12-27l-27-12z" fill="#fff4a7"/>
    </g>`;

  const sceneGeneric = () => `
    <g stroke="#111923" stroke-width="6" stroke-linejoin="round">
      <circle cx="256" cy="231" r="113" fill="#8fb6e5"/>
      <path d="M256 139l27 57l62 8l-45 44l12 61l-56-30l-55 30l11-61l-45-44l62-8z" fill="#f3d15b"/>
    </g>`;

  const sceneMarkup = scene => ({
    tableWork:sceneTableWork,
    magnaTiles:sceneMagnaTiles,
    outside:sceneOutside,
    eat:sceneEat,
    play:scenePlay,
    bathroom:sceneBathroom,
    drink:sceneDrink,
    swing:sceneSwing,
    pool:scenePool,
    bubbles:sceneBubbles,
    tablet:sceneTablet,
    music:sceneMusic,
    break:sceneBreak,
    home:sceneHome,
    car:sceneCar,
    walk:sceneWalk,
    help:sceneHelp,
    more:sceneMore,
    hug:sceneHug,
    person:scenePerson,
    drawing:sceneDrawing,
    blocks:sceneBlocks,
    book:sceneBook,
    sleep:sceneSleep,
    generic:sceneGeneric
  }[scene] || sceneGeneric)();

  const makeAutoFirstThenVisual = text => {
    const clean = String(text || "").trim() || "Activity";
    const key = clean.toLowerCase();
    if (autoVisualCache.has(key)) return autoVisualCache.get(key);

    const scene = resolveAutoVisual(clean);
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
      <rect x="10" y="10" width="492" height="492" rx="34" fill="#fff" stroke="#080b0f" stroke-width="11"/>
      <g transform="translate(0,12)">${sceneMarkup(scene)}</g>
      <rect x="35" y="404" width="442" height="76" rx="20" fill="#fff"/>
      <text x="256" y="454" text-anchor="middle" dominant-baseline="middle"
        font-family="Arial Rounded MT Bold, Arial, sans-serif" font-size="42"
        font-weight="800" fill="#05070a">${svgEsc(clean.slice(0, 26))}</text>
    </svg>`;

    const url = "data:image/svg+xml;charset=utf-8," + encodeURIComponent(svg);
    autoVisualCache.set(key, url);
    return url;
  };

  const firstThenModeFor = side => side === "first" ? state.firstMode : state.thenMode;
  const firstThenSavedIdFor = side => side === "first" ? state.firstIconId : state.thenIconId;
  const firstThenTextFor = side => {
    const field = document.getElementById(side === "first" ? "firstThenFirst" : "firstThenThen");
    return String(field?.value || field?.placeholder || (side === "first" ? "Table work" : "Outside")).trim();
  };

  const firstThenVisualFor = side => {
    const mode = firstThenModeFor(side);
    if (mode === "text") return null;
    if (mode === "saved") return getIcon(firstThenSavedIdFor(side))?.dataURL || null;
    return makeAutoFirstThenVisual(firstThenTextFor(side));
  };

  const ensureFirstThenVisualSlots = overlay => {
    ["First", "Then"].forEach(side => {
      const panel = overlay.querySelector(side === "First" ? ".firstPanel" : ".thenPanel");
      const value = overlay.querySelector(`#firstThen${side}Value`);
      if (!panel || !value) return;
      let img = panel.querySelector(".firstThenVisualImage");
      if (!img) {
        img = document.createElement("img");
        img.className = "firstThenVisualImage";
        img.alt = "";
        img.hidden = true;
        panel.insertBefore(img, value);
      }
    });
  };

  const applyFirstThenVisuals = () => {
    const overlay = document.getElementById("firstThenOverlay");
    if (!overlay) return;
    ensureFirstThenVisualSlots(overlay);
    const pairs = [
      ["first", ".firstPanel"],
      ["then", ".thenPanel"]
    ];
    pairs.forEach(([side, selector]) => {
      const panel = overlay.querySelector(selector);
      const img = panel?.querySelector(".firstThenVisualImage");
      const visual = firstThenVisualFor(side);
      if (!panel || !img) return;
      if (visual) {
        img.src = visual;
        img.alt = firstThenTextFor(side);
        img.hidden = false;
        panel.classList.add("visualReady");
        panel.setAttribute("aria-label", firstThenTextFor(side));
      } else {
        img.hidden = true;
        img.removeAttribute("src");
        panel.classList.remove("visualReady");
        panel.removeAttribute("aria-label");
      }
    });
  };

  const ensureChoiceOverlay = () => {
    let overlay = document.getElementById("choiceBoardOverlay");
    if (overlay) return overlay;
    overlay = document.createElement("div");
    overlay.id = "choiceBoardOverlay";
    overlay.className = "choiceBoardOverlay";
    overlay.innerHTML = `
      <div class="choiceBoardTop"><button id="closeChoiceBoard" type="button">Close</button><div class="tiny">VISUAL CHOICE BOARD</div><div style="width:64px"></div></div>
      <div class="choiceBoardTitle" id="choiceBoardOverlayTitle">Choices</div>
      <div class="choiceBoardGrid" id="choiceBoardGrid"></div>
    `;
    document.body.appendChild(overlay);
    overlay.querySelector("#closeChoiceBoard").onclick = () => overlay.classList.remove("show");
    return overlay;
  };

  const selectedBoardIcons = () => state.boardSelection.map(getIcon).filter(Boolean);

  const showChoiceBoard = () => {
    const overlay = ensureChoiceOverlay();
    const title = String(document.getElementById("choiceBoardTitle")?.value || "Choices").trim() || "Choices";
    const columns = Number(document.getElementById("choiceBoardLayout")?.value || 2);
    const items = selectedBoardIcons();
    overlay.querySelector("#choiceBoardOverlayTitle").textContent = title;
    const grid = overlay.querySelector("#choiceBoardGrid");
    grid.style.setProperty("--choice-columns", String(columns));
    grid.innerHTML = items.length ? items.map(item => `
      <div class="choiceBoardCell"><img src="${item.dataURL}" alt="${safe(item.label)}"><b>${safe(item.label)}</b></div>
    `).join("") : '<div class="choiceBoardEmpty">Choose at least one saved icon first.</div>';
    overlay.classList.add("show");
  };

  const imageFromURL = src => new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = reject;
    img.src = src;
  });

  const exportBoard = async () => {
    const items = selectedBoardIcons();
    if (!items.length) {
      alert("Choose at least one icon first.");
      return;
    }
    const columns = Number(document.getElementById("choiceBoardLayout")?.value || 2);
    const rows = Math.ceil(items.length / columns);
    const cell = columns === 2 ? 500 : 340;
    const gap = 22;
    const margin = 40;
    const header = 110;
    const width = columns * cell + (columns - 1) * gap + margin * 2;
    const height = header + rows * cell + (rows - 1) * gap + margin * 2;
    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext("2d");
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, width, height);
    ctx.fillStyle = "#101820";
    ctx.font = "900 54px -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(String(document.getElementById("choiceBoardTitle")?.value || "Choices"), width / 2, 76);

    const images = await Promise.all(items.map(item => imageFromURL(item.dataURL)));
    items.forEach((item, index) => {
      const col = index % columns;
      const row = Math.floor(index / columns);
      const x = margin + col * (cell + gap);
      const y = margin + header + row * (cell + gap);
      ctx.strokeStyle = "#152235";
      ctx.lineWidth = 4;
      ctx.strokeRect(x, y, cell, cell);
      const img = images[index];
      const pad = 18;
      const imageSize = cell - pad * 2 - 72;
      ctx.drawImage(img, x + pad, y + pad, imageSize, imageSize);
      ctx.fillStyle = "#101820";
      ctx.font = `900 ${columns === 2 ? 36 : 26}px -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif`;
      ctx.textAlign = "center";
      ctx.fillText(item.label, x + cell / 2, y + cell - 26, cell - 30);
    });

    const url = canvas.toDataURL("image/jpeg", .94);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = "LifeRoute-Choice-Board.jpg";
    document.body.appendChild(anchor);
    anchor.click();
    anchor.remove();
    if (typeof setStatus === "function") setStatus("Choice board image created");
  };

  const bind = () => {
    const camera = document.getElementById("visualCameraInput");
    document.getElementById("visualCameraButton")?.addEventListener("click", () => camera?.click());
    camera?.addEventListener("change", () => chooseDraft(camera.files?.[0]));
    document.getElementById("visualIconLabel")?.addEventListener("input", () => {
      if (!draftFile) return;
      clearTimeout(labelDebounce);
      labelDebounce = setTimeout(generateDraftVisual, 220);
    });
    document.getElementById("createVisualIcon")?.addEventListener("click", createIcon);

    document.getElementById("firstThenFirstMode")?.addEventListener("change", event => {
      state.firstMode = event.target.value;
      save();
      renderIconSelectors();
      applyFirstThenVisuals();
    });
    document.getElementById("firstThenThenMode")?.addEventListener("change", event => {
      state.thenMode = event.target.value;
      save();
      renderIconSelectors();
      applyFirstThenVisuals();
    });
    document.getElementById("firstThenFirstIcon")?.addEventListener("change", event => {
      state.firstIconId = event.target.value;
      save();
      applyFirstThenVisuals();
    });
    document.getElementById("firstThenThenIcon")?.addEventListener("change", event => {
      state.thenIconId = event.target.value;
      save();
      applyFirstThenVisuals();
    });

    ["firstThenFirst","firstThenThen"].forEach(id => {
      document.getElementById(id)?.addEventListener("input", () => {
        if ((id === "firstThenFirst" ? state.firstMode : state.thenMode) === "auto") {
          applyFirstThenVisuals();
        }
      });
    });

    // Existing First/Then code builds and opens the overlay first; this listener
    // adds the selected visuals immediately afterward.
    document.getElementById("showFirstThen")?.addEventListener("click", () => {
      setTimeout(applyFirstThenVisuals, 0);
    });

    document.getElementById("choiceBoardLayout")?.addEventListener("change", () => {
      const max = Number(document.getElementById("choiceBoardLayout")?.value || 2) === 3 ? 9 : 8;
      state.boardSelection = state.boardSelection.slice(0, max);
      save();
      renderLibraries();
    });
    document.getElementById("showChoiceBoard")?.addEventListener("click", showChoiceBoard);
    document.getElementById("exportChoiceBoard")?.addEventListener("click", exportBoard);
    document.getElementById("clearChoiceBoard")?.addEventListener("click", () => {
      state.boardSelection = [];
      save();
      renderLibraries();
    });
  };

  const start = () => {
    if (!ensureTools()) {
      setTimeout(start, 60);
      return;
    }
    bind();
    renderAllVisual();
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start, { once: true });
  } else {
    start();
  }
})();