// LifeRoute visual-support tools: automatic camera icon styling, visual First/Then, and choice boards.
// Images stay on-device/in-browser in localStorage. No upload service is used.
(() => {
  const STORE = "liferoute_visual_tools_v2";
  const LEGACY_STORE = "liferoute_" + "pe" + "cs_tools_v1";
  const MAX_ICONS = 18;
  let state = {
    icons: [],
    firstIconId: "",
    thenIconId: "",
    firstThenVisual: true,
    boardSelection: []
  };

  try {
    const saved = JSON.parse(localStorage.getItem(STORE) || localStorage.getItem(LEGACY_STORE) || "{}");
    state.icons = Array.isArray(saved.icons) ? saved.icons : [];
    state.firstIconId = String(saved.firstIconId || "");
    state.thenIconId = String(saved.thenIconId || "");
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
      <div class="toolHead"><div class="toolIcon">▦</div><div class="grow"><div class="title">Choice board creator</div><div class="meta">Build a visual board from your saved Visual support icons. Default layout matches an 8-choice, 2 × 4 board.</div></div></div>
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
          <div class="row"><div><b>Visual option</b><div class="tiny">Add visual support icons above the words.</div></div><label class="switch"><input id="firstThenVisualToggle" type="checkbox" checked><span class="slider"></span></label></div>
          <div class="grid2 visualFirstThenSelects">
            <div><label>First visual</label><select id="firstThenFirstIcon"></select></div>
            <div><label>Then visual</label><select id="firstThenThenIcon"></select></div>
          </div>
          <div class="tiny">Create or photograph new visuals in Visual support icon maker, then select them here.</div>
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
    .visualCaptureLayout{display:grid;grid-template-columns:150px 1fr;gap:9px;margin-bottom:9px}.visualCameraTile{min-height:145px;border:1px dashed color-mix(in srgb,var(--blue) 44%,var(--line));background:color-mix(in srgb,var(--blue) 5%,var(--panel2));color:var(--text);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:3px}.visualCameraTile span{font-size:9px;color:var(--muted)}.visualCameraGlyph{font-size:28px;color:var(--blue);margin-bottom:4px}.visualDraftCard{min-height:145px;border-radius:14px;border:1px solid var(--line);background:#fff;overflow:hidden;display:grid;place-items:center}.visualDraftCard img{width:100%;height:145px;object-fit:cover}.visualDraftCard #visualDraftEmpty{color:#243348;text-align:center;padding:18px;display:grid;gap:4px}.visualDraftCard #visualDraftEmpty span{font-size:9px;color:#66768b;line-height:1.4}.visualLabelRow{margin-top:8px}.visualLibraryHead{display:flex;justify-content:space-between;align-items:center;margin:12px 0 7px}.visualIconLibrary,.choiceBoardPicker{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:7px}.visualLibraryItem,.choicePick{position:relative;border:1px solid var(--line);border-radius:12px;padding:6px;background:color-mix(in srgb,var(--panel2) 76%,transparent);text-align:center;color:var(--text);overflow:hidden}.visualLibraryItem img,.choicePick img{width:100%;aspect-ratio:1;object-fit:cover;border-radius:8px;background:white}.visualLibraryItem b,.choicePick b{display:block;font-size:9px;margin-top:4px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.visualDelete{position:absolute;right:3px;top:3px;width:24px;height:24px;padding:0;border-radius:999px;background:rgba(8,15,26,.82);color:white;font-size:13px}.choicePick.selected{border-color:var(--gold);box-shadow:inset 0 0 0 1px var(--gold);background:color-mix(in srgb,var(--gold) 8%,var(--panel2))}.choicePick.selected:after{content:"✓";position:absolute;top:5px;right:5px;width:21px;height:21px;border-radius:999px;display:grid;place-items:center;background:var(--gold);color:var(--bg);font-size:11px;font-weight:950}.visualFirstThenControls{margin-top:10px;padding-top:10px;border-top:1px solid var(--line)}.visualFirstThenSelects{margin-top:8px}
    .firstThenVisualImage{width:min(42vw,330px);max-height:42vh;object-fit:contain;border-radius:22px;background:white;border:6px solid white;box-shadow:0 16px 48px rgba(0,0,0,.18);margin-bottom:18px}.firstThenPanel.visualReady .firstThenValue{font-size:clamp(24px,5vw,48px)}
    .choiceBoardOverlay{position:fixed;inset:0;z-index:12500;display:none;background:#f8fafc;color:#10213a;padding:calc(12px + env(safe-area-inset-top)) 14px calc(14px + env(safe-area-inset-bottom));overflow:auto}.choiceBoardOverlay.show{display:block}.choiceBoardTop{max-width:900px;margin:0 auto 12px;display:flex;justify-content:space-between;align-items:center}.choiceBoardTop button{background:#e9eff7;color:#10213a}.choiceBoardTitle{font-size:clamp(24px,5vw,42px);font-weight:950;text-align:center;margin:5px 0 18px}.choiceBoardGrid{--choice-columns:2;max-width:900px;margin:auto;display:grid;grid-template-columns:repeat(var(--choice-columns),minmax(0,1fr));gap:12px}.choiceBoardCell{min-height:190px;background:white;border:3px solid #10213a;border-radius:20px;padding:10px;display:flex;flex-direction:column;align-items:center;justify-content:center;box-shadow:0 10px 28px rgba(16,33,58,.08)}.choiceBoardCell img{width:100%;max-height:260px;aspect-ratio:1;object-fit:contain}.choiceBoardCell b{font:900 clamp(18px,4vw,32px)/1.05 system-ui,-apple-system,sans-serif;margin-top:8px;text-align:center}.choiceBoardEmpty{grid-column:1/-1;text-align:center;color:#66768b;padding:30px}
    @media(max-width:680px){.visualCaptureLayout{grid-template-columns:115px 1fr}.visualCameraTile,.visualDraftCard{min-height:118px}.visualDraftCard img{height:118px}.visualIconLibrary,.choiceBoardPicker{grid-template-columns:repeat(3,minmax(0,1fr))}.choiceBoardCell{min-height:150px;border-width:2px;border-radius:16px;padding:8px}.firstThenVisualImage{width:min(70vw,300px);max-height:27vh;margin-bottom:10px}}
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
    const toggle = document.getElementById("firstThenVisualToggle");
    if (toggle) toggle.checked = !!state.firstThenVisual;
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
      if (typeof setStatus === "function") setStatus(`${label} Visual support icon created`);
    } catch (_) {
      alert("LifeRoute could not process that photo. Try another image.");
    } finally {
      if (button) {
        button.disabled = false;
        button.textContent = "Save visual";
      }
    }
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
      [".firstPanel", state.firstIconId],
      [".thenPanel", state.thenIconId]
    ];
    pairs.forEach(([selector, id]) => {
      const panel = overlay.querySelector(selector);
      const img = panel?.querySelector(".firstThenVisualImage");
      const item = state.firstThenVisual ? getIcon(id) : null;
      if (!panel || !img) return;
      if (item) {
        img.src = item.dataURL;
        img.alt = item.label;
        img.hidden = false;
        panel.classList.add("visualReady");
      } else {
        img.hidden = true;
        img.removeAttribute("src");
        panel.classList.remove("visualReady");
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

    document.getElementById("firstThenVisualToggle")?.addEventListener("change", event => {
      state.firstThenVisual = !!event.target.checked;
      save();
      applyFirstThenVisuals();
    });
    document.getElementById("firstThenFirstIcon")?.addEventListener("change", event => {
      state.firstIconId = event.target.value;
      save();
    });
    document.getElementById("firstThenThenIcon")?.addEventListener("change", event => {
      state.thenIconId = event.target.value;
      save();
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