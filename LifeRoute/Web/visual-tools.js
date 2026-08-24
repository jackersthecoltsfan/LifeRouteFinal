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
  // Concrete visual scene generator. The goal is immediate child recognition:
  // show the actual person, object, place, or action — not a symbol standing in
  // for it. Cards use LifeRoute's established white background, black rounded
  // border, bold outlines, bright natural colors, and one readable label.
  const AUTO_VISUALS = [
    { terms:["table work","work","worksheet","desk","school work","learning"], scene:"work" },
    { terms:["magna tiles","magna-tiles","magnet tiles","magnetic tiles"], scene:"magnaTiles" },
    { terms:["outside","outdoors","play outside","yard","park","playground"], scene:"outside" },
    { terms:["eat","food","snack","lunch","dinner","breakfast","meal"], scene:"eat" },
    { terms:["play","toy","toys","free play"], scene:"play" },
    { terms:["bathroom","toilet","potty"], scene:"bathroom" },
    { terms:["drink","water","juice"], scene:"drink" },
    { terms:["swing","swinging"], scene:"swing" },
    { terms:["pool","swim","swimming","water play"], scene:"pool" },
    { terms:["bubbles","bubble"], scene:"bubbles" },
    { terms:["ipad","tablet","phone","screen"], scene:"tablet" },
    { terms:["music","song","sing","singing"], scene:"music" },
    { terms:["break","rest","calm","quiet","relax"], scene:"break" },
    { terms:["home","go home","house"], scene:"home" },
    { terms:["car","drive","ride","car ride"], scene:"car" },
    { terms:["walk","walking","go for a walk"], scene:"walk" },
    { terms:["help","ask for help"], scene:"help" },
    { terms:["more","more please"], scene:"more" },
    { terms:["hug","hugs"], scene:"hug" },
    { terms:["mom","mother","mommy"], scene:"mom" },
    { terms:["dad","father","daddy"], scene:"dad" },
    { terms:["grandma","grandmother","vovo","vovó"], scene:"grandma" },
    { terms:["draw","drawing","color","coloring","art"], scene:"drawing" },
    { terms:["blocks","lego","legos","building"], scene:"blocks" },
    { terms:["book","read","reading","story"], scene:"book" },
    { terms:["sleep","nap","bed","bedtime"], scene:"sleep" }
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

  // Reusable illustrated child. The details are deliberate: face, eyes, hair,
  // clothing, hands and shoes remain visible at card size.
  const child = ({x=250,y=160,shirt="#4e9e42",pants="#2d6fa8",skin="#d99a5c",hair="#252525",scale=1,pose="sit"}={}) => {
    const s = scale;
    const tx = x - 250*s;
    const ty = y - 160*s;
    const body = pose === "kneel"
      ? `<path d="M231 255q-8 60-48 82M286 255q12 57 56 75" fill="none" stroke="${pants}" stroke-width="27" stroke-linecap="round"/>
         <path d="M178 337h52M324 330h50" stroke="#1f252b" stroke-width="18" stroke-linecap="round"/>`
      : pose === "stand"
      ? `<path d="M231 255v92M286 255v92" fill="none" stroke="${pants}" stroke-width="27" stroke-linecap="round"/>
         <path d="M211 348h49M275 348h49" stroke="#1f252b" stroke-width="18" stroke-linecap="round"/>`
      : `<path d="M231 255q6 54-22 89M286 255q10 46 45 76" fill="none" stroke="${pants}" stroke-width="27" stroke-linecap="round"/>
         <path d="M192 345h50M318 333h48" stroke="#1f252b" stroke-width="18" stroke-linecap="round"/>`;

    return `<g transform="translate(${tx} ${ty}) scale(${s})" stroke="#111923" stroke-linejoin="round" stroke-linecap="round">
      <circle cx="253" cy="139" r="44" fill="${skin}" stroke-width="5"/>
      <path d="M211 139q2-51 46-54q48 3 42 57q-12-17-28-22q-24 20-60 19z" fill="${hair}" stroke-width="5"/>
      <circle cx="237" cy="143" r="4.5" fill="#111923" stroke="none"/>
      <circle cx="270" cy="143" r="4.5" fill="#111923" stroke="none"/>
      <path d="M241 164q12 9 25 0" fill="none" stroke-width="4"/>
      <path d="M218 190q35-21 71 0l17 70h-105z" fill="${shirt}" stroke-width="5"/>
      <path d="M220 204q-25 18-39 53M286 204q25 17 40 52" fill="none" stroke="${skin}" stroke-width="17"/>
      <circle cx="179" cy="260" r="9" fill="${skin}" stroke-width="4"/>
      <circle cx="328" cy="259" r="9" fill="${skin}" stroke-width="4"/>
      ${body}
    </g>`;
  };

  const adult = ({x=250,y=165,shirt="#6c8fd1",skin="#b9784f",hair="#2b2421",scale=.92,kind="adult"}={}) => `
    <g transform="translate(${x-250*scale} ${y-165*scale}) scale(${scale})" stroke="#111923" stroke-linejoin="round" stroke-linecap="round">
      <circle cx="250" cy="137" r="48" fill="${skin}" stroke-width="5"/>
      <path d="M203 137q4-57 49-59q50 6 45 63q-40-25-94-4z" fill="${hair}" stroke-width="5"/>
      <circle cx="233" cy="141" r="5" fill="#111923" stroke="none"/><circle cx="269" cy="141" r="5" fill="#111923" stroke="none"/>
      <path d="M236 166q15 10 29 0" fill="none" stroke-width="4"/>
      <path d="M184 361q17-154 66-154q50 0 67 154z" fill="${shirt}" stroke-width="5"/>
    </g>`;

  const workScene = () => `
    <g>
      <rect x="340" y="185" width="82" height="145" rx="18" fill="#2174c9" stroke="#111923" stroke-width="6"/>
      ${child({x:296,y:155,scale:.92,pose:"sit"})}
      <ellipse cx="252" cy="304" rx="176" ry="66" fill="#1975cf" stroke="#111923" stroke-width="6"/>
      <path d="M128 337v73M376 337v73" stroke="#1366b5" stroke-width="22" stroke-linecap="round"/>
      <rect x="113" y="226" width="83" height="64" rx="9" fill="#1573c8" stroke="#111923" stroke-width="5"/>
      <path d="M126 225h56v-30h-56z" fill="#fff" stroke="#111923" stroke-width="4"/>
      <circle cx="154" cy="211" r="10" fill="#ef433e" stroke="#111923" stroke-width="3"/>
      <g stroke="#111923" stroke-width="4">
        <rect x="170" y="270" width="54" height="43" rx="6" fill="#fff"/><path d="M185 298l12-18l12 18z" fill="#f4cc3c"/>
        <rect x="230" y="266" width="54" height="43" rx="6" fill="#fff"/><rect x="244" y="278" width="26" height="17" rx="5" fill="#56a36b"/>
        <rect x="290" y="268" width="54" height="43" rx="6" fill="#fff"/><circle cx="317" cy="289" r="10" fill="#ef4a47"/>
      </g>
      <path d="M226 330h105" stroke="#fff" stroke-width="5" opacity=".55"/>
      <path d="M270 251l-30 30" stroke="#d99a5c" stroke-width="15" stroke-linecap="round"/>
    </g>`;

  const magnaTilesScene = () => `
    <g stroke="#111923" stroke-width="5" stroke-linejoin="round">
      <rect x="119" y="235" width="79" height="79" rx="7" fill="#ef3934"/>
      <rect x="203" y="235" width="79" height="79" rx="7" fill="#ef3934"/>
      <rect x="287" y="235" width="79" height="79" rx="7" fill="#ef3934"/>
      <rect x="161" y="151" width="79" height="79" rx="7" fill="#ef3934"/>
      <rect x="245" y="151" width="79" height="79" rx="7" fill="#ef3934"/>
      <path d="M161 146l40-76l39 76z" fill="#63cb30"/>
      <path d="M245 146l39-66l40 66z" fill="#2d92ec"/>
      <path d="M119 230l40-68l37 68zM329 230l38-68l39 68z" fill="#ffd32f"/>
      <g fill="#fff" stroke-width="3">
        <circle cx="131" cy="247" r="7"/><circle cx="186" cy="247" r="7"/><circle cx="131" cy="302" r="7"/><circle cx="186" cy="302" r="7"/>
        <circle cx="215" cy="247" r="7"/><circle cx="270" cy="247" r="7"/><circle cx="299" cy="247" r="7"/><circle cx="354" cy="247" r="7"/>
      </g>
      ${child({x:365,y:210,scale:.52,pose:"kneel"})}
    </g>`;

  const outsideScene = () => `
    <g stroke="#111923" stroke-linejoin="round">
      <rect x="54" y="68" width="404" height="274" rx="22" fill="#72c9f4" stroke-width="5"/>
      <path d="M54 214h404v128H54z" fill="#78bd57" stroke="none"/>
      <rect x="68" y="173" width="122" height="70" fill="#bd6044" stroke-width="4"/><path d="M62 173l67-54l67 54z" fill="#5d6269" stroke-width="4"/>
      <rect x="91" y="194" width="24" height="49" fill="#fff" stroke-width="3"/><rect x="143" y="191" width="31" height="26" fill="#c6e8f6" stroke-width="3"/>
      <path d="M277 223v-100" stroke="#6d472d" stroke-width="18"/><circle cx="278" cy="112" r="78" fill="#4c9d3d" stroke-width="5"/>
      <path d="M57 266h398" stroke="#33393f" stroke-width="6"/><path d="M80 235v101M126 235v101M172 235v101M218 235v101M264 235v101M310 235v101M356 235v101M402 235v101" stroke="#33393f" stroke-width="3"/>
      <path d="M331 257h65l-7 43h-51z" fill="#1f629e" stroke-width="4"/><path d="M345 257v-29h36v29" fill="none" stroke-width="4"/>
      ${child({x:205,y:222,scale:.52,pose:"stand",shirt:"#ef7d3c",pants:"#3678b8"})}
      <circle cx="144" cy="288" r="24" fill="#ffd24f" stroke-width="4"/>
    </g>`;

  const eatScene = () => `
    <g>
      <rect x="348" y="181" width="76" height="143" rx="18" fill="#2376ca" stroke="#111923" stroke-width="6"/>
      ${child({x:300,y:155,scale:.88,pose:"sit",shirt:"#5b9f43"})}
      <ellipse cx="251" cy="303" rx="170" ry="62" fill="#1974ca" stroke="#111923" stroke-width="6"/>
      <circle cx="239" cy="298" r="59" fill="#fff" stroke="#111923" stroke-width="5"/>
      <path d="M208 299h61" stroke="#e5b566" stroke-width="16" stroke-linecap="round"/><circle cx="222" cy="279" r="15" fill="#ef4d45" stroke="#111923" stroke-width="3"/>
      <path d="M272 277l30-20" stroke="#5fa544" stroke-width="9" stroke-linecap="round"/>
      <rect x="119" y="247" width="52" height="75" rx="10" fill="#76c7ed" stroke="#111923" stroke-width="4"/>
      <path d="M132 247l28-38" stroke="#ef6360" stroke-width="8" stroke-linecap="round"/>
      <path d="M270 248q-20 19-31 42" stroke="#d99a5c" stroke-width="15" stroke-linecap="round"/>
    </g>`;

  const playScene = () => `
    <g stroke="#111923" stroke-linejoin="round">
      <ellipse cx="254" cy="343" rx="171" ry="50" fill="#cde6f6" stroke-width="5"/>
      ${child({x:256,y:143,scale:.78,pose:"kneel",shirt:"#f08c3f",pants:"#3275b5"})}
      <rect x="118" y="295" width="61" height="58" rx="7" fill="#ef4943" stroke-width="5"/>
      <rect x="184" y="306" width="55" height="47" rx="7" fill="#327dd0" stroke-width="5"/>
      <rect x="244" y="287" width="63" height="66" rx="7" fill="#f1cd32" stroke-width="5"/>
      <path d="M310 329h84l-14 24h-65z" fill="#58a761" stroke-width="5"/>
      <circle cx="330" cy="354" r="12" fill="#222a30" stroke-width="4"/><circle cx="371" cy="354" r="12" fill="#222a30" stroke-width="4"/>
      <circle cx="105" cy="269" r="29" fill="#f2c940" stroke-width="5"/><path d="M84 269h42M105 248v42" stroke="#fff" stroke-width="5"/>
      <path d="M205 246q20 26 34 57" stroke="#d99a5c" stroke-width="15" stroke-linecap="round"/>
    </g>`;

  const bathroomScene = () => `
    <g stroke="#111923" stroke-width="5" stroke-linejoin="round">
      <rect x="88" y="86" width="141" height="110" rx="12" fill="#d9eef8"/><rect x="110" y="108" width="97" height="66" rx="8" fill="#fff"/>
      <rect x="300" y="104" width="112" height="43" rx="14" fill="#e9eef2"/>
      <path d="M315 148h82v77q0 58-41 58t-41-58z" fill="#fff"/>
      <ellipse cx="356" cy="209" rx="34" ry="19" fill="#c8e6f3"/>
      <path d="M102 260h126q8 0 8 8v38H94v-38q0-8 8-8z" fill="#eef3f5"/><path d="M165 260v-57" stroke="#8ca2ae" stroke-width="9"/><path d="M140 211q25-22 50 0" fill="none" stroke="#8ca2ae" stroke-width="8"/>
      <rect x="104" y="306" width="123" height="24" rx="10" fill="#b6c5cc"/>
      <rect x="317" y="278" width="78" height="21" rx="9" fill="#d7e1e6"/>
      <circle cx="398" cy="126" r="6" fill="#8798a3"/>
    </g>`;

  const drinkScene = () => `
    <g>
      ${child({x:257,y:153,scale:.9,pose:"stand",shirt:"#4e9f48"})}
      <path d="M310 212q25-9 39 6" fill="none" stroke="#d99a5c" stroke-width="17" stroke-linecap="round"/>
      <path d="M332 193h54l-8 86q-2 19-19 19q-18 0-20-19z" fill="#79c8ec" stroke="#111923" stroke-width="5"/>
      <path d="M364 194l24-42" stroke="#ed5d59" stroke-width="8" stroke-linecap="round"/>
      <ellipse cx="359" cy="194" rx="27" ry="8" fill="#d9f4ff" stroke="#111923" stroke-width="4"/>
    </g>`;

  const swingScene = () => `
    <g stroke="#111923" stroke-linejoin="round">
      <path d="M103 389l96-285M409 389l-96-285M163 214h185" fill="none" stroke="#31638f" stroke-width="18"/>
      <path d="M220 214v89M291 214v89" fill="none" stroke="#535c63" stroke-width="5"/>
      <path d="M209 303h95l-10 38h-75z" fill="#efbd39" stroke-width="5"/>
      ${child({x:257,y:182,scale:.52,pose:"sit",shirt:"#ef7e3d",pants:"#3a77b3"})}
    </g>`;

  const poolScene = () => `
    <g stroke="#111923" stroke-linejoin="round">
      <rect x="70" y="168" width="372" height="207" rx="28" fill="#55b9ec" stroke-width="5"/>
      <path d="M70 230q62-25 124 0q62 25 124 0q62-25 124 0M70 282q62-25 124 0q62 25 124 0q62-25 124 0" fill="none" stroke="#e9fbff" stroke-width="10"/>
      <path d="M103 146v177M103 170h58M161 146v177" fill="none" stroke="#f5f6f7" stroke-width="12"/>
      <circle cx="306" cy="202" r="39" fill="#d99a5c" stroke-width="5"/>
      <path d="M274 191q10-42 45-43q35 6 30 45q-38-18-75-2z" fill="#292929" stroke-width="5"/>
      <path d="M253 264q51-54 105 0" fill="none" stroke="#ed5c4f" stroke-width="27"/>
      <circle cx="307" cy="270" r="58" fill="none" stroke="#ffd140" stroke-width="19"/>
    </g>`;

  const bubblesScene = () => `
    <g stroke="#111923" stroke-linejoin="round">
      ${child({x:207,y:176,scale:.64,pose:"stand",shirt:"#5aa052"})}
      <path d="M252 220l52-38" stroke="#d99a5c" stroke-width="15" stroke-linecap="round"/>
      <circle cx="321" cy="167" r="18" fill="none" stroke="#8a9da8" stroke-width="5"/><path d="M305 183l-20 49" stroke="#8a9da8" stroke-width="6"/>
      <circle cx="355" cy="133" r="31" fill="#a9e4f4" fill-opacity=".62" stroke-width="4"/><circle cx="406" cy="195" r="43" fill="#c6aaf0" fill-opacity=".55" stroke-width="4"/><circle cx="342" cy="254" r="28" fill="#f5adca" fill-opacity=".58" stroke-width="4"/>
      <path d="M344 121q8-8 17-7M392 178q11-12 23-10M331 244q8-7 14-6" fill="none" stroke="#fff" stroke-width="7" stroke-linecap="round"/>
    </g>`;

  const tabletScene = () => `
    <g>
      ${child({x:256,y:146,scale:.78,pose:"sit",shirt:"#4d9c46"})}
      <rect x="181" y="248" width="150" height="113" rx="15" fill="#242d36" stroke="#111923" stroke-width="6"/>
      <rect x="195" y="261" width="122" height="82" rx="8" fill="#72c4eb"/>
      <path d="M174 286q21 12 30 20M338 286q-20 12-29 20" stroke="#d99a5c" stroke-width="15" stroke-linecap="round"/>
      <circle cx="256" cy="352" r="6" fill="#a6b0b8"/>
    </g>`;

  const musicScene = () => `
    <g stroke="#111923" stroke-linejoin="round">
      ${child({x:248,y:163,scale:.7,pose:"stand",shirt:"#8a67c7"})}
      <path d="M180 151q5-75 73-75q69 0 76 75" fill="none" stroke="#3d4651" stroke-width="15"/>
      <rect x="169" y="137" width="24" height="69" rx="11" fill="#4d5966" stroke-width="4"/><rect x="315" y="137" width="24" height="69" rx="11" fill="#4d5966" stroke-width="4"/>
      <path d="M360 111v104q-16-10-31-4q-25 10-17 31q8 21 33 10q20-9 20-39v-61l55-13v65q-15-8-28-2q-22 10-14 30q8 19 31 8q19-9 19-38v-112z" fill="#5a78df" stroke-width="5"/>
    </g>`;

  const breakScene = () => `
    <g stroke="#111923" stroke-linejoin="round">
      <ellipse cx="257" cy="327" rx="153" ry="73" fill="#8fb0c8" stroke-width="5"/>
      <path d="M128 329q14-103 128-103q115 0 131 103z" fill="#a9c4d8" stroke-width="5"/>
      ${child({x:256,y:154,scale:.68,pose:"sit",shirt:"#5f97c7",pants:"#4a6786"})}
      <path d="M205 313q50 30 102 0" fill="none" stroke="#d99a5c" stroke-width="14" stroke-linecap="round"/>
      <path d="M352 141q-7 58 48 66q-61 13-76-43q-6-21 28-23z" fill="#f1d459" stroke-width="4"/>
    </g>`;

  const homeScene = () => `
    <g stroke="#111923" stroke-linejoin="round">
      <path d="M108 227l148-121l148 121v151H108z" fill="#e6a061" stroke-width="6"/>
      <path d="M85 234l171-144l171 144" fill="none" stroke="#5e6672" stroke-width="19"/>
      <rect x="222" y="286" width="69" height="92" fill="#8f5c39" stroke-width="5"/>
      <circle cx="278" cy="333" r="6" fill="#f5d064" stroke-width="3"/>
      <rect x="139" y="257" width="58" height="54" fill="#bee4f4" stroke-width="5"/><path d="M168 257v54M139 284h58" stroke-width="3"/>
      <rect x="316" y="257" width="58" height="54" fill="#bee4f4" stroke-width="5"/><path d="M345 257v54M316 284h58" stroke-width="3"/>
      <path d="M104 379h306" stroke="#75b35b" stroke-width="18"/>
    </g>`;

  const carScene = () => `
    <g stroke="#111923" stroke-linejoin="round">
      <path d="M98 292l42-93q11-24 42-24h145q29 0 42 24l45 93v70H98z" fill="#357fce" stroke-width="6"/>
      <path d="M164 199h183l27 67H134z" fill="#bfe4f6" stroke-width="5"/>
      <path d="M254 199v67" stroke-width="4"/>
      <circle cx="165" cy="361" r="37" fill="#282f35" stroke-width="6"/><circle cx="165" cy="361" r="16" fill="#a6afb5" stroke-width="4"/>
      <circle cx="347" cy="361" r="37" fill="#282f35" stroke-width="6"/><circle cx="347" cy="361" r="16" fill="#a6afb5" stroke-width="4"/>
      <rect x="118" y="294" width="58" height="28" rx="10" fill="#ffd457" stroke-width="4"/><rect x="339" y="294" width="58" height="28" rx="10" fill="#ffd457" stroke-width="4"/>
      <rect x="217" y="292" width="78" height="35" rx="8" fill="#e9eff4" stroke-width="4"/>
    </g>`;

  const walkScene = () => `
    <g stroke="#111923" stroke-linejoin="round">
      <path d="M65 368q115-79 220-31q87 41 163 3" fill="none" stroke="#d6d1bf" stroke-width="56" stroke-linecap="round"/>
      <path d="M68 368q114-79 219-31q86 41 160 3" fill="none" stroke="#a8a38f" stroke-width="4" stroke-dasharray="15 15"/>
      ${child({x:249,y:143,scale:.82,pose:"stand",shirt:"#ed8242",pants:"#3778b5"})}
      <path d="M190 328l-55 42M322 330l54 35" stroke="#2a3037" stroke-width="13" stroke-linecap="round"/>
      <circle cx="404" cy="192" r="45" fill="#5ca748" stroke-width="5"/><path d="M404 232v67" stroke="#6f4a2f" stroke-width="13"/>
    </g>`;

  const helpScene = () => `
    <g stroke="#111923" stroke-linejoin="round">
      ${child({x:183,y:168,scale:.66,pose:"stand",shirt:"#4e9e45"})}
      ${adult({x:350,y:172,scale:.65,shirt:"#6e8fd0"})}
      <path d="M204 212q39-65 68-84" fill="none" stroke="#d99a5c" stroke-width="14" stroke-linecap="round"/>
      <circle cx="267" cy="118" r="9" fill="#d99a5c" stroke-width="4"/>
      <path d="M286 238q-20 20-40 27M317 236q-18 26-42 33" fill="none" stroke="#b9784f" stroke-width="13" stroke-linecap="round"/>
      <circle cx="256" cy="331" r="48" fill="#f3ce4b" stroke-width="5"/><path d="M256 303v56M228 331h56" stroke="#fff" stroke-width="14" stroke-linecap="round"/>
    </g>`;

  const moreScene = () => `
    <g stroke="#111923" stroke-linejoin="round">
      ${child({x:255,y:155,scale:.72,pose:"stand",shirt:"#4e9e45"})}
      <path d="M193 260q31 24 62 0M317 260q-31 24-62 0" fill="none" stroke="#d99a5c" stroke-width="17" stroke-linecap="round"/>
      <circle cx="373" cy="284" r="49" fill="#6fc68a" stroke-width="5"/>
      <path d="M373 255v58M344 284h58" stroke="#fff" stroke-width="15" stroke-linecap="round"/>
    </g>`;

  const hugScene = () => `
    <g stroke="#111923" stroke-linejoin="round">
      ${child({x:204,y:163,scale:.62,pose:"stand",shirt:"#4f8fd0"})}
      ${child({x:312,y:163,scale:.62,pose:"stand",shirt:"#65a95d",skin:"#b87a4f",hair:"#25201d"})}
      <path d="M191 243q66 82 133 0M323 243q-66 82-133 0" fill="none" stroke="#d99a5c" stroke-width="16" stroke-linecap="round"/>
      <path d="M256 317c-44-33-72-56-72-89q0-31 29-31q23 0 43 26q20-26 43-26q29 0 29 31q0 33-72 89z" fill="#ef7d94" stroke-width="5"/>
    </g>`;

  const portraitScene = (kind="mom") => {
    const config = kind === "dad"
      ? {shirt:"#4d83c4",skin:"#b97950",hair:"#29231f"}
      : kind === "grandma"
      ? {shirt:"#8f70ba",skin:"#c38b61",hair:"#c5c5c5"}
      : {shirt:"#dd7b9d",skin:"#d89a62",hair:"#3a2a22"};
    return adult({x:256,y:165,scale:1.05,...config});
  };

  const drawingScene = () => `
    <g>
      ${child({x:305,y:158,scale:.75,pose:"sit",shirt:"#4e9e45"})}
      <ellipse cx="239" cy="307" rx="164" ry="55" fill="#1974ca" stroke="#111923" stroke-width="6"/>
      <rect x="157" y="259" width="137" height="78" rx="8" fill="#fff" stroke="#111923" stroke-width="4"/>
      <path d="M180 316l34-43l32 32l21-22l20 33z" fill="#6fb25a" stroke="#111923" stroke-width="3"/>
      <circle cx="261" cy="280" r="12" fill="#ffd04f" stroke="#111923" stroke-width="3"/>
      <path d="M278 243l-62 68" stroke="#ed684f" stroke-width="12" stroke-linecap="round"/>
      <path d="M286 235q-19 21-32 36" stroke="#d99a5c" stroke-width="15" stroke-linecap="round"/>
    </g>`;

  const blocksScene = () => `
    <g stroke="#111923" stroke-linejoin="round">
      ${child({x:350,y:180,scale:.58,pose:"kneel",shirt:"#ef8543"})}
      <rect x="105" y="277" width="77" height="77" rx="7" fill="#ef4a45" stroke-width="5"/>
      <rect x="187" y="277" width="77" height="77" rx="7" fill="#3382d7" stroke-width="5"/>
      <rect x="269" y="277" width="77" height="77" rx="7" fill="#f1cd34" stroke-width="5"/>
      <rect x="146" y="195" width="77" height="77" rx="7" fill="#69b956" stroke-width="5"/>
      <rect x="228" y="195" width="77" height="77" rx="7" fill="#ee7342" stroke-width="5"/>
      <path d="M157 189l28-47l28 47z" fill="#66bd55" stroke-width="5"/><path d="M239 189l28-47l28 47z" fill="#318add" stroke-width="5"/>
    </g>`;

  const bookScene = () => `
    <g stroke="#111923" stroke-linejoin="round">
      ${child({x:255,y:145,scale:.72,pose:"sit",shirt:"#4d9c47"})}
      <path d="M91 272q82-31 164 27v108q-80-56-164-27z" fill="#5b94da" stroke-width="5"/>
      <path d="M421 272q-82-31-166 27v108q81-56 166-27z" fill="#76b56b" stroke-width="5"/>
      <path d="M255 299v108" fill="none" stroke-width="5"/>
      <path d="M115 313q52-13 106 17M115 344q52-13 106 17M397 313q-52-13-106 17M397 344q-52-13-106 17" fill="none" stroke="#edf3f6" stroke-width="7"/>
      <path d="M192 253q25 18 46 45M318 253q-25 18-46 45" stroke="#d99a5c" stroke-width="14" stroke-linecap="round"/>
    </g>`;

  const sleepScene = () => `
    <g stroke="#111923" stroke-linejoin="round">
      <rect x="77" y="249" width="359" height="121" rx="19" fill="#6d90c4" stroke-width="5"/>
      <rect x="96" y="224" width="128" height="69" rx="24" fill="#f4f6f8" stroke-width="5"/>
      <circle cx="204" cy="251" r="37" fill="#d99a5c" stroke-width="5"/>
      <path d="M172 248q4-42 38-45q34 5 34 43q-29-16-72 2z" fill="#292929" stroke-width="5"/>
      <path d="M220 260q53-45 121 2q38 27 62 76H176z" fill="#8fb3df" stroke-width="5"/>
      <path d="M345 96q-12 79 62 91q-84 20-108-56q-9-31 46-35z" fill="#f3d55b" stroke-width="5"/>
      <path d="M116 164l10-23l10 23l24 10l-24 10l-10 24l-10-24l-24-10z" fill="#fff4a8" stroke-width="4"/>
    </g>`;

  const genericScene = clean => `
    <g stroke="#111923" stroke-linejoin="round">
      ${child({x:258,y:146,scale:.72,pose:"stand",shirt:"#4e9e45"})}
      <rect x="130" y="293" width="252" height="83" rx="16" fill="#eef3f7" stroke-width="5"/>
      <path d="M156 336h200" stroke="#a4b0bb" stroke-width="7" stroke-linecap="round"/>
      <circle cx="256" cy="335" r="25" fill="#f3cc4a" stroke-width="5"/>
      <path d="M256 319v32M240 335h32" stroke="#fff" stroke-width="8" stroke-linecap="round"/>
    </g>`;

  const sceneMarkup = (scene, clean) => ({
    work:workScene,
    magnaTiles:magnaTilesScene,
    outside:outsideScene,
    eat:eatScene,
    play:playScene,
    bathroom:bathroomScene,
    drink:drinkScene,
    swing:swingScene,
    pool:poolScene,
    bubbles:bubblesScene,
    tablet:tabletScene,
    music:musicScene,
    break:breakScene,
    home:homeScene,
    car:carScene,
    walk:walkScene,
    help:helpScene,
    more:moreScene,
    hug:hugScene,
    mom:()=>portraitScene("mom"),
    dad:()=>portraitScene("dad"),
    grandma:()=>portraitScene("grandma"),
    drawing:drawingScene,
    blocks:blocksScene,
    book:bookScene,
    sleep:sleepScene,
    generic:()=>genericScene(clean)
  }[scene] || (()=>genericScene(clean)))();

  const makeAutoFirstThenVisual = text => {
    const clean = String(text || "").trim() || "Activity";
    const key = clean.toLowerCase();
    if (autoVisualCache.has(key)) return autoVisualCache.get(key);

    const scene = resolveAutoVisual(clean);
    let size = clean.length > 18 ? 34 : clean.length > 11 ? 39 : 44;
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
      <rect x="9" y="9" width="494" height="494" rx="34" fill="#fff" stroke="#080b0f" stroke-width="10"/>
      <g transform="translate(0,7)">${sceneMarkup(scene, clean)}</g>
      <rect x="30" y="407" width="452" height="75" rx="18" fill="#fff"/>
      <text x="256" y="451" text-anchor="middle" dominant-baseline="middle"
        font-family="Arial Rounded MT Bold, Arial, sans-serif" font-size="${size}"
        font-weight="800" fill="#05070a">${svgEsc(clean.slice(0, 28))}</text>
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