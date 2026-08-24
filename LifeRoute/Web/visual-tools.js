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
        <input id="visualIconLabel" maxlength="28" placeholder="Label">
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
    .firstThenVisualImage{width:min(49vw,420px);aspect-ratio:4/3;max-height:50vh;object-fit:cover;border-radius:22px 22px 0 0;background:white;border:6px solid #111820;border-bottom:0;box-shadow:0 16px 48px rgba(0,0,0,.18);margin-bottom:0}.firstThenPanel.visualReady .firstThenValue{display:block;width:min(49vw,420px);box-sizing:border-box;margin:0;background:#fff;color:#111820;border:6px solid #111820;border-top:0;border-radius:0 0 22px 22px;padding:11px 14px 14px;font-size:clamp(22px,4.5vw,38px);font-weight:950;line-height:1.05;text-align:center}
    .choiceBoardOverlay{position:fixed;inset:0;z-index:12500;display:none;background:#f8fafc;color:#10213a;padding:calc(12px + env(safe-area-inset-top)) 14px calc(14px + env(safe-area-inset-bottom));overflow:auto}.choiceBoardOverlay.show{display:block}.choiceBoardTop{max-width:900px;margin:0 auto 12px;display:flex;justify-content:space-between;align-items:center}.choiceBoardTop button{background:#e9eff7;color:#10213a}.choiceBoardTitle{font-size:clamp(24px,5vw,42px);font-weight:950;text-align:center;margin:5px 0 18px}.choiceBoardGrid{--choice-columns:2;max-width:900px;margin:auto;display:grid;grid-template-columns:repeat(var(--choice-columns),minmax(0,1fr));gap:12px}.choiceBoardCell{min-height:190px;background:white;border:3px solid #10213a;border-radius:20px;padding:10px;display:flex;flex-direction:column;align-items:center;justify-content:center;box-shadow:0 10px 28px rgba(16,33,58,.08)}.choiceBoardCell img{width:100%;max-height:260px;aspect-ratio:1;object-fit:contain}.choiceBoardCell b{font:900 clamp(18px,4vw,32px)/1.05 system-ui,-apple-system,sans-serif;margin-top:8px;text-align:center}.choiceBoardEmpty{grid-column:1/-1;text-align:center;color:#66768b;padding:30px}
    @media(max-width:680px){.visualCaptureLayout{grid-template-columns:115px 1fr}.visualCameraTile,.visualDraftCard{min-height:118px}.visualDraftCard img{height:118px}.visualIconLibrary,.choiceBoardPicker{grid-template-columns:repeat(3,minmax(0,1fr))}.choiceBoardCell{min-height:150px;border-width:2px;border-radius:16px;padding:8px}.firstThenVisualImage{width:min(84vw,390px);max-height:35vh;margin-bottom:0}.firstThenPanel.visualReady .firstThenValue{width:min(84vw,390px);font-size:clamp(24px,7vw,36px)}}
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
  // Child-recognizable visual generator v3.
  // Goal: literal, concrete scenes with people/objects interacting in an obvious
  // way. Avoid abstract symbols whenever a child could instead see the actual
  // activity, object, place, or person represented.
  const AUTO_VISUALS = [
    { terms:["table work","work","worksheet","desk","school work","do work"], scene:"tableWork" },
    { terms:["magna tiles","magna-tiles","magnet tiles","magnetic tiles"], scene:"magnaTiles" },
    { terms:["outside","outdoors","play outside","yard","patio","playground"], scene:"outside" },
    { terms:["park"], scene:"park" },
    { terms:["eat","food","snack","lunch","dinner","breakfast","meal"], scene:"eat" },
    { terms:["play","free play","toys","toy time"], scene:"play" },
    { terms:["bathroom","toilet","potty"], scene:"bathroom" },
    { terms:["wash hands","hand washing","wash my hands"], scene:"washHands" },
    { terms:["brush teeth","teeth","toothbrush"], scene:"brushTeeth" },
    { terms:["drink","water","juice"], scene:"drink" },
    { terms:["swing","swinging"], scene:"swing" },
    { terms:["pool","swim","swimming"], scene:"pool" },
    { terms:["water play","water table"], scene:"waterPlay" },
    { terms:["bubbles","blow bubbles"], scene:"bubbles" },
    { terms:["ipad","tablet","screen time"], scene:"tablet" },
    { terms:["phone"], scene:"phone" },
    { terms:["music","song","sing","singing"], scene:"music" },
    { terms:["break","rest","calm","quiet time"], scene:"break" },
    { terms:["home","go home"], scene:"home" },
    { terms:["car","drive","ride in car"], scene:"car" },
    { terms:["walk","walking","go for a walk"], scene:"walk" },
    { terms:["help","ask for help"], scene:"help" },
    { terms:["more","more please"], scene:"more" },
    { terms:["hug"], scene:"hug" },
    { terms:["mom","mother"], scene:"mom" },
    { terms:["dad","father"], scene:"dad" },
    { terms:["grandma","grandmother"], scene:"grandma" },
    { terms:["draw","drawing","color","coloring","crayons"], scene:"drawing" },
    { terms:["blocks","lego","legos"], scene:"blocks" },
    { terms:["puzzle"], scene:"puzzle" },
    { terms:["book","read","reading"], scene:"book" },
    { terms:["sleep","nap","bed","bedtime"], scene:"sleep" },
    { terms:["sit","sit down","chair"], scene:"sit" },
    { terms:["wait","waiting"], scene:"wait" },
    { terms:["clean up","cleanup","put away"], scene:"cleanUp" },
    { terms:["shoes","put on shoes"], scene:"shoes" },
    { terms:["coat","jacket","put on coat"], scene:"coat" },
    { terms:["tv","television","watch tv"], scene:"tv" }
  ];

  const autoVisualCache = new Map();

  // High-fidelity raster cards. These are complete image illustrations, not
  // browser-assembled SVG shapes. Prefer them whenever an exact concept exists.
  const REAL_IMAGE_VISUALS = {
    tableWork: "https://images.unsplash.com/photo-1623287072561-95c7ba942539?auto=format&fit=crop&w=1200&q=88",
    play: "https://images.pexels.com/photos/8363750/pexels-photo-8363750.jpeg?auto=compress&dpr=1&w=1200",
    outside: "assets/visuals/outside.jpg"
  };

  const svgEsc = value => String(value || "").replace(/[&<>"']/g, char => ({
    "&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;"
  }[char]));

  const resolveAutoVisual = text => {
    const raw = String(text || "").trim().toLowerCase().replace(/[–—]/g, "-");
    for (const item of AUTO_VISUALS) {
      if (item.terms.some(term => raw === term || raw.includes(term))) return item.scene;
    }
    return "genericActivity";
  };

  const cardBg = (fill="#ffffff") => '<rect x="24" y="24" width="464" height="374" rx="28" fill="' + fill + '"/>';
  const stroke = '#111820';
  const skin = '#D89A5A';
  const darkSkin = '#9C673D';
  const hair = '#252525';

  const sceneTableWork = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <ellipse cx="250" cy="305" rx="166" ry="59" fill="#126BC0"/>
      <path d="M120 334v58M383 334v58" stroke="#0F5CA7" stroke-width="22"/>
      <rect x="350" y="205" width="74" height="128" rx="14" fill="#1971C8"/>
      <rect x="376" y="317" width="17" height="73" rx="7" fill="#145A98"/>
      <circle cx="309" cy="170" r="47" fill="${skin}"/>
      <path d="M266 159q16-58 82-27q9 32-9 67q-6-30-73-40z" fill="${hair}"/>
      <path d="M289 179q8 6 16 0M326 179q8 6 16 0" fill="none" stroke-width="3"/>
      <path d="M305 204q14 9 28 0" fill="none" stroke-width="3"/>
      <path d="M278 218q30 20 63 0l26 89h-111z" fill="#54A33E"/>
      <path d="M276 246q-27 17-51 44M348 246q21 16 32 44" stroke="${skin}" stroke-width="18"/>
      <circle cx="223" cy="291" r="10" fill="${skin}"/><circle cx="382" cy="291" r="10" fill="${skin}"/>
      <rect x="165" y="263" width="51" height="41" rx="7" fill="#fff"/>
      <circle cx="190" cy="283" r="10" fill="#F04B42"/>
      <rect x="221" y="261" width="51" height="41" rx="7" fill="#fff"/>
      <path d="M235 290l12-18l13 18z" fill="#F4CE3E"/>
      <rect x="277" y="259" width="51" height="41" rx="7" fill="#fff"/>
      <rect x="288" y="270" width="29" height="17" rx="5" fill="#5BA96B"/>
      <rect x="112" y="232" width="76" height="65" rx="8" fill="#1673C6"/>
      <rect x="126" y="211" width="49" height="29" rx="4" fill="#fff"/>
      <circle cx="150" cy="225" r="9" fill="#EF433D"/>
      <path d="M281 307v57M342 307v57" stroke="#2E68A7" stroke-width="17"/>
      <path d="M278 364h33M339 364h34" stroke="#252525" stroke-width="14"/>
    </g>`;

  const sceneOutside = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="4" stroke-linejoin="round">
      <rect x="48" y="58" width="416" height="300" rx="24" fill="#69BFF0"/>
      <path d="M48 228h416v130H48z" fill="#D7D0BE"/>
      <rect x="58" y="174" width="141" height="70" fill="#B85D43"/>
      <path d="M52 174l77-55l77 55z" fill="#5E636B"/>
      <rect x="78" y="194" width="25" height="50" fill="#fff"/>
      <rect x="133" y="191" width="33" height="28" fill="#C4E8F8"/>
      <path d="M260 235v-103" stroke="#71492E" stroke-width="18"/>
      <circle cx="260" cy="117" r="82" fill="#4B9636"/>
      <circle cx="223" cy="104" r="34" fill="#5BA843"/>
      <circle cx="303" cy="101" r="36" fill="#3F8A31"/>
      <path d="M65 279h385" stroke="#2D333A" stroke-width="8"/>
      <path d="M80 246v103M126 246v103M172 246v103M218 246v103M264 246v103M310 246v103M356 246v103M402 246v103" stroke="#303740" stroke-width="4"/>
      <path d="M86 319h67l-8 35H94z" fill="#fff"/><path d="M101 319v-29h38v29" fill="none"/>
      <path d="M350 315h70l-10 39h-50z" fill="#1D5C99"/><path d="M366 315v-32h39v32" fill="none"/>
      <rect x="322" y="265" width="28" height="22" fill="#F29AC1"/><rect x="355" y="265" width="28" height="22" fill="#6DD4D3"/><rect x="388" y="265" width="28" height="22" fill="#B795E8"/>
    </g>`;

  const scenePark = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linejoin="round">
      <rect x="48" y="62" width="416" height="295" rx="26" fill="#77C8F1"/>
      <path d="M48 259q100-55 208-5q100 47 208-8v111H48z" fill="#72B85C"/>
      <path d="M93 297q92-38 163-8q80 33 168 0" fill="none" stroke="#D9C79A" stroke-width="34"/>
      <path d="M106 255v-94" stroke="#6F472C" stroke-width="16"/><circle cx="106" cy="143" r="60" fill="#4A9A3A"/>
      <path d="M318 276v-112" stroke="#71472D" stroke-width="16"/><circle cx="318" cy="144" r="65" fill="#4E9A3C"/>
      <path d="M188 270h77" stroke="#6E4C33" stroke-width="10"/><path d="M196 270v50M257 270v50" stroke="#6E4C33" stroke-width="9"/>
      <rect x="188" y="242" width="77" height="28" rx="6" fill="#B67944"/>
    </g>`;

  const sceneMagnaTiles = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linejoin="round">
      <rect x="142" y="164" width="74" height="74" rx="6" fill="#F12F2B"/>
      <rect x="221" y="164" width="74" height="74" rx="6" fill="#F12F2B"/>
      <rect x="300" y="164" width="74" height="74" rx="6" fill="#F12F2B"/>
      <rect x="142" y="243" width="74" height="74" rx="6" fill="#F12F2B"/>
      <rect x="221" y="243" width="74" height="74" rx="6" fill="#F12F2B"/>
      <rect x="300" y="243" width="74" height="74" rx="6" fill="#F12F2B"/>
      <path d="M142 158l37-73 37 73z" fill="#64C832"/>
      <path d="M221 158l37-61l37 61z" fill="#2C8FE7"/>
      <path d="M300 158l37-73 37 73z" fill="#64C832"/>
      <rect x="142" y="322" width="74" height="72" rx="6" fill="#F12F2B"/>
      <rect x="300" y="322" width="74" height="72" rx="6" fill="#F12F2B"/>
      <path d="M221 394l37-39l37 39z" fill="#3099EF"/>
      <path d="M101 305l35-66l34 66zM378 305l35-66l34 66z" fill="#FFD32D"/>
      <g fill="#fff" stroke-width="3">
        <circle cx="153" cy="175" r="6"/><circle cx="205" cy="175" r="6"/><circle cx="153" cy="227" r="6"/><circle cx="205" cy="227" r="6"/>
        <circle cx="232" cy="175" r="6"/><circle cx="284" cy="175" r="6"/><circle cx="311" cy="175" r="6"/><circle cx="363" cy="175" r="6"/>
      </g>
    </g>`;

  const sceneEat = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <ellipse cx="250" cy="316" rx="157" ry="55" fill="#2C78C4"/>
      <circle cx="275" cy="172" r="45" fill="${skin}"/>
      <path d="M236 161q12-53 73-30q11 27-1 56q-10-24-72-26z" fill="${hair}"/>
      <path d="M251 182q8 6 16 0M286 182q8 6 16 0M262 207q13 8 25 0" fill="none" stroke-width="3"/>
      <path d="M247 220q28 18 58 0l21 88h-98z" fill="#5AA34A"/>
      <path d="M240 250q-24 22-38 49M310 252q25 18 36 46" stroke="${skin}" stroke-width="17"/>
      <ellipse cx="254" cy="308" rx="75" ry="33" fill="#fff"/>
      <path d="M219 307q35-44 70 0q-34 43-70 0z" fill="#E84C42"/>
      <path d="M254 284q10-20 27-26" fill="none" stroke="#638B3D" stroke-width="8"/>
      <path d="M151 275v74M137 276v38q0 24 14 24q14 0 14-24v-38" fill="none" stroke="#A1ABB4" stroke-width="8"/>
      <path d="M364 276v73M347 276q17 22 17 43q0-21 17-43" fill="none" stroke="#A1ABB4" stroke-width="8"/>
    </g>`;

  const scenePlay = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="256" cy="152" r="44" fill="${skin}"/>
      <path d="M218 144q13-48 66-29q12 26 1 52q-19-18-67-23z" fill="${hair}"/>
      <path d="M232 163q7 5 14 0M267 163q7 5 14 0M243 188q13 8 26 0" fill="none" stroke-width="3"/>
      <path d="M225 203q31 20 64 0l32 90h-125z" fill="#4FA35A"/>
      <path d="M214 237q-44 15-59 47M302 237q43 16 58 49" stroke="${skin}" stroke-width="17"/>
      <path d="M216 292q-34 43-64 72M299 292q35 43 63 72" stroke="#2D6BB0" stroke-width="20"/>
      <path d="M151 365h48M316 365h48" stroke="#252525" stroke-width="13"/>
      <rect x="124" y="286" width="63" height="63" rx="7" fill="#EF4A43"/>
      <rect x="191" y="302" width="59" height="47" rx="7" fill="#347FD0"/>
      <rect x="254" y="277" width="63" height="72" rx="7" fill="#F2CB31"/>
      <circle cx="374" cy="299" r="31" fill="#DD9553"/><circle cx="348" cy="274" r="13" fill="#DD9553"/><circle cx="400" cy="274" r="13" fill="#DD9553"/>
      <circle cx="364" cy="296" r="4" fill="#111820"/><circle cx="383" cy="296" r="4" fill="#111820"/><ellipse cx="374" cy="310" rx="10" ry="7" fill="#F0BA7E"/>
    </g>`;

  const sceneBathroom = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linejoin="round">
      <rect x="129" y="107" width="253" height="70" rx="18" fill="#EDF2F6"/>
      <circle cx="342" cy="142" r="8" fill="#8795A3"/>
      <path d="M153 180h205v119q0 72-103 72q-102 0-102-72z" fill="#FAFCFD"/>
      <ellipse cx="255" cy="257" rx="78" ry="38" fill="#CDE7F4"/>
      <rect x="178" y="346" width="154" height="31" rx="14" fill="#DCE7EC"/>
      <rect x="383" y="210" width="54" height="116" rx="8" fill="#E8EEF1"/>
      <path d="M392 226h36M392 242h36M392 258h36" stroke="#A8B2BA" stroke-width="4"/>
    </g>`;

  const sceneWashHands = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <rect x="109" y="213" width="294" height="92" rx="40" fill="#F2F6F8"/>
      <ellipse cx="256" cy="260" rx="90" ry="38" fill="#BFE6F5"/>
      <path d="M256 207v-53q0-30 31-30h38" fill="none" stroke="#8D9AA5" stroke-width="15"/>
      <path d="M325 124v61" fill="none" stroke="#8D9AA5" stroke-width="15"/>
      <path d="M325 185q-2 40-37 55" fill="none" stroke="#57B9EB" stroke-width="11"/>
      <path d="M189 248q31-35 66 3M322 248q-31-35-66 3" fill="none" stroke="${skin}" stroke-width="23"/>
      <circle cx="202" cy="221" r="12" fill="#BEEAF4"/><circle cx="225" cy="202" r="9" fill="#BEEAF4"/><circle cx="300" cy="208" r="10" fill="#BEEAF4"/>
      <rect x="110" y="316" width="294" height="43" rx="12" fill="#DCE6EA"/>
    </g>`;

  const sceneBrushTeeth = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="245" cy="189" r="77" fill="${skin}"/>
      <path d="M180 174q10-91 88-76q62 15 58 84q-48-39-146-8z" fill="${hair}"/>
      <circle cx="219" cy="184" r="5" fill="#111820"/><circle cx="271" cy="184" r="5" fill="#111820"/>
      <path d="M219 220q27 20 54 0" fill="#fff"/>
      <path d="M259 222l94 62" stroke="#3F8CD5" stroke-width="12"/>
      <rect x="340" y="270" width="61" height="23" rx="8" fill="#E9F1F7"/>
      <path d="M196 282q47 28 99 0l28 77H170z" fill="#57A64B"/>
      <rect x="349" y="111" width="61" height="97" rx="9" fill="#F2F6F8"/><rect x="359" y="126" width="41" height="52" fill="#BDE4F5"/>
    </g>`;

  const sceneDrink = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="248" cy="166" r="51" fill="${skin}"/>
      <path d="M204 156q15-61 71-35q12 24 3 54q-24-22-74-19z" fill="${hair}"/>
      <path d="M222 177q8 6 15 0M258 177q8 6 15 0" fill="none" stroke-width="3"/>
      <path d="M218 221q31 21 65 0l29 112H190z" fill="#57A44A"/>
      <path d="M211 248q-15 41 8 78M292 245q37 17 46 54" stroke="${skin}" stroke-width="18"/>
      <path d="M314 216h84l-9 111q-2 22-33 22q-31 0-33-22z" fill="#BDE9FA"/>
      <path d="M322 271h69l-5 55q-2 12-30 12q-27 0-29-12z" fill="#51B7EC"/>
      <path d="M353 216l40-69" stroke="#EF5B5B" stroke-width="10"/>
      <circle cx="337" cy="296" r="9" fill="${skin}"/>
    </g>`;

  const sceneSwing = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <path d="M95 381l99-266M417 381l-99-266M151 192h210" fill="none" stroke="#315F91" stroke-width="18"/>
      <path d="M222 192v122M290 192v122" fill="none" stroke="#4E565E" stroke-width="5"/>
      <path d="M207 314h98l-10 35h-78z" fill="#F1B838"/>
      <circle cx="257" cy="226" r="37" fill="${skin}"/>
      <path d="M225 218q9-42 50-25q7 20-1 42q-18-18-49-17z" fill="${hair}"/>
      <path d="M233 260q25 18 51 0l24 71h-101z" fill="#5CA64F"/>
      <path d="M232 282l-24 52M281 283l29 50" stroke="${skin}" stroke-width="14"/>
      <path d="M228 331l-21 49M287 331l27 47" stroke="#2E6DB0" stroke-width="16"/>
    </g>`;

  const scenePool = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <rect x="69" y="194" width="374" height="177" rx="26" fill="#55B9EE"/>
      <path d="M69 248q52-20 105 0q52 21 105 0q52-20 105 0q30 12 59 2M69 300q52-20 105 0q52 21 105 0q52-20 105 0q30 12 59 2" fill="none" stroke="#EAFBFF" stroke-width="10"/>
      <circle cx="290" cy="186" r="42" fill="${skin}"/>
      <path d="M254 177q11-49 53-31q10 20 0 45q-18-19-53-14z" fill="${hair}"/>
      <path d="M253 225q36 22 72 0" fill="none" stroke="#E85A4B" stroke-width="22"/>
      <path d="M125 176v155M125 195h59M184 176v155" fill="none" stroke="#F4F6F7" stroke-width="12"/>
    </g>`;

  const sceneWaterPlay = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <ellipse cx="256" cy="306" rx="147" ry="54" fill="#4EB6E8"/>
      <rect x="142" y="282" width="228" height="68" rx="23" fill="#58BCEB"/>
      <path d="M167 350v42M345 350v42" stroke="#337AA9" stroke-width="15"/>
      <circle cx="257" cy="161" r="42" fill="${skin}"/>
      <path d="M221 153q9-48 50-29q10 21 1 44q-15-15-51-15z" fill="${hair}"/>
      <path d="M228 206q28 18 58 0l25 78H203z" fill="#5AA44B"/>
      <path d="M218 232q-34 24-45 56M294 232q34 23 43 56" stroke="${skin}" stroke-width="16"/>
      <path d="M196 286q31-35 63 0" fill="none" stroke="#F3D04D" stroke-width="10"/>
      <rect x="294" y="258" width="39" height="29" rx="5" fill="#EF5A4E"/>
      <path d="M312 258v-24" stroke="#EF5A4E" stroke-width="8"/>
    </g>`;

  const sceneBubbles = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="4" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="183" cy="202" r="43" fill="${skin}"/>
      <path d="M146 195q10-49 50-29q9 20 1 43q-16-15-51-14z" fill="${hair}"/>
      <path d="M154 247q30 20 61 0l26 95H131z" fill="#5AA44B"/>
      <path d="M215 228l81 18" stroke="${skin}" stroke-width="15"/>
      <circle cx="307" cy="248" r="19" fill="none" stroke="#6EC8EA" stroke-width="7"/>
      <path d="M300 248h-33" stroke="#E15B5B" stroke-width="7"/>
      <circle cx="351" cy="171" r="46" fill="#C5EAF6" fill-opacity=".66"/>
      <circle cx="384" cy="257" r="31" fill="#D8C4F4" fill-opacity=".66"/>
      <circle cx="315" cy="321" r="38" fill="#A8E3D8" fill-opacity=".64"/>
      <path d="M336 158q12-14 25-13M371 246q9-10 18-10M301 309q10-11 20-10" stroke="#fff" stroke-width="6"/>
    </g>`;

  const sceneTablet = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="180" cy="167" r="45" fill="${skin}"/>
      <path d="M141 157q11-51 54-31q9 21 1 45q-18-17-55-14z" fill="${hair}"/>
      <path d="M149 214q30 20 63 0l28 107H121z" fill="#5AA44B"/>
      <path d="M210 239q34 13 50 43M148 240q-28 18-34 48" stroke="${skin}" stroke-width="16"/>
      <rect x="243" y="178" width="169" height="205" rx="21" fill="#27313D"/>
      <rect x="259" y="197" width="137" height="154" rx="10" fill="#71C2EA"/>
      <path d="M283 321l34-47l27 31l22-25l30 41z" fill="#6FB85B" stroke-width="3"/>
      <circle cx="356" cy="236" r="20" fill="#FFD057" stroke-width="3"/>
      <circle cx="327" cy="367" r="7" fill="#9DA7B3"/>
    </g>`;

  const scenePhone = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="236" cy="166" r="49" fill="${skin}"/>
      <path d="M194 155q13-56 59-33q10 22 1 48q-18-18-60-15z" fill="${hair}"/>
      <path d="M203 221q31 20 66 0l28 112H174z" fill="#5AA44B"/>
      <rect x="313" y="178" width="84" height="161" rx="17" fill="#2D333B"/>
      <rect x="324" y="196" width="62" height="111" rx="8" fill="#77C4EC"/>
      <circle cx="355" cy="324" r="7" fill="#AAB2B8"/>
      <path d="M272 251q28 4 45 17" stroke="${skin}" stroke-width="16"/>
    </g>`;

  const sceneMusic = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="238" cy="165" r="46" fill="${skin}"/>
      <path d="M198 155q12-52 55-31q10 21 1 46q-18-17-56-15z" fill="${hair}"/>
      <path d="M208 214q31 21 64 0l28 112H178z" fill="#5AA44B"/>
      <path d="M194 162q-23 7-23 38v31M282 162q23 7 23 38v31" stroke="#526378" stroke-width="13"/>
      <circle cx="171" cy="231" r="21" fill="#5D76D8"/><circle cx="305" cy="231" r="21" fill="#5D76D8"/>
      <path d="M350 121v147q-17-10-35-5q-30 8-25 34q5 27 39 21q34-7 35-42V172l70-16v87q-16-9-33-4q-29 8-24 34q6 27 39 20q33-8 34-43V110z" fill="#7B6DD7"/>
    </g>`;

  const sceneBreak = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <path d="M96 328q16-120 136-120q112 0 131 120z" fill="#8CB3D6"/>
      <circle cx="234" cy="164" r="44" fill="${skin}"/>
      <path d="M196 155q11-50 52-31q10 20 1 45q-17-16-53-14z" fill="${hair}"/>
      <path d="M204 214q30 18 61 0l26 91H178z" fill="#5AA44B"/>
      <path d="M201 251q-38 25-49 55M273 251q36 24 46 54" stroke="${skin}" stroke-width="16"/>
      <path d="M189 302q42 38 91 0" fill="none" stroke="#2F6CB0" stroke-width="20"/>
      <rect x="328" y="179" width="87" height="116" rx="13" fill="#E6EEF4"/>
      <path d="M346 204h51M346 227h51M346 250h37" stroke="#A0AEB8" stroke-width="5"/>
    </g>`;

  const sceneHome = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="6" stroke-linejoin="round">
      <path d="M100 227l156-126l156 126v159H100z" fill="#E7A063"/>
      <path d="M78 234l178-149l178 149" fill="none" stroke="#5C636C" stroke-width="18"/>
      <rect x="220" y="287" width="73" height="99" fill="#8C5A39"/>
      <circle cx="278" cy="337" r="5" fill="#F1D16A"/>
      <rect x="137" y="258" width="59" height="57" fill="#BFE5F5"/><rect x="317" y="258" width="59" height="57" fill="#BFE5F5"/>
      <path d="M256 117v-45" stroke="#5C636C" stroke-width="12"/>
    </g>`;

  const sceneCar = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="6" stroke-linejoin="round">
      <path d="M105 286l43-91q10-22 41-22h135q29 0 42 22l41 91v68H105z" fill="#347ECB"/>
      <path d="M174 198h164l25 65H149z" fill="#BFE5F6"/>
      <circle cx="165" cy="354" r="36" fill="#282D32"/><circle cx="347" cy="354" r="36" fill="#282D32"/>
      <circle cx="165" cy="354" r="16" fill="#9EA7AE"/><circle cx="347" cy="354" r="16" fill="#9EA7AE"/>
      <rect x="121" y="292" width="57" height="25" rx="10" fill="#FFD35A"/><rect x="335" y="292" width="57" height="25" rx="10" fill="#FFD35A"/>
      <rect x="228" y="287" width="58" height="20" rx="8" fill="#E5EEF2"/>
    </g>`;

  const sceneWalk = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round">
      <path d="M65 353q97-36 191-10q90 25 191-3" fill="none" stroke="#BCA97A" stroke-width="33"/>
      <circle cx="245" cy="142" r="43" fill="${skin}"/>
      <path d="M209 133q10-49 50-29q9 20 1 44q-16-16-51-15z" fill="${hair}"/>
      <path d="M216 190q28 19 59 0l29 98H188z" fill="#5AA44B"/>
      <path d="M210 225l-48 49M285 225l51 44" stroke="${skin}" stroke-width="16"/>
      <path d="M221 286l-50 91M275 286l63 83" stroke="#2E6CB0" stroke-width="19"/>
      <path d="M166 378h43M333 370h44" stroke="#252525" stroke-width="13"/>
      <circle cx="382" cy="151" r="50" fill="#4C9B3A"/><path d="M382 197v83" stroke="#70492E" stroke-width="12"/>
    </g>`;

  const sceneHelp = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="182" cy="153" r="40" fill="${skin}"/>
      <path d="M148 144q10-45 46-28q9 18 1 41q-16-14-47-13z" fill="${hair}"/>
      <path d="M154 197q27 18 55 0l24 91H132z" fill="#5AA44B"/>
      <circle cx="332" cy="142" r="44" fill="${darkSkin}"/>
      <path d="M294 132q12-49 52-30q10 20 1 44q-17-15-53-14z" fill="#2B2421"/>
      <path d="M302 191q30 20 60 0l26 105H277z" fill="#4F83C4"/>
      <path d="M213 226q41 11 64 37M301 230q-24 17-40 39" stroke="${skin}" stroke-width="15"/>
      <rect x="221" y="267" width="76" height="71" rx="9" fill="#F1C94A"/>
      <path d="M242 289h34M259 272v34" stroke="#fff" stroke-width="11"/>
    </g>`;

  const sceneMore = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="191" cy="168" r="43" fill="${skin}"/>
      <path d="M154 159q10-48 50-29q9 20 1 44q-16-15-51-15z" fill="${hair}"/>
      <path d="M161 215q29 19 59 0l26 102H139z" fill="#5AA44B"/>
      <path d="M216 240q46 7 71 29" stroke="${skin}" stroke-width="16"/>
      <ellipse cx="344" cy="297" rx="90" ry="42" fill="#2D79C3"/>
      <rect x="307" y="260" width="37" height="37" rx="5" fill="#EF4A43"/>
      <rect x="350" y="255" width="37" height="42" rx="5" fill="#F2CD34"/>
      <path d="M285 206h119" stroke="#70C786" stroke-width="20"/><path d="M344 147v119" stroke="#70C786" stroke-width="20"/>
    </g>`;

  const sceneHug = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="204" cy="157" r="42" fill="${skin}"/><circle cx="307" cy="157" r="42" fill="${darkSkin}"/>
      <path d="M167 148q10-46 49-28q8 18 1 41q-17-14-50-13z" fill="${hair}"/>
      <path d="M270 148q11-46 50-28q9 18 1 41q-17-14-51-13z" fill="#2A2422"/>
      <path d="M166 204q38-25 79 12l12 124q-91 46-129-29z" fill="#5B8FD6"/>
      <path d="M346 204q-39-25-80 12l-12 124q91 46 129-29z" fill="#69AD63"/>
      <path d="M178 233q79 92 157 0M334 233q-79 92-157 0" fill="none" stroke="${skin}" stroke-width="17"/>
    </g>`;

  const sceneMom = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linejoin="round">
      <circle cx="256" cy="168" r="67" fill="${skin}"/>
      <path d="M188 164q8-94 82-86q64 12 64 90q-24-28-48-38q-39 34-98 34z" fill="#4A3327"/>
      <circle cx="232" cy="171" r="5" fill="#111820"/><circle cx="280" cy="171" r="5" fill="#111820"/>
      <path d="M235 205q21 14 42 0" fill="none"/>
      <path d="M149 388q18-126 107-126q89 0 108 126z" fill="#D96D93"/>
    </g>`;

  const sceneDad = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linejoin="round">
      <circle cx="256" cy="168" r="67" fill="${darkSkin}"/>
      <path d="M191 155q13-83 70-75q55 6 62 73q-55-26-132 2z" fill="#272323"/>
      <circle cx="232" cy="171" r="5" fill="#111820"/><circle cx="280" cy="171" r="5" fill="#111820"/>
      <path d="M235 205q21 14 42 0" fill="none"/>
      <path d="M149 388q18-126 107-126q89 0 108 126z" fill="#4F83C4"/>
    </g>`;

  const sceneGrandma = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linejoin="round">
      <circle cx="256" cy="171" r="67" fill="${skin}"/>
      <path d="M186 166q7-81 68-88q66 1 74 88q-33-25-142 0z" fill="#C9C9C9"/>
      <circle cx="232" cy="173" r="5" fill="#111820"/><circle cx="280" cy="173" r="5" fill="#111820"/>
      <path d="M234 208q22 13 44 0" fill="none"/>
      <path d="M149 388q18-126 107-126q89 0 108 126z" fill="#9A78C3"/>
      <circle cx="232" cy="173" r="15" fill="none"/><circle cx="280" cy="173" r="15" fill="none"/><path d="M247 173h18" fill="none"/>
    </g>`;

  const sceneDrawing = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="175" cy="160" r="42" fill="${skin}"/>
      <path d="M139 152q10-47 49-28q8 19 1 42q-17-15-50-14z" fill="${hair}"/>
      <path d="M147 206q28 19 58 0l25 98H125z" fill="#5AA44B"/>
      <rect x="234" y="173" width="191" height="172" rx="11" fill="#fff"/>
      <path d="M259 310l48-63l42 47l35-36l30 52z" fill="#72B65C"/>
      <circle cx="364" cy="220" r="24" fill="#FFD04D"/>
      <path d="M197 244l118 97" stroke="${skin}" stroke-width="15"/>
      <path d="M289 318l98-98" stroke="#EE6D52" stroke-width="12"/>
    </g>`;

  const sceneBlocks = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="174" cy="160" r="41" fill="${skin}"/>
      <path d="M139 151q10-46 48-28q9 19 1 41q-16-14-49-13z" fill="${hair}"/>
      <path d="M147 203q28 18 57 0l25 97H124z" fill="#5AA44B"/>
      <path d="M203 232q45 12 67 43" stroke="${skin}" stroke-width="15"/>
      <rect x="265" y="265" width="70" height="70" rx="7" fill="#EF4A45"/>
      <rect x="340" y="265" width="70" height="70" rx="7" fill="#3484D8"/>
      <rect x="302" y="190" width="70" height="70" rx="7" fill="#F2CE3B"/>
      <rect x="340" y="115" width="70" height="70" rx="7" fill="#6DBD58"/>
    </g>`;

  const scenePuzzle = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="170" cy="161" r="41" fill="${skin}"/>
      <path d="M135 152q10-46 48-28q9 19 1 41q-16-14-49-13z" fill="${hair}"/>
      <path d="M142 204q28 19 57 0l25 96H120z" fill="#5AA44B"/>
      <path d="M198 234q50 12 74 40" stroke="${skin}" stroke-width="15"/>
      <rect x="253" y="180" width="177" height="165" rx="13" fill="#F6E8B8"/>
      <path d="M253 262h177M341 180v165" stroke="#D89A4F" stroke-width="6"/>
      <circle cx="341" cy="221" r="15" fill="#5CA7DD"/><circle cx="298" cy="262" r="15" fill="#EF6E66"/><circle cx="385" cy="262" r="15" fill="#72B65E"/>
      <path d="M327 181v28q0 14 14 14q14 0 14-14v-28M254 248h29q14 0 14 14q0 14-14 14h-29" fill="#F6E8B8"/>
    </g>`;

  const sceneBook = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="165" cy="151" r="41" fill="${skin}"/>
      <path d="M130 143q10-46 48-28q8 19 1 41q-16-14-49-13z" fill="${hair}"/>
      <path d="M137 194q28 18 57 0l25 102H115z" fill="#5AA44B"/>
      <path d="M192 225q38 13 59 44" stroke="${skin}" stroke-width="15"/>
      <path d="M236 173q88-33 174 28v170q-83-58-174-29z" fill="#6A9DD9"/>
      <path d="M236 201q-88-33-174 28v142q83-58 174-29z" fill="#77B66C"/>
      <path d="M236 202v140" fill="none"/>
      <path d="M88 255q55-15 113 20M88 290q55-15 113 20M385 227q-57-15-113 20M385 262q-57-15-113 20" fill="none" stroke="#EAF1F5" stroke-width="7"/>
    </g>`;

  const sceneSleep = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <rect x="72" y="264" width="368" height="117" rx="18" fill="#6B8FC5"/>
      <rect x="95" y="233" width="130" height="63" rx="22" fill="#F2F4F7"/>
      <circle cx="180" cy="245" r="38" fill="${skin}"/>
      <path d="M148 237q9-42 43-26q8 17 1 37q-14-13-44-11z" fill="${hair}"/>
      <path d="M214 268q58-52 135 5q40 31 57 80H169z" fill="#8FB4E1"/>
      <path d="M350 93q-12 87 69 99q-93 22-119-63q-9-30 50-36z" fill="#F2D55B"/>
      <path d="M112 151l11-24l11 24l24 11l-24 11l-11 24l-11-24l-24-11z" fill="#FFF1A6"/>
    </g>`;

  const sceneSit = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <rect x="278" y="195" width="113" height="122" rx="16" fill="#2878C7"/>
      <path d="M293 315v75M374 315v75" stroke="#1B5E9E" stroke-width="15"/>
      <circle cx="238" cy="157" r="43" fill="${skin}"/>
      <path d="M201 148q10-48 50-29q9 20 1 44q-17-15-51-15z" fill="${hair}"/>
      <path d="M210 203q29 19 60 0l27 93H181z" fill="#5AA44B"/>
      <path d="M224 294l63 18M286 312l54 39" stroke="#2E6CB0" stroke-width="18"/>
      <path d="M195 233q45 19 80 61" stroke="${skin}" stroke-width="15"/>
    </g>`;

  const sceneWait = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="181" cy="156" r="42" fill="${skin}"/>
      <path d="M145 147q10-47 49-28q9 19 1 42q-16-15-50-14z" fill="${hair}"/>
      <path d="M153 201q28 18 58 0l26 102H130z" fill="#5AA44B"/>
      <path d="M159 234q29 35 65 0" stroke="${skin}" stroke-width="15"/>
      <circle cx="349" cy="232" r="89" fill="#F4F6F8"/>
      <circle cx="349" cy="232" r="75" fill="#fff"/>
      <path d="M349 232V177M349 232l43 28" stroke="#4F6172" stroke-width="9"/>
      <circle cx="349" cy="232" r="8" fill="#4F6172"/>
    </g>`;

  const sceneCleanUp = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="176" cy="153" r="41" fill="${skin}"/>
      <path d="M141 144q10-46 48-28q9 19 1 41q-16-14-49-13z" fill="${hair}"/>
      <path d="M148 197q28 18 57 0l25 101H126z" fill="#5AA44B"/>
      <path d="M202 228q49 16 78 49" stroke="${skin}" stroke-width="15"/>
      <rect x="275" y="248" width="128" height="103" rx="13" fill="#2F7DC3"/>
      <rect x="290" y="213" width="97" height="36" rx="10" fill="#3A8ACD"/>
      <rect x="252" y="289" width="43" height="43" rx="6" fill="#EF4A43"/>
      <rect x="320" y="269" width="43" height="43" rx="6" fill="#F2CE3B"/>
      <path d="M255 272l19-31l18 31z" fill="#70B65D"/>
    </g>`;

  const sceneShoes = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="176" cy="153" r="41" fill="${skin}"/>
      <path d="M141 144q10-46 48-28q9 19 1 41q-16-14-49-13z" fill="${hair}"/>
      <path d="M148 198q28 18 57 0l25 96H126z" fill="#5AA44B"/>
      <path d="M172 292l-24 62M208 292l20 62" stroke="#2E6CB0" stroke-width="18"/>
      <path d="M143 355h57q8 0 8 13v12h-78q-9 0-9-10q0-15 22-15zM219 355h57q8 0 8 13v12h-78q-9 0-9-10q0-15 13-15z" fill="#252525"/>
      <path d="M301 304h88q14 0 14 19v25h-120q-12 0-12-14q0-30 30-30z" fill="#2B72B7"/>
      <path d="M312 319l48 0M320 332l44 0" stroke="#fff" stroke-width="5"/>
    </g>`;

  const sceneCoat = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="165" cy="151" r="41" fill="${skin}"/>
      <path d="M130 142q10-46 48-28q9 19 1 41q-16-14-49-13z" fill="${hair}"/>
      <path d="M137 194q28 18 57 0l25 97H115z" fill="#5AA44B"/>
      <path d="M196 225q45 12 72 42" stroke="${skin}" stroke-width="15"/>
      <path d="M276 122q55 22 93 0l39 101l-33 19v138H270V242l-34-19z" fill="#D55349"/>
      <path d="M322 125v255M286 189h21M337 189h21" fill="none" stroke="#A23D36" stroke-width="6"/>
      <circle cx="322" cy="180" r="5" fill="#F1D172"/><circle cx="322" cy="215" r="5" fill="#F1D172"/>
    </g>`;

  const sceneTV = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <rect x="205" y="105" width="236" height="177" rx="15" fill="#2A3037"/>
      <rect x="223" y="124" width="200" height="137" rx="8" fill="#75C5EF"/>
      <path d="M249 236l46-61l39 43l31-32l47 50z" fill="#70B75F"/>
      <circle cx="373" cy="157" r="24" fill="#FFD258"/>
      <path d="M281 283v42M365 283v42M249 325h150" stroke="#59626A" stroke-width="12"/>
      <circle cx="145" cy="195" r="39" fill="${skin}"/>
      <path d="M111 187q10-44 47-27q8 18 1 40q-15-14-48-13z" fill="${hair}"/>
      <path d="M117 237q27 18 55 0l24 100H95z" fill="#5AA44B"/>
    </g>`;

  const sceneGenericActivity = () => `
    ${cardBg("#fff")}
    <g stroke="${stroke}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="184" cy="157" r="42" fill="${skin}"/>
      <path d="M148 148q10-47 49-28q9 19 1 42q-16-15-50-14z" fill="${hair}"/>
      <path d="M156 202q28 18 58 0l26 102H133z" fill="#5AA44B"/>
      <path d="M212 232q44 15 73 48" stroke="${skin}" stroke-width="15"/>
      <rect x="282" y="194" width="130" height="139" rx="18" fill="#EDF3F8"/>
      <circle cx="347" cy="249" r="34" fill="#79AEDD"/>
      <path d="M326 291h42" stroke="#7C8D9B" stroke-width="8"/>
    </g>`;

  const sceneMarkup = scene => ({
    tableWork:sceneTableWork,
    magnaTiles:sceneMagnaTiles,
    outside:sceneOutside,
    park:scenePark,
    eat:sceneEat,
    play:scenePlay,
    bathroom:sceneBathroom,
    washHands:sceneWashHands,
    brushTeeth:sceneBrushTeeth,
    drink:sceneDrink,
    swing:sceneSwing,
    pool:scenePool,
    waterPlay:sceneWaterPlay,
    bubbles:sceneBubbles,
    tablet:sceneTablet,
    phone:scenePhone,
    music:sceneMusic,
    break:sceneBreak,
    home:sceneHome,
    car:sceneCar,
    walk:sceneWalk,
    help:sceneHelp,
    more:sceneMore,
    hug:sceneHug,
    mom:sceneMom,
    dad:sceneDad,
    grandma:sceneGrandma,
    drawing:sceneDrawing,
    blocks:sceneBlocks,
    puzzle:scenePuzzle,
    book:sceneBook,
    sleep:sceneSleep,
    sit:sceneSit,
    wait:sceneWait,
    cleanUp:sceneCleanUp,
    shoes:sceneShoes,
    coat:sceneCoat,
    tv:sceneTV,
    genericActivity:sceneGenericActivity
  }[scene] || sceneGenericActivity)();

  const fontSizeFor = text => {
    const n = String(text || "").length;
    if (n > 20) return 29;
    if (n > 15) return 33;
    if (n > 11) return 37;
    return 42;
  };

  const makeAutoFirstThenVisual = text => {
    const clean = String(text || "").trim() || "Activity";
    const key = "v3:" + clean.toLowerCase();
    if (autoVisualCache.has(key)) return autoVisualCache.get(key);

    const scene = resolveAutoVisual(clean);

    // The new image pipeline uses complete raster illustrations first.
    // This produces the same kind of recognizable scene card as LifeRoute's
    // established visual library instead of constructing a picture from shapes.
    if (REAL_IMAGE_VISUALS[scene]) {
      const base = REAL_IMAGE_VISUALS[scene];
      const url = /^https?:/i.test(base) ? base : base + "?v=real-visual-v4";
      autoVisualCache.set(key, url);
      return url;
    }

    const label = svgEsc(clean.slice(0, 28));
    const labelSize = fontSizeFor(clean);
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" role="img" aria-label="${label}">
      <rect x="9" y="9" width="494" height="494" rx="35" fill="#fff" stroke="#05070A" stroke-width="11"/>
      <g>${sceneMarkup(scene)}</g>
      <rect x="33" y="399" width="446" height="83" rx="18" fill="#fff"/>
      <text x="256" y="449" text-anchor="middle" dominant-baseline="middle"
        font-family="Arial Rounded MT Bold, Arial, sans-serif" font-size="${labelSize}"
        font-weight="800" fill="#05070A">${label}</text>
    </svg>`;

    const url = "data:image/svg+xml;charset=utf-8," + encodeURIComponent(svg);
    autoVisualCache.set(key, url);
    return url;
  };

  const firstThenModeFor = side => side === "first" ? state.firstMode : state.thenMode;
  const firstThenSavedIdFor = side => side === "first" ? state.firstIconId : state.thenIconId;
  const firstThenTextFor = side => {
    const field = document.getElementById(side === "first" ? "firstThenFirst" : "firstThenThen");
    return String(field?.value || "").trim();
  };

  const firstThenVisualFor = side => {
    const mode = firstThenModeFor(side);
    const text = firstThenTextFor(side);
    if (!text || mode === "text") return null;
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
        const label = firstThenTextFor(side);
        img.onerror = () => {
          // Never leave a blank/broken card if a raster asset fails to load.
          const scene = resolveAutoVisual(label);
          const svgLabel = svgEsc(label.slice(0, 28));
          const labelSize = fontSizeFor(label);
          const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" role="img" aria-label="${svgLabel}">
            <rect x="9" y="9" width="494" height="494" rx="35" fill="#fff" stroke="#05070A" stroke-width="11"/>
            <g>${sceneMarkup(scene)}</g>
            <rect x="33" y="399" width="446" height="83" rx="18" fill="#fff"/>
            <text x="256" y="449" text-anchor="middle" dominant-baseline="middle"
              font-family="Arial Rounded MT Bold, Arial, sans-serif" font-size="${labelSize}"
              font-weight="800" fill="#05070A">${svgLabel}</text>
          </svg>`;
          img.onerror = null;
          img.src = "data:image/svg+xml;charset=utf-8," + encodeURIComponent(svg);
        };
        img.src = visual;
        img.alt = label;
        img.hidden = false;
        panel.classList.add("visualReady");
        panel.setAttribute("aria-label", label);
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