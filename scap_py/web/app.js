"use strict";
/* Performance de Decolagem - front-end (sem bibliotecas).
 * Fala com app.py: /api/meta, /api/airport/<ICAO>, /api/calc, /api/malha,
 * /api/job/<id>, /files/<csv>. */

// ------------------------------------------------------------------ utilidades
const $ = (sel, root = document) => root.querySelector(sel);
const SVG = "http://www.w3.org/2000/svg";

function h(tag, attrs, ...kids) {
  const el = document.createElement(tag);
  setAttrs(el, attrs);
  for (const kid of kids.flat()) {
    if (kid == null || kid === false) continue;
    el.append(kid.nodeType ? kid : document.createTextNode(String(kid)));
  }
  return el;
}
function s(tag, attrs, ...kids) {
  const el = document.createElementNS(SVG, tag);
  setAttrs(el, attrs);
  for (const kid of kids.flat()) {
    if (kid == null || kid === false) continue;
    el.append(kid.nodeType ? kid : document.createTextNode(String(kid)));
  }
  return el;
}
function setAttrs(el, attrs) {
  for (const [k, v] of Object.entries(attrs || {})) {
    if (k.startsWith("aria-") && typeof v === "boolean") { el.setAttribute(k, String(v)); continue; }
    if (v == null || v === false) continue;
    if (k === "class") el.setAttribute("class", v);
    else if (k === "text") el.textContent = v;
    else if (k.startsWith("on")) el.addEventListener(k.slice(2), v);
    else el.setAttribute(k, v === true ? "" : v);
  }
}

const nfKg = new Intl.NumberFormat("pt-BR", { maximumFractionDigits: 0 });
const nfNum = new Intl.NumberFormat("pt-BR", { maximumFractionDigits: 2 });
const nfPlain = new Intl.NumberFormat("pt-BR", { maximumFractionDigits: 2, useGrouping: false });
const kg = (n) => nfKg.format(Math.round(n));
const num = (n) => nfNum.format(n);
const plain = (n) => nfPlain.format(n);
const qnhText = (q) => plain(q);
const tempText = (t) => `${plain(t)} °C`;
const speed = (v) => (v == null ? "–" : String(Math.round(v)));

function windText(w, x = 0, unit = true) {
  const kt = unit ? " kt" : "";
  if (x) return `través ${plain(Math.abs(x))}${kt} (${x > 0 ? "D" : "E"})`;
  if (w > 0) return `proa ${plain(w)}${kt}`;
  if (w < 0) return `cauda ${plain(-w)}${kt}`;
  return "sem vento";
}
function v1Text(r) {
  if (r.v1_min == null) return "–";
  const a = Math.round(r.v1_min), b = Math.round(r.v1_max);
  return a === b ? String(a) : `${a}–${b}`;
}
const uniq = (arr) => [...new Set(arr)].sort((a, b) => a - b);
const norm = (t) => t.normalize("NFD").replace(/[̀-ͯ]/g, "").toUpperCase();
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/* Servidor (config.js) e senha: com PERF_PASSWORD no servidor, a senha vai
 * no cabecalho X-Perf-Key e fica guardada neste navegador. */
const API = (window.PERF_API || "").replace(/\/$/, "");
const KEY_STORE = "perf.key";
const apiKey = () => { try { return localStorage.getItem(KEY_STORE) || ""; } catch (e) { return ""; } };
/** Link de download (CSV): leva a senha na URL, ja que um <a> nao manda cabecalho. */
const fileUrl = (name) => `${API}/files/${encodeURIComponent(name)}${apiKey() ? `?key=${encodeURIComponent(apiKey())}` : ""}`;
let loginPromise = null;
function askLogin(wrong) {
  loginPromise ||= new Promise((resolve) => {
    const dlg = $("#login");
    $("#login-error").hidden = !wrong;
    $("#login-key").value = "";
    dlg.addEventListener("close", () => {
      try { localStorage.setItem(KEY_STORE, $("#login-key").value); } catch (e) { /* sem storage */ }
      loginPromise = null;
      resolve();
    }, { once: true });
    dlg.addEventListener("cancel", (e) => e.preventDefault(), { once: true });   // Esc nao fecha
    dlg.showModal();
    $("#login-key").focus();
  });
  return loginPromise;
}
async function api(path, body) {
  for (let attempt = 0; ; attempt++) {
    const headers = { ...(body === undefined ? {} : { "Content-Type": "application/json" }), ...(apiKey() ? { "X-Perf-Key": apiKey() } : {}) };
    const res = await fetch(API + path, body === undefined ? { headers } : { method: "POST", headers, body: JSON.stringify(body) });
    const data = await res.json().catch(() => ({ error: "Resposta inválida do servidor" }));
    if (res.status === 401 && data.auth) { await askLogin(attempt > 0 || !!apiKey()); continue; }
    if (!res.ok || data.error && !data.state) throw new Error(data.error || res.statusText);
    return data;
  }
}
async function pollJob(id, onTick) {
  for (;;) {
    const job = await api(`/api/job/${id}`);
    onTick(job);
    if (job.state !== "running") return job;
    await sleep(job.kind === "malha" ? 600 : 350);
  }
}

const tooltip = $("#tooltip");
function showTooltip(content, x, y) {
  tooltip.replaceChildren(content);
  tooltip.hidden = false;
  const pad = 14, r = tooltip.getBoundingClientRect();
  let left = x + pad, top = y + pad;
  if (left + r.width > innerWidth - 8) left = x - r.width - pad;
  if (top + r.height > innerHeight - 8) top = y - r.height - pad;
  tooltip.style.left = `${Math.max(8, left)}px`;
  tooltip.style.top = `${Math.max(8, top)}px`;
}
const hideTooltip = () => { tooltip.hidden = true; };

// ------------------------------------------------------------------ tema
(function theme() {
  const root = document.documentElement;
  try { const saved = localStorage.getItem("theme"); if (saved) root.dataset.theme = saved; } catch (e) { /* sem storage */ }
  $("#theme-toggle").addEventListener("click", () => {
    const dark = root.dataset.theme ? root.dataset.theme === "dark"
      : matchMedia("(prefers-color-scheme: dark)").matches;
    root.dataset.theme = dark ? "light" : "dark";
    try { localStorage.setItem("theme", root.dataset.theme); } catch (e) { /* ok */ }
    if (state.result) renderViews();
  });
})();

// ------------------------------------------------------------------ paginas
document.querySelectorAll(".tabs button").forEach((b) => b.addEventListener("click", () => {
  document.querySelectorAll(".tabs button").forEach((x) => x.setAttribute("aria-selected", x === b));
  for (const page of ["calc", "malha", "pouso"]) {
    const el = $(`#page-${page}`);
    el.hidden = page !== b.dataset.page;
    el.classList.toggle("active", page === b.dataset.page);
  }
  if (b.dataset.page === "pouso") initPouso();
}));

// ------------------------------------------------------------------ condicoes
/* Formulario de temperatura / vento / QNH, cada um com "Um valor" ou "Faixa".
 * spec() -> corpo da API; count() -> numero de combinacoes (ou null). */
function conditionsForm(root, { tempMode = "single", onEnter, onChange }) {
  const st = {
    temp: { mode: tempMode, value: "25", min: "-10", max: "45", step: "1" },
    wind: { mode: "single", kind: "calm", speed: "10", side: "right", min: "-10", max: "20", step: "5" },
    qnh: { mode: "single", value: "1013,25", min: "990", max: "1030", step: "10" },
  };
  let crossNote = "";

  const previews = {};
  const input = (obj, key, width) => h("input", {
    class: "num-input", value: obj[key], inputmode: "decimal", style: width ? `width:${width}px` : null,
    "aria-label": key,
    oninput: (e) => { obj[key] = e.target.value; updatePreviews(); onChange && onChange(); },
    onkeydown: (e) => { if (e.key === "Enter" && onEnter) onEnter(); },
  });
  const seg = (options, current, pick, full) => h("div", { class: `seg${full ? " full" : ""}`, role: "group" },
    options.map(([key, label]) => h("button", {
      type: "button", "aria-pressed": key === current, text: label,
      onclick: () => { pick(key); render(); onChange && onChange(); },
    })));
  const range = (obj, unit, key) => {
    previews[key] = h("p", { class: "range-preview" });
    return [h("div", { class: "inline-inputs range-inputs" },
      "De", input(obj, "min"), "até", input(obj, "max"), "a cada", input(obj, "step"),
      h("span", { class: "unit", text: unit })), previews[key]];
  };
  const UNITS = { temp: "°C", wind: "kt", qnh: "hPa" };
  function updatePreviews() {
    for (const [key, el] of Object.entries(previews)) {
      if (!el.isConnected) continue;
      const vals = rangeValues(st[key]);
      el.classList.toggle("warn", !vals || vals.length < 2);
      if (!vals) { el.textContent = "Faixa inválida: o início tem que ser menor ou igual ao fim e o intervalo maior que zero."; continue; }
      const fmt = (v) => plain(v);
      const list = vals.length <= 8 ? vals.map(fmt).join(" · ")
        : `${vals.slice(0, 3).map(fmt).join(" · ")} … ${vals.slice(-2).map(fmt).join(" · ")}`;
      el.textContent = vals.length === 1
        ? `Só 1 valor (${fmt(vals[0])} ${UNITS[key]}): o intervalo é maior que a faixa.`
        : `${vals.length} valores: ${list} ${UNITS[key]}`;
    }
  }
  const block = (key, title, sub, single, unit) => {
    const obj = st[key];
    return h("div", { class: "cond" },
      h("div", { class: "cond-head" },
        h("span", {}, title, sub ? h("small", { text: sub }) : null),
        seg([["single", "Um valor"], ["range", "Faixa"]], obj.mode, (m) => { obj.mode = m; })),
      h("div", { class: "cond-body" }, obj.mode === "single" ? single() : range(obj, unit, key)));
  };

  function render() {
    const w = st.wind;
    root.replaceChildren(
      block("temp", "Temperatura", null, () => h("div", { class: "inline-inputs" },
        input(st.temp, "value", 80), h("span", { class: "unit", text: "°C" })), "°C"),
      block("wind", "Vento", w.mode === "range" ? "na pista · negativo = cauda" : "em relação à pista",
        () => [
          seg([["calm", "Sem vento"], ["head", "Proa"], ["tail", "Cauda"], ["cross", "Través"]],
            w.kind, (k) => { w.kind = k; }, true),
          w.kind === "calm" ? null : h("div", { class: "inline-inputs" },
            input(w, "speed"), h("span", { class: "unit", text: "kt" }),
            w.kind === "cross" ? seg([["right", "da direita"], ["left", "da esquerda"]], w.side, (k) => { w.side = k; }) : null),
          w.kind === "cross" ? h("p", { class: "hint", text: crossNote || "O través só entra no cálculo dos Airbus." }) : null,
        ], "kt"),
      block("qnh", "QNH", null, () => h("div", { class: "inline-inputs" },
        input(st.qnh, "value", 96), h("span", { class: "unit", text: "hPa" })), "hPa"),
    );
    updatePreviews();
  }

  const n = (v) => Number(String(v).replace(",", "."));
  // mesma regra do servidor (batch.temperatures): inicio, inicio+passo, ... <= fim
  function rangeValues(obj) {
    const lo = n(obj.min), hi = n(obj.max), step = n(obj.step);
    if (![lo, hi, step].every(Number.isFinite) || step <= 0 || hi < lo) return null;
    const count = Math.floor((hi - lo) / step + 1e-9) + 1;
    if (count > 5000) return null;
    return Array.from({ length: count }, (_, i) => Math.round((lo + i * step) * 100) / 100);
  }
  const sizeOf = (obj) => {
    if (obj.mode === "single") return 1;
    const vals = rangeValues(obj);
    return vals ? vals.length : null;
  };
  render();
  const pack = (obj) => obj.mode === "range"
    ? { mode: "range", min: obj.min, max: obj.max, step: obj.step }
    : { mode: "single", value: obj.value };
  return {
    spec: () => ({
      temp: pack(st.temp), qnh: pack(st.qnh),
      wind: st.wind.mode === "range" ? pack(st.wind)
        : { mode: "single", kind: st.wind.kind, speed: st.wind.speed, side: st.wind.side },
    }),
    count: () => {
      const sizes = [sizeOf(st.temp), sizeOf(st.wind), sizeOf(st.qnh)];
      return sizes.includes(null) ? null : sizes.reduce((a, b) => a * b, 1);
    },
    setCrossNote: (text) => { crossNote = text; if (st.wind.kind === "cross") render(); },
    /** Estado do formulario (para salvar/restaurar consultas). */
    getState: () => JSON.parse(JSON.stringify(st)),
    setState: (saved) => {
      for (const k of ["temp", "wind", "qnh"]) if (saved && saved[k]) Object.assign(st[k], saved[k]);
      render();
    },
    /** Resumo curto: "25 °C · sem vento · QNH 1013,25". */
    summary: () => {
      const span = (obj, unit, fmt = plain) => {
        if (obj.mode === "single") return `${fmt(n(obj.value))}${unit}`;
        const vals = rangeValues(obj);
        if (!vals) return "faixa inválida";
        return vals.length === 1 ? `${fmt(vals[0])}${unit}` : `${fmt(vals[0])}–${fmt(vals.at(-1))}${unit}`;
      };
      const w = st.wind;
      const wind = w.mode === "range" ? `vento ${span(w, " kt")}`
        : w.kind === "calm" ? "sem vento"
          : `${{ head: "proa", tail: "cauda", cross: "través" }[w.kind]} ${plain(n(w.speed))} kt`;
      return `${span(st.temp, " °C")} · ${wind} · QNH ${span(st.qnh, "")}`;
    },
  };
}
const countText = (n) => n == null ? "Confira os valores das faixas"
  : n === 1 ? "1 cálculo" : `${nfKg.format(n)} combinações`;

// ------------------------------------------------------------------ estado
const state = {
  meta: null, airport: null, focus: null,
  planes: new Set(),            // "aeronave:motor" (indices)
  runways: [],                  // [{icao, rwy, edit?}] edit = dados alterados (RWYD 1/3/4/5/6/8/11)
  airports: {},                 // cache de /api/airport/<ICAO>
  flaps: {},                    // {nome da aeronave: [null (otimo) e/ou codigos]}; ausente = so o otimo
  cgs: {},                      // {nome da aeronave: [codigos do POPT 30]}; ausente = so Standard (0)
  closures: {},                 // {"ICAO 12-30": {"12": m, "30": m}} metros fechados a partir de cada cabeceira
  result: null, view: "summary", chart: null, rtow: {}, sort: { key: "plane", dir: 1 },
};
const planeId = (i, j) => `${i}:${j}`;
const runwayId = (r) => `${r.icao} ${r.rwy}`;
function toggleSet(set, key) { if (set.has(key)) set.delete(key); else set.add(key); }

// ------------------------------------------------------------------ memoria (ultima consulta e recentes)
/* Fica so no navegador (localStorage), como conveniencia: a ultima consulta
 * volta ao abrir o app e as recentes viram atalhos. Aeronaves sao guardadas
 * pelo nome (nao pelo indice), para sobreviver a mudancas na lista. */
const STORE = { last: "perf.last", recent: "perf.recent", airports: "perf.airports" };
const load = (key, fallback) => { try { return JSON.parse(localStorage.getItem(key)) ?? fallback; } catch (e) { return fallback; } };
const save = (key, value) => { try { localStorage.setItem(key, JSON.stringify(value)); } catch (e) { /* sem storage */ } };

function planeLabel(id) {
  const [i, j] = id.split(":");
  const a = state.meta.aircraft[i];
  return `${a.name} ${a.variants[j].label}`;
}
function planeIdOf(label) {
  for (const a of state.meta.aircraft) {
    for (const v of a.variants) if (`${a.name} ${v.label}` === label && v.ready) return planeId(a.id, v.id);
  }
  return null;
}
function runwaysText() {
  const groups = {};
  for (const r of state.runways) (groups[r.icao] ||= []).push(r.rwy + (isChanged(r) ? "*" : ""));
  return Object.entries(groups).map(([icao, rwys]) => `${icao} ${rwys.join(", ")}`).join(" · ");
}
function snapshot() {
  return { planes: [...state.planes].map(planeLabel), runways: state.runways.map((r) => ({ ...r })), conds: calcForm.getState(),
    ...(Object.keys(state.flaps).length ? { flaps: { ...state.flaps } } : {}),
    ...(Object.keys(state.cgs).length ? { cgs: { ...state.cgs } } : {}),
    ...(Object.keys(state.closures).length ? { closures: { ...state.closures } } : {}) };
}
function restore(snap, { quiet } = {}) {
  if (!snap) return;
  state.planes = new Set((snap.planes || []).map(planeIdOf).filter(Boolean));
  state.runways = (snap.runways || []).filter((r) => r && r.icao && r.rwy);
  state.flaps = Object.fromEntries(Object.entries(snap.flaps || {})        // antes: um codigo so
    .map(([k, v]) => [k, Array.isArray(v) ? v : [v]]));
  state.closures = { ...(snap.closures || {}) };
  state.cgs = Object.fromEntries(Object.entries(snap.cgs || {})          // antes: um codigo so
    .map(([k, v]) => [k, Array.isArray(v) ? v : [v]]));
  if (snap.conds) calcForm.setState(snap.conds);
  renderPlanes(); renderSelectedRunways(); renderAirportRunways(); updateCalcButton();
  if (!quiet) flash("#calc-btn");
}
function rememberLast() { save(STORE.last, snapshot()); }
function addRecent() {
  const snap = snapshot();
  const key = JSON.stringify(snap);
  const list = load(STORE.recent, []).filter((x) => JSON.stringify(x.snap) !== key);
  list.unshift({ snap, when: Date.now() });
  save(STORE.recent, list.slice(0, 6));
  renderRecents();
}
function renderRecents() {
  const list = load(STORE.recent, []);
  $("#recent-block").hidden = !list.length;
  $("#recents").replaceChildren(...list.map(({ snap }) => {
    const planes = snap.planes || [];
    const groups = {};
    for (const r of snap.runways || []) (groups[r.icao] ||= []).push(r.rwy + (r.edit ? "*" : ""));
    const where = Object.entries(groups).map(([i, rs]) => `${i} ${rs.join(", ")}`).join(" · ");
    return h("button", { class: "recent", type: "button", title: "Carregar esta consulta", onclick: () => restore(snap) },
      h("b", { text: planes.length > 2 ? `${planes.slice(0, 2).join(", ")} +${planes.length - 2}` : planes.join(", ") }),
      h("span", { text: where }),
      h("span", { text: summaryOf(snap.conds) }));
  }));
}
function summaryOf(conds) {
  // usa o formulario para descrever um estado salvo sem alterar o atual
  const current = calcForm.getState();
  calcForm.setState(conds);
  const text = calcForm.summary();
  calcForm.setState(current);
  return text;
}
$("#recent-clear").addEventListener("click", () => { save(STORE.recent, []); renderRecents(); });
function flash(sel) {
  const el = $(sel);
  el.animate([{ boxShadow: "0 0 0 0 rgba(30,111,240,.6)" }, { boxShadow: "0 0 0 8px rgba(30,111,240,0)" }], { duration: 600 });
}

// ------------------------------------------------------------------ aeronaves
function renderPlanes() {
  $("#planes").replaceChildren(...state.meta.aircraft.map((a) => {
    const ready = a.variants.filter((v) => v.ready);
    const on = ready.filter((v) => state.planes.has(planeId(a.id, v.id)));
    const all = on.length === ready.length && ready.length > 0;
    return h("div", { class: "plane-row" },
      h("button", {
        class: `model-btn${on.length ? " on" : ""}`, type: "button",
        title: all ? `Desmarcar todos os motores do ${a.name}` : `Marcar todos os motores do ${a.name}`,
        onclick: () => {
          for (const v of ready) {
            const id = planeId(a.id, v.id);
            if (all) state.planes.delete(id); else state.planes.add(id);
          }
          renderPlanes(); updateCalcButton();
        },
      }, a.name, h("small", { text: on.length ? `${on.length} de ${ready.length}` : a.speeds ? "" : "sem V1/VR/V2" })),
      h("div", { class: "pills" }, a.variants.map((v) => h("button", {
        class: "pill", type: "button", disabled: !v.ready, text: v.label,
        title: v.ready ? `Base ${v.database.split(";")[0]}` : `Indisponível: ${v.reason}`,
        "aria-pressed": state.planes.has(planeId(a.id, v.id)),
        onclick: () => { toggleSet(state.planes, planeId(a.id, v.id)); renderPlanes(); updateCalcButton(); },
      }))));
  }));
  const chosen = [...state.planes].map((id) => state.meta.aircraft[id.split(":")[0]]);
  const n = chosen.length;
  $("#planes-count").textContent = String(n);
  $("#planes-count").toggleAttribute("data-zero", !n);
  $("#planes-hint").textContent = chosen.some((a) => !a.speeds) ? "E195 e E195-E2 não informam V1/VR/V2." : "";
  $("#planes-hint").hidden = !$("#planes-hint").textContent;
  calcForm.setCrossNote(n && chosen.every((a) => a.crosswind) ? "O través entra no cálculo dos Airbus selecionados."
    : "O través só entra no cálculo dos Airbus; nas outras aeronaves é ignorado.");
  renderFlaps();
  renderCg();
}

/* Flap por modelo: "Ótimo" (o motor escolhe o de maior MTOW) ou fixo. */
const shortFlap = (label) => label.replace(/^(CONF|FLAP) /, "");
function chosenModels() {
  const ids = new Set([...state.planes].map((id) => +id.split(":")[0]));
  return state.meta.aircraft.filter((a) => ids.has(a.id));
}
const flapsOf = (a) => state.flaps[a.name] || [null];
function toggleFlap(a, code) {
  const cur = flapsOf(a);
  const next = cur.includes(code) ? cur.filter((c) => c !== code) : [...cur, code];
  if (!next.length || (next.length === 1 && next[0] === null)) delete state.flaps[a.name];
  else state.flaps[a.name] = next;
  renderFlaps(); updateCalcButton();
}
function renderFlaps() {
  const models = chosenModels();
  const rows = models.map((a) => {
    if (a.flaps.length < 2) {
      return h("div", { class: "flap-row" }, h("b", { text: a.name }),
        h("span", { class: "muted", text: a.flaps.length ? `${a.flaps[0].label} (único na base)` : "ótimo" }));
    }
    const cur = flapsOf(a);
    const options = [[null, "Ótimo"], ...a.flaps.map((f) => [f.code, shortFlap(f.label)])];
    return h("div", { class: "flap-row" },
      h("b", { text: a.name }, h("small", { text: a.flaps[0].label.split(" ")[0] })),
      h("div", { class: "seg multi", role: "group", "aria-label": `Flap ${a.name}` }, options.map(([code, text]) => h("button", {
        type: "button", text, "aria-pressed": cur.includes(code),
        title: code == null ? "O motor testa os flaps e usa o que dá o maior MTOW"
          : `Calcular também com ${a.flaps.find((f) => f.code === code).label}`,
        onclick: () => toggleFlap(a, code),
      }))));
  });
  $("#calc-flaps").replaceChildren(
    h("div", { class: "cond-head" }, h("span", {}, "Flap",
      h("small", { text: "Marque um ou mais. Ótimo = o motor escolhe o de maior MTOW" }))),
    h("div", { class: "cond-body" }, rows.length ? rows : h("p", { class: "muted", text: "Marque uma aeronave para escolher o flap." })));
}
/* Limite dianteiro de CG por modelo (POPT 30), um ou mais, como os flaps.
 * So as opcoes que a base da aeronave aceita; Standard = o padrao do AFM. */
const cgsOf = (a) => state.cgs[a.name] || [0];
function toggleCg(a, code) {
  const cur = cgsOf(a);
  const next = cur.includes(code) ? cur.filter((c) => c !== code) : [...cur, code];
  const ordered = a.cg.map((c) => c.code).filter((c) => next.includes(c));
  if (!ordered.length || (ordered.length === 1 && ordered[0] === 0)) delete state.cgs[a.name];
  else state.cgs[a.name] = ordered;
  renderCg(); updateCalcButton();
}
function renderCg() {
  const rows = chosenModels().map((a) => {
    if (a.cg.length < 2) {
      return h("div", { class: "flap-row" }, h("b", { text: a.name }),
        h("span", { class: "muted", text: `${a.cg[0].label} (único na base)` }));
    }
    return h("div", { class: "flap-row" }, h("b", { text: a.name }),
      h("div", { class: "seg multi", role: "group", "aria-label": `Limite de CG ${a.name}` }, a.cg.map((c) => h("button", {
        type: "button", text: c.label.replace(" Alternate", " Alt."), "aria-pressed": cgsOf(a).includes(c.code),
        title: `Limite dianteiro de CG: ${c.label} (POPT 30 = ${c.code})`,
        onclick: () => toggleCg(a, c.code),
      }))));
  });
  $("#calc-cg").replaceChildren(
    h("div", { class: "cond-head" }, h("span", {}, "Limite de CG",
      h("small", { text: "Limite dianteiro (POPT 30). Marque um ou mais" }))),
    h("div", { class: "cond-body" }, rows.length ? rows : h("p", { class: "muted", text: "Marque uma aeronave para escolher o limite de CG." })));
}
$("#planes-clear").addEventListener("click", () => { state.planes.clear(); renderPlanes(); updateCalcButton(); });

// ------------------------------------------------------------------ aeroporto / pistas
const search = $("#airport-search"), list = $("#airport-list");
let matches = [], active = -1;
function filterAirports() {
  const q = norm(search.value.trim());
  if (!q) { matches = []; return renderAirportList(); }
  const score = (a) => (a.icao === q || a.iata === q) ? 0 : a.icao.startsWith(q) || a.iata.startsWith(q) ? 1 : 2;
  matches = state.meta.airports
    .filter((a) => a.icao.includes(q) || a.iata.includes(q) || norm(a.name).includes(q))
    .sort((a, b) => score(a) - score(b) || a.icao.localeCompare(b.icao))
    .slice(0, 40);
  active = matches.length ? 0 : -1;
  renderAirportList();
}
function renderAirportList() {
  list.replaceChildren(...matches.map((a, i) => h("li", {
    role: "option", "aria-selected": i === active,
    onmousedown: (e) => { e.preventDefault(); pickAirport(a.icao); },
  }, h("span", { class: "code", text: a.icao }), h("span", { class: "iata", text: a.iata }),
  h("span", { class: "name", text: a.name }))));
  list.hidden = !matches.length;
  search.setAttribute("aria-expanded", String(!list.hidden));
}
search.addEventListener("input", filterAirports);
search.addEventListener("focus", () => { if (search.value) filterAirports(); });
search.addEventListener("blur", () => setTimeout(() => { list.hidden = true; }, 120));
search.addEventListener("keydown", (e) => {
  if (e.key === "ArrowDown" || e.key === "ArrowUp") {
    e.preventDefault();
    if (!matches.length) return;
    active = (active + (e.key === "ArrowDown" ? 1 : -1) + matches.length) % matches.length;
    renderAirportList();
    list.children[active]?.scrollIntoView({ block: "nearest" });
  } else if (e.key === "Enter" && active >= 0) {
    e.preventDefault(); pickAirport(matches[active].icao);
  } else if (e.key === "Escape") { list.hidden = true; }
});

async function getAirport(icao) {
  return state.airports[icao] ||= await api(`/api/airport/${encodeURIComponent(icao)}`);
}
async function pickAirport(icao) {
  list.hidden = true;
  try {
    state.airport = await getAirport(icao);
    search.value = "";
    const recent = [icao, ...load(STORE.airports, []).filter((x) => x !== icao)].slice(0, 8);
    save(STORE.airports, recent);
    renderRecentAirports();
    renderAirportRunways();
  } catch (e) { alert(e.message); }
}
function renderRecentAirports() {
  const recent = load(STORE.airports, []).filter((icao) => state.meta.airports.some((a) => a.icao === icao));
  $("#recent-airports").replaceChildren(...recent.map((icao) => {
    const n = state.runways.filter((r) => r.icao === icao).length;
    return h("button", {
      class: `mini${state.airport?.icao === icao ? " on" : ""}`, type: "button",
      title: `Abrir ${icao}`, text: n ? `${icao} · ${n}` : icao, onclick: () => pickAirport(icao),
    });
  }));
}
const isSelected = (icao, rwy) => state.runways.some((r) => r.icao === icao && r.rwy === rwy);
function toggleRunway(icao, rwy) {
  state.runways = isSelected(icao, rwy) ? state.runways.filter((r) => !(r.icao === icao && r.rwy === rwy))
    : [...state.runways, { icao, rwy }];
}
/** Cabeceira = pista inteira (sem interseção, ex.: "15", "33L"; nao "15/A"). */
const isMain = (rwy) => !rwy.includes("/");
function setAirportRunways(pick) {
  const a = state.airport;
  const kept = Object.fromEntries(state.runways.filter((r) => r.icao === a.icao).map((r) => [r.rwy, r]));
  state.runways = state.runways.filter((r) => r.icao !== a.icao);
  state.runways.push(...a.runways.filter((r) => pick(r.rwy)).map((r) => kept[r.rwy] || { icao: a.icao, rwy: r.rwy }));
  refreshRunways();
}
$("#rw-main").addEventListener("click", () => setAirportRunways(isMain));
$("#runways-all").addEventListener("click", () => setAirportRunways(() => true));
$("#rw-none").addEventListener("click", () => setAirportRunways(() => false));
$("#runways-clear").addEventListener("click", () => { state.runways = []; refreshRunways(); });
function refreshRunways() { renderAirportRunways(); renderSelectedRunways(); renderRecentAirports(); updateCalcButton(); }

function renderAirportRunways() {
  const a = state.airport;
  $("#airport-runways").hidden = !a;
  if (!a) return;
  $("#airport-name").textContent = `${a.icao}${a.iata ? " / " + a.iata : ""} · ${a.name}`;
  $("#airport-meta").textContent = `elev. ${kg(a.runways[0].elev)} ft · ${a.runways.length} pista${a.runways.length > 1 ? "s" : ""}/interseç${a.runways.length > 1 ? "ões" : "ão"}`;
  $("#runways").replaceChildren(...a.runways.map((r) => h("button", {
    class: `pill${isChanged(state.runways.find((x) => x.icao === a.icao && x.rwy === r.rwy) || { icao: a.icao, rwy: r.rwy }) ? " edited" : ""}`,
    type: "button", "aria-pressed": isSelected(a.icao, r.rwy),
    title: `TORA ${kg(r.tora)} · TODA ${kg(r.toda)} · ASDA ${kg(r.asda)} m · largura ${kg(r.width)} m · incl. ${num(r.slope)}% · `
      + `${r.obstacles.length ? `${r.obstacles.length} obstáculo(s)` : "sem obstáculos"} · alinhamento ${r.to_align}`,
    onclick: () => { toggleRunway(a.icao, r.rwy); refreshRunways(); },
  }, r.rwy, h("small", { text: kg(r.tora) }))));
}
function renderSelectedRunways() {
  const groups = {};
  for (const r of state.runways) (groups[r.icao] ||= []).push(r);
  $("#selected-runways").replaceChildren(...Object.entries(groups).map(([icao, rws]) => h("div", { class: "sel-row" },
    h("b", { text: icao }),
    ...rws.map((r) => h("span", { class: `tag${isChanged(r) ? " edited" : ""}`, title: isChanged(r) ? changeText(r) : null }, r.rwy,
      isChanged(r) ? h("small", { class: "flag", text: "editada" }) : null,
      h("button", { type: "button", class: "edit", title: `Editar dados e obstáculos de ${runwayId(r)}`,
        "aria-label": `Editar ${runwayId(r)}`, text: "✎", onclick: () => openRunwayEditor(r) }),
      h("button", { type: "button", title: `Tirar ${runwayId(r)}`, "aria-label": `Tirar ${runwayId(r)}`, text: "×",
        onclick: () => { toggleRunway(r.icao, r.rwy); refreshRunways(); } }))))));
  const n = state.runways.length;
  $("#runways-count").textContent = String(n);
  $("#runways-count").toggleAttribute("data-zero", !n);
  $("#runways-hint").hidden = n > 0 || !!state.airport;
  renderRunwayPanel();
}

// ------------------------------------------------------------------ edicao dos dados da pista
/* Altera so o que vai para o calculo (RWYD 1, 3, 4, 5, 6, 8 e 11), os
 * obstaculos (OBSD) e a reducao da pista fisica. Limites iguais aos de app.py. */
const RW_FIELDS = [
  { key: "elev", label: "RUNWAY ELEVATION", rwyd: "RWYD1", unit: "ft", min: -2000, max: 16000, step: 1 },
  { key: "tora", label: "TORA", rwyd: "RWYD3", unit: "m", min: 100, max: 6000, step: 1 },
  { key: "asda", label: "ASDA", rwyd: "RWYD4", unit: "m", min: 100, max: 6000, step: 1 },
  { key: "toda", label: "TODA", rwyd: "RWYD5", unit: "m", min: 100, max: 8000, step: 1 },
  { key: "slope", label: "SLOPE TODA", rwyd: "RWYD6", unit: "%", min: -5, max: 5, step: 0.01 },
  { key: "surface", label: "RUNWAY SURFACE", rwyd: "RWYD8" },
  { key: "width", label: "RUNWAY WIDTH", rwyd: "RWYD11", unit: "m", min: 10, max: 100, step: 1 },
];
const surfaceOf = (s) => (String(s).toUpperCase().includes("GROOVED") ? "grooved" : "normal");
const surfaceText = (s) => (s === "grooved" ? "Grooved" : "Normal");
const fieldText = (f, v) => (f.key === "surface" ? surfaceText(v) : `${f.key === "slope" ? num(v) : kg(v)} ${f.unit}`);
function editText(edit) {
  const parts = RW_FIELDS.filter((f) => f.key in edit).map((f) => `${f.label} ${fieldText(f, edit[f.key])}`);
  if (edit.obstacles) parts.push(obstText(edit.obstacles));
  return parts.join(" · ");
}

/* Obstaculos da pista no editor: { dist (m, do fim da TORA do cadastro),
 * height (ft), on (entra no calculo), cad (indice no cadastro; null = novo) }.
 * Com o fim da pista fechado, os do cadastro andam junto com o fim da TORA
 * (dist + corte no fim); os novos ja sao digitados a partir do novo fim. */
const MAX_OBST = 15;   // takeoff_data.dat: OBSD(3) ate OBSD(46)
const OBST_LIMITS = { dist: { min: 0, max: 20000, step: 1 }, height: { min: 0, max: 5000, step: 1 } };
const obstFromCad = (list) => list.map(([dist, height], i) => ({ dist, height, on: true, cad: i }));
const obstOn = (list) => list.filter((o) => o.on).length;
const shiftedDist = (o, shift) => (o.cad != null && o.dist != null ? o.dist + shift : o.dist);
const effectiveObstacles = (list, shift) => list.map((o) => ({ ...o, dist: shiftedDist(o, shift) }));
function obstText(list) {
  const on = obstOn(list), added = list.filter((o) => o.cad == null).length;
  return `obstáculos: ${on} de ${list.length} considerados${added ? ` (${added} novo${added > 1 ? "s" : ""})` : ""}`;
}
function obstChanged(list, cad) {
  return list.length !== cad.length || list.some((o, i) => !o.on || o.cad !== i
    || o.dist !== cad[i][0] || o.height !== cad[i][1]);
}

// ------------------------------------------------------------------ pista fisica e reducao
/* A pista fisica vai da cabeceira a (x = 0) a cabeceira b (x = L). Cada pista
 * do cadastro e um sentido dela: as da cabeceira a e suas intersecoes (12,
 * 12/A) decolam para +x; as da b, para -x. A intersecao comeca dentro da pista
 * (TORA da cabeceira - TORA da intersecao) e termina no mesmo fim da TORA.
 * Aproximacao: as duas TORAs comecam nas pontas do pavimento (sem cabeceira
 * deslocada). A reducao e em metros fechados a partir de cada cabeceira e
 * vale para todas as pistas da pista fisica. */
const RWY_RE = /^(\d{2})([LRC]?)(?:\/(.+))?$/;
function oppositeEnd(base) {
  const m = /^(\d{2})([LRC]?)$/.exec(base);
  return String((+m[1] + 17) % 36 + 1).padStart(2, "0") + ({ L: "R", R: "L" }[m[2]] ?? m[2]);
}
function physicalRunway(airport, rwy) {
  const m = RWY_RE.exec(rwy);
  if (!m) return null;
  const [a, b] = [m[1] + m[2], oppositeEnd(m[1] + m[2])].sort();
  const byName = Object.fromEntries(airport.runways.map((r) => [r.rwy, r]));
  const members = airport.runways.filter((r) => {
    const k = RWY_RE.exec(r.rwy);
    return k && [a, b].includes(k[1] + k[2]);
  });
  const L = Math.max(...members.map((r) => r.tora));
  const ways = {};
  for (const r of members) {
    const k = RWY_RE.exec(r.rwy), end = k[1] + k[2], main = byName[end];
    const offset = main ? Math.max(0, main.tora - r.tora) : 0;
    const dir = end === a ? 1 : -1;
    ways[r.rwy] = { rw: r, dir, start: dir > 0 ? offset : L - offset, inter: !!k[3] };
  }
  return { key: `${airport.icao} ${a}-${b}`, a, b, L, ways };
}
/** Rotulo da intersecao no desenho: a letra (15/A -> A), ou o nome inteiro
 * quando a mesma letra existe nos dois sentidos (15/B e 33/B). */
function interLabel(phys, name) {
  const letter = name.split("/")[1];
  return Object.keys(phys.ways).filter((n) => n.split("/")[1] === letter).length > 1 ? name : letter;
}
/** Corte no inicio e no fim da TORA de uma pista e as distancias que sobram. */
function closureCuts(phys, rwy, closure) {
  const w = phys.ways[rwy], r = w.rw;
  const ca = Math.max(0, closure[phys.a] || 0), cb = Math.max(0, closure[phys.b] || 0);
  const toraEnd = w.start + w.dir * r.tora;
  const beg = w.dir > 0 ? Math.max(0, ca - w.start) : Math.max(0, cb - (phys.L - w.start));
  const end = w.dir > 0 ? Math.max(0, toraEnd - (phys.L - cb)) : Math.max(0, ca - toraEnd);
  const tora = Math.max(100, r.tora - beg - end);
  /* Fim fechado: stopway e clearway ficam alem do trecho fechado, entao ASDA
   * e TODA nao passam da nova TORA. Inicio fechado: as tres perdem o trecho. */
  const cut = (d) => Math.max(100, end > 0 ? Math.min(d - beg, tora) : d - beg);
  return { beg, end, tora, asda: cut(r.asda), toda: cut(r.toda) };
}
/** Reducao que vale para uma pista selecionada (null = nenhuma). */
function cutsFor(icao, rwy) {
  const airport = state.airports[icao];
  const phys = airport && physicalRunway(airport, rwy);
  if (!phys || !state.closures[phys.key]) return null;
  const c = closureCuts(phys, rwy, state.closures[phys.key]);
  return c.beg || c.end ? c : null;
}
/** O que vai para o app.py: reducao + edicoes a mao (campos e obstaculos). */
function runwayOverride(item) {
  const cuts = cutsFor(item.icao, item.rwy), edit = item.edit || {};
  const out = cuts ? { tora: cuts.tora, asda: cuts.asda, toda: cuts.toda } : {};
  for (const f of RW_FIELDS) if (f.key in edit) out[f.key] = edit[f.key];
  const shift = cuts?.end || 0;
  if (edit.obstacles || shift) {
    const rw = state.airports[item.icao].runways.find((r) => r.rwy === item.rwy);
    out.obstacles = effectiveObstacles(edit.obstacles || obstFromCad(rw.obstacles), shift);
  }
  return Object.keys(out).length ? out : null;
}
const isChanged = (r) => !!(r.edit || cutsFor(r.icao, r.rwy));
function changeText(r) {
  const cuts = cutsFor(r.icao, r.rwy), parts = [];
  if (cuts) parts.push(`redução: início −${kg(cuts.beg)} m, fim −${kg(cuts.end)} m`);
  if (r.edit) parts.push(editText(r.edit));
  return "Editada: " + parts.join(" · ");
}

// ------------------------------------------------------------------ editor
const editor = $("#rw-editor");
let editing = null;   // { item, airport, orig, phys, closure, obst }
for (const b of editor.querySelectorAll('button[value="cancel"]')) b.formNoValidate = true;
const DIST_KEYS = ["tora", "asda", "toda"];

/** Valores da pista com a reducao (sem as edicoes a mao) e os cortes. */
function editorBase() {
  const { orig, phys, item, closure } = editing;
  const cuts = phys ? closureCuts(phys, item.rwy, closure) : null;
  const values = { ...orig };
  if (cuts) for (const k of DIST_KEYS) values[k] = cuts[k];
  return { values, cuts: cuts && (cuts.beg || cuts.end) ? cuts : null };
}

async function openRunwayEditor(item) {
  let a;
  try { a = await getAirport(item.icao); } catch (e) { return alert(e.message); }
  const rw = a.runways.find((r) => r.rwy === item.rwy);
  if (!rw) return;
  const phys = physicalRunway(a, item.rwy);
  editing = {
    item, airport: a, phys, orig: { ...rw, surface: surfaceOf(rw.surface) },
    closure: { ...(phys && state.closures[phys.key]) },
    obst: (item.edit?.obstacles || obstFromCad(rw.obstacles)).map((o) => ({ ...o })),
  };
  $("#rwe-title").textContent = `Editar pista ${item.icao} ${item.rwy}`;
  $("#rwe-sub").textContent = `${a.name} · ${rw.obstacles.length ? `${rw.obstacles.length} obstáculo(s) do cadastro` : "sem obstáculos no cadastro"}`;
  $("#rwe-closure").hidden = !phys;
  if (phys) {
    $("#rwe-closure-pair").textContent = `· pista ${phys.a}/${phys.b}`;
    for (const side of ["a", "b"]) {
      $(`#rwe-closure [data-thr="${side}"]`).textContent = phys[side];
      $(`#rwe-close-${side}`).value = editing.closure[phys[side]] || "";
      $(`#rwe-close-${side}`).max = phys.L - 100;
    }
  }
  const { values } = editorBase();
  $("#rwe-fields").replaceChildren(...RW_FIELDS.map((f) => {
    const input = f.key === "surface"
      ? h("select", { id: `rwe-${f.key}` }, h("option", { value: "normal", text: "Normal" }), h("option", { value: "grooved", text: "Grooved" }))
      : h("input", { id: `rwe-${f.key}`, type: "number", min: f.min, max: f.max, step: f.step, required: true, inputmode: "decimal" });
    input.value = item.edit?.[f.key] ?? values[f.key];
    input.addEventListener("input", () => { markChanged(); drawRunway(); });
    return h("div", { class: "rwe-field", "data-key": f.key },
      h("label", { for: `rwe-${f.key}`, text: `${f.label} (${f.rwyd})` }),
      h("div", { class: "row" }, input, f.unit ? h("span", { class: "unit", text: f.unit }) : null),
      h("small", { id: `rwe-${f.key}-info` }));
  }));
  syncReduced(false);
  editor.showModal();
  (phys ? $("#rwe-close-a") : $("#rwe-tora")).focus();
}
function editorValues() {
  const out = {};
  for (const f of RW_FIELDS) {
    const el = $(`#rwe-${f.key}`);
    out[f.key] = f.key === "surface" ? el.value : el.value === "" ? null : Number(el.value);
  }
  return out;
}
/** "changed" = editado a mao (difere do valor com a reducao); "reduced" = a
 * reducao mudou o valor do cadastro. */
function markChanged() {
  const v = editorValues(), { values } = editorBase();
  for (const f of RW_FIELDS) {
    const box = $(`.rwe-field[data-key="${f.key}"]`);
    box.classList.toggle("changed", v[f.key] != null && v[f.key] !== values[f.key]);
    box.classList.toggle("reduced", values[f.key] !== editing.orig[f.key]);
    $(`#rwe-${f.key}-info`).textContent = `Cadastro: ${fieldText(f, editing.orig[f.key])}`
      + (values[f.key] !== editing.orig[f.key] ? ` · com redução: ${fieldText(f, values[f.key])}` : "");
  }
}
/** Reducao mudou: TORA/ASDA/TODA que nao foram editadas a mao seguem a
 * reducao; obstaculos, nota e desenho sao refeitos. */
function syncReduced(follow = true) {
  if (follow) {
    const v = editorValues(), { values } = editorBase(), before = editing.lastBase || values;
    for (const k of DIST_KEYS) if (v[k] === before[k]) $(`#rwe-${k}`).value = values[k];
  }
  editing.lastBase = editorBase().values;
  markChanged(); renderClosureNote(); renderObstacles();
}
for (const side of ["a", "b"]) {
  $(`#rwe-close-${side}`).addEventListener("input", (e) => {
    const thr = editing.phys[side], v = Number(e.target.value);
    if (e.target.value === "" || !(v > 0)) delete editing.closure[thr];
    else editing.closure[thr] = v;
    syncReduced();
  });
}
function renderClosureNote() {
  const { phys, item } = editing;
  if (!phys) return;
  const { cuts } = editorBase();
  const others = Object.keys(phys.ways).filter((r) => r !== item.rwy);
  const parts = [h("b", { text: `Pista ${item.rwy}: ` }),
    cuts ? `início da TORA −${kg(cuts.beg)} m · fim da TORA −${kg(cuts.end)} m`
      + (cuts.end ? ` · obstáculos do cadastro +${kg(cuts.end)} m` : "") : "sem redução"];
  if (others.length) parts.push(h("br"), `A mesma redução vale para ${others.join(", ")}.`);
  const tooBig = phys && (editing.closure[phys.a] || 0) + (editing.closure[phys.b] || 0) > phys.L - 100;
  if (tooBig) parts.push(h("br"), h("b", { class: "err", text: `Trecho fechado maior que a pista (${kg(phys.L)} m).` }));
  $("#rwe-closure-note").replaceChildren(...parts);
}

function renderObstacles() {
  const { obst, orig } = editing;
  const cad = orig.obstacles, shift = editorBase().cuts?.end || 0;
  const full = obstOn(obst) >= MAX_OBST;
  const numInput = (o, key, n) => {
    const idx = key === "dist" ? 0 : 1, sh = key === "dist" && o.cad != null ? shift : 0;
    const changed = o.cad != null && o[key] !== cad[o.cad][idx];
    const input = h("input", { type: "number", ...OBST_LIMITS[key], required: true, inputmode: "decimal",
      class: changed ? "changed" : null, "aria-label": `${key === "dist" ? "Distância" : "Altura"} do obstáculo ${n}`,
      title: o.cad == null ? null : key === "dist"
        ? `Cadastro: ${kg(cad[o.cad][0])} m${shift ? ` + ${kg(shift)} m de pista fechada no fim` : ""}`
        : `Cadastro: ${kg(cad[o.cad][1])} ft` });
    input.value = o[key] == null ? "" : o[key] + sh;
    input.addEventListener("input", () => {
      o[key] = input.value === "" ? null : Number(input.value) - sh;
      input.classList.toggle("changed", o.cad != null && o[key] !== cad[o.cad][idx]);
      drawRunway();
    });
    return input;
  };
  $("#rwe-obst").replaceChildren(...obst.map((o, i) => h("tr", { class: `${o.on ? "" : "off"}${o.cad == null ? " new" : ""}`.trim() || null },
    h("td", {}, h("input", { type: "checkbox", checked: o.on, "aria-label": `Considerar o obstáculo ${i + 1}`,
      disabled: !o.on && full, title: !o.on && full ? `Máximo de ${MAX_OBST} obstáculos no cálculo` : null,
      onchange: (e) => { o.on = e.target.checked; renderObstacles(); } })),
    h("td", {}, numInput(o, "dist", i + 1),
      o.cad != null && shift ? h("small", { class: "shift", text: `cad. ${kg(cad[o.cad][0])} + ${kg(shift)}` }) : null),
    h("td", {}, numInput(o, "height", i + 1)),
    h("td", {}, h("span", { class: `src${o.cad == null ? " new" : ""}`, text: o.cad == null ? "Novo" : "Cadastro" })),
    h("td", {}, o.cad == null ? h("button", { type: "button", class: "del", text: "×", title: "Remover este obstáculo",
      "aria-label": `Remover o obstáculo ${i + 1}`, onclick: () => { obst.splice(i, 1); renderObstacles(); } }) : null))));
  const count = $("#rwe-obst-count");
  count.textContent = obst.length ? `${obstOn(obst)}/${obst.length}` : "0";
  count.toggleAttribute("data-zero", !obstOn(obst));
  $("#rwe-obst-empty").hidden = obst.length > 0;
  $(".obst-table").closest(".table-wrap").hidden = !obst.length;
  $("#rwe-obst-add").disabled = full;
  $("#rwe-obst-add").title = full ? `Máximo de ${MAX_OBST} obstáculos no cálculo` : "Incluir um obstáculo que não está no cadastro (distância a partir do fim da TORA atual)";
  $("#rwe-obst-all").disabled = obst.every((o) => o.on) || obst.length > MAX_OBST;
  $("#rwe-obst-none").disabled = !obstOn(obst);
  drawRunway();
}
$("#rwe-obst-add").addEventListener("click", () => {
  editing.obst.push({ dist: null, height: null, on: true, cad: null });
  renderObstacles();
  $("#rwe-obst tr:last-child input[type=number]")?.focus();
});
$("#rwe-obst-all").addEventListener("click", () => { for (const o of editing.obst) o.on = true; renderObstacles(); });
$("#rwe-obst-none").addEventListener("click", () => { for (const o of editing.obst) o.on = false; renderObstacles(); });
$("#rwe-reset").addEventListener("click", () => {
  editing.closure = {};
  for (const side of ["a", "b"]) $(`#rwe-close-${side}`).value = "";
  for (const f of RW_FIELDS) $(`#rwe-${f.key}`).value = editing.orig[f.key];
  editing.obst = obstFromCad(editing.orig.obstacles);
  syncReduced(false);
});
editor.addEventListener("close", () => {
  if (editor.returnValue === "apply" && editing) {
    const v = editorValues(), { values } = editorBase(), edit = {};
    for (const f of RW_FIELDS) if (v[f.key] != null && v[f.key] !== values[f.key]) edit[f.key] = v[f.key];
    if (obstChanged(editing.obst, editing.orig.obstacles)) edit.obstacles = editing.obst;
    const { item, phys, closure } = editing;
    if (phys) {
      const kept = Object.fromEntries(Object.entries(closure).filter(([, m]) => m > 0));
      if (Object.keys(kept).length) state.closures[phys.key] = kept;
      else delete state.closures[phys.key];
    }
    state.runways = state.runways.map((r) => (r.icao === item.icao && r.rwy === item.rwy
      ? (Object.keys(edit).length ? { icao: r.icao, rwy: r.rwy, edit } : { icao: r.icao, rwy: r.rwy }) : r));
    refreshRunways();
  }
  editor.returnValue = "";
  editing = null;
});

// ------------------------------------------------------------------ desenho da pista
/* Vista de cima (pista fisica em escala, trechos fechados, TORA/ASDA/TODA da
 * pista editada, intersecoes) e perfil dos obstaculos (distancia a partir do
 * fim da TORA x altura). Refeito a cada mudanca no editor. */
const REF_STORE = "perf.rweRef";
const svgClear = (svg, w, hgt) => { svg.setAttribute("viewBox", `0 0 ${w} ${hgt}`); svg.replaceChildren(); return svg; };
function drawRunway() {
  if (!editing) return;
  drawPlan();
  drawProfile();
}
function drawPlan() {
  const W = 560, H = 168, pad = 32;
  const svg = svgClear($("#rwe-plan"), W, H);
  const { phys, item, closure } = editing;
  const v = editorValues(), { cuts } = editorBase();
  const way = phys ? phys.ways[item.rwy] : { dir: 1, start: 0 };
  const L = phys ? phys.L : editing.orig.tora;
  const dir = way.dir, s0 = way.start + dir * (cuts?.beg || 0);
  const ends = ["tora", "asda", "toda"].map((k) => s0 + dir * (v[k] || 0));
  const lo = Math.min(0, s0, ...ends), hi = Math.max(L, s0, ...ends);
  const sx = (x) => pad + (x - lo) / (hi - lo || 1) * (W - 2 * pad);
  const defs = s("defs", {}, s("pattern", { id: "rwe-hatch", width: 7, height: 7, patternUnits: "userSpaceOnUse", patternTransform: "rotate(45)" },
    s("rect", { width: 7, height: 7, class: "hatch-bg" }), s("line", { x1: 0, y1: 0, x2: 0, y2: 7, class: "hatch-line" })));
  svg.append(defs);
  // pavimento, eixo e cabeceiras
  svg.append(s("rect", { x: sx(0), y: 34, width: sx(L) - sx(0), height: 26, rx: 3, class: "rw-strip" }),
    s("line", { x1: sx(0) + 6, y1: 47, x2: sx(L) - 6, y2: 47, class: "rw-center" }));
  if (phys) {
    svg.append(s("text", { x: sx(0) - 5, y: 52, class: "rw-thr", "text-anchor": "end", text: phys.a }),
      s("text", { x: sx(L) + 5, y: 52, class: "rw-thr", "text-anchor": "start", text: phys.b }));
    // trechos fechados
    for (const [thr, from] of [[phys.a, 0], [phys.b, L]]) {
      const m = Math.min(closure[thr] || 0, L);
      if (!m) continue;
      const x1 = sx(from === 0 ? 0 : L - m), x2 = sx(from === 0 ? m : L);
      svg.append(s("rect", { x: x1, y: 34, width: x2 - x1, height: 26, class: "rw-closed" }),
        s("text", { x: (x1 + x2) / 2, y: 26, class: "rw-closed-label", "text-anchor": "middle", text: `fechado ${kg(m)} m` }));
    }
    // intersecoes: marca no ponto de entrada
    for (const [name, w] of Object.entries(phys.ways)) {
      if (!w.inter) continue;
      const x = sx(w.start);
      svg.append(s("line", { x1: x, y1: 34, x2: x, y2: 66, class: "rw-inter" }),
        s("text", { x, y: 76, class: `rw-inter-label${name === item.rwy ? " on" : ""}`, "text-anchor": "middle", text: interLabel(phys, name) }));
    }
  }
  // seta do sentido da decolagem da pista editada
  const ax = sx(s0), tip = ax + dir * 22;
  svg.append(s("path", { d: `M${ax} 47 L${tip} 47 M${tip - dir * 7} 41 L${tip} 47 L${tip - dir * 7} 53`, class: "rw-arrow" }));
  // TORA / ASDA / TODA
  const bars = [["TORA", v.tora, 96, 8], ["ASDA", v.asda, 122, 4], ["TODA", v.toda, 146, 4]];
  for (const [label, len, y, th] of bars) {
    if (!len) continue;
    const x1 = sx(s0), x2 = sx(s0 + dir * len), xt = sx(s0 + dir * Math.min(len, v.tora || len));
    svg.append(s("line", { x1, y1: y, x2: xt, y2: y, class: `rw-bar ${label.toLowerCase()}`, "stroke-width": th }));
    if (Math.abs(x2 - xt) > 0.5) svg.append(s("line", { x1: xt, y1: y, x2, y2: y, class: "rw-bar ext", "stroke-width": th }));
    for (const x of [x1, x2]) svg.append(s("line", { x1: x, y1: y - 6, x2: x, y2: y + 6, class: "rw-tick" }));
    svg.append(s("text", { x: (x1 + x2) / 2, y: y - 7, class: "rw-bar-label", "text-anchor": "middle", text: `${label} ${kg(len)} m` }));
  }
}
function drawProfile() {
  const W = 560, H = 230, l = 46, r = 14, t = 16, b = 40;
  const svg = svgClear($("#rwe-profile"), W, H);
  const v = editorValues(), shift = editorBase().cuts?.end || 0;
  const obst = editing.obst.map((o, i) => ({ ...o, i, d: shiftedDist(o, shift) })).filter((o) => o.d != null && o.height != null);
  const ext = Math.max(0, (v.toda || 0) - (v.tora || 0));          // clearway
  const showRef = $("#rwe-ref").checked;
  const refH = (d) => 35 + Math.max(0, d - ext) * 0.016 * 3.2808;  // ft
  const maxD = Math.max(1000, ext * 1.5, ...obst.map((o) => o.d)) * 1.04;
  // escala: linear ate D0 (62% da largura), comprimida (log) depois
  const D0 = 2000, linear = maxD <= D0 * 1.25;
  const fx = (d) => l + (W - l - r) * (linear ? d / maxD
    : d <= D0 ? 0.62 * d / D0 : 0.62 + 0.38 * Math.log(d / D0) / Math.log(maxD / D0));
  const maxH = Math.max(100, ...obst.map((o) => o.height)) * 1.2;
  const fy = (hgt) => H - b - (H - b - t) * Math.min(hgt, maxH) / maxH;
  // grade e eixos
  const hStep = [25, 50, 100, 200, 250, 500].find((st) => maxH / st <= 6) || 1000;
  for (let hh = 0; hh <= maxH; hh += hStep) {
    svg.append(s("line", { x1: l, y1: fy(hh), x2: W - r, y2: fy(hh), class: "pf-grid" }),
      s("text", { x: l - 6, y: fy(hh) + 4, class: "pf-tick", "text-anchor": "end", text: kg(hh) }));
  }
  const dStep = maxD <= 1500 ? 250 : 500;
  const ticks = [];
  for (let d = 0; d <= Math.min(maxD, linear ? maxD : D0); d += dStep) ticks.push(d);
  if (!linear) for (const d of [5000, 10000, 15000, 20000]) if (d < maxD) ticks.push(d);
  for (const d of ticks) {
    svg.append(s("line", { x1: fx(d), y1: H - b, x2: fx(d), y2: H - b + 4, class: "pf-axis" }),
      s("text", { x: fx(d), y: H - b + 16, class: "pf-tick", "text-anchor": "middle", text: d >= 1000 && d % 1000 === 0 && d > D0 ? `${d / 1000} km` : kg(d) }));
  }
  if (!linear) svg.append(s("text", { x: fx(D0) + 6, y: t + 10, class: "pf-note", text: "escala comprimida →" }),
    s("line", { x1: fx(D0), y1: t, x2: fx(D0), y2: H - b, class: "pf-break" }));
  svg.append(s("line", { x1: l, y1: H - b, x2: W - r, y2: H - b, class: "pf-axis" }),
    s("line", { x1: l, y1: t, x2: l, y2: H - b, class: "pf-axis" }),
    s("text", { x: l - 6, y: t - 4, class: "pf-tick", "text-anchor": "end", text: "ft" }),
    s("text", { x: W - r, y: H - 6, class: "pf-tick", "text-anchor": "end", text: "m depois do fim da TORA" }),
    s("text", { x: l + 4, y: H - b - 6, class: "pf-note", text: "fim da TORA" }));
  if (ext > 0) svg.append(s("line", { x1: fx(ext), y1: t, x2: fx(ext), y2: H - b, class: "pf-toda" }),
    s("text", { x: fx(ext) + 4, y: t + 22, class: "pf-note", text: "fim da TODA" }));
  if (showRef) {
    const pts = [];
    for (let k = 0; k <= 80; k++) {
      const d = ext + (maxD - ext) * k / 80;
      if (refH(d) > maxH) break;
      pts.push(`${fx(d).toFixed(1)},${fy(refH(d)).toFixed(1)}`);
    }
    svg.append(s("polyline", { points: pts.join(" "), class: "pf-ref" }));
  }
  if (!obst.length) svg.append(s("text", { x: (l + W - r) / 2, y: (t + H - b) / 2, class: "pf-note", "text-anchor": "middle", text: "Sem obstáculos" }));
  for (const o of obst) {
    const x = fx(o.d), y0 = fy(0), y1 = fy(o.height);
    const warn = showRef && o.on && o.height + 35 > refH(o.d);
    const cls = `pf-obst${o.on ? "" : " off"}${o.cad == null ? " new" : ""}${warn ? " warn" : ""}`;
    const tri = s("path", { d: `M${x - 5} ${y0} L${x} ${y1} L${x + 5} ${y0} Z`, class: cls,
      onclick: () => $(`#rwe-obst tr:nth-child(${o.i + 1}) input[type=number]`)?.focus() },
      s("title", { text: `Obstáculo ${o.i + 1}: ${kg(o.d)} m${o.cad != null && shift ? ` (cadastro ${kg(o.dist)} + ${kg(shift)})` : ""} · ${kg(o.height)} ft · `
        + `${o.cad == null ? "novo" : "cadastro"}${o.on ? "" : " · fora do cálculo"}${warn ? " · acima da referência" : ""}` }));
    svg.append(tri);
    if (obst.length <= 8 && o.on) svg.append(s("text", { x, y: y1 - 4, class: "pf-label", "text-anchor": "middle", text: kg(o.height) }));
  }
}
try { $("#rwe-ref").checked = localStorage.getItem(REF_STORE) === "1"; } catch (e) { /* sem storage */ }
$("#rwe-ref").addEventListener("change", (e) => {
  try { localStorage.setItem(REF_STORE, e.target.checked ? "1" : "0"); } catch (err) { /* sem storage */ }
  drawProfile();
});

// ------------------------------------------------------------------ painel das pistas (tela principal)
/* Um cartao por pista fisica selecionada, assim que a pista e marcada: vista
 * lateral com a reducao, os sentidos selecionados e os obstaculos de cada
 * sentido depois do fim da TORA (fora da pista, distancia comprimida). */
const panelLoading = new Set();
const PANEL_STORE = "perf.rwPanelCollapsed";
let sideUid = 0;
/** Pista como vai para o calculo: reducao + edicoes; obstaculos considerados. */
function effectiveRunway(item) {
  const rw = state.airports[item.icao].runways.find((r) => r.rwy === item.rwy);
  const ov = runwayOverride(item) || {};
  const obst = (ov.obstacles || obstFromCad(rw.obstacles)).filter((o) => o.on && o.dist != null && o.height != null);
  return { rw, cuts: cutsFor(item.icao, item.rwy), tora: ov.tora ?? rw.tora, asda: ov.asda ?? rw.asda, toda: ov.toda ?? rw.toda, obst };
}
function renderRunwayPanel() {
  const panel = $("#rw-panel");
  for (const icao of new Set(state.runways.map((r) => r.icao))) {
    if (state.airports[icao] || panelLoading.has(icao)) continue;
    panelLoading.add(icao);
    getAirport(icao).then(() => renderSelectedRunways()).catch(() => {}).finally(() => panelLoading.delete(icao));
  }
  const groups = new Map();       // pista fisica -> { airport, phys, items }
  for (const item of state.runways) {
    const airport = state.airports[item.icao];
    if (!airport || !airport.runways.some((r) => r.rwy === item.rwy)) continue;
    const phys = physicalRunway(airport, item.rwy);
    const key = phys ? phys.key : `${item.icao} ${item.rwy}`;
    if (!groups.has(key)) groups.set(key, { airport, phys, items: [] });
    groups.get(key).items.push(item);
  }
  panel.hidden = !groups.size;
  let collapsed = false;
  try { collapsed = localStorage.getItem(PANEL_STORE) === "1"; } catch (e) { /* sem storage */ }
  panel.classList.toggle("collapsed", collapsed);
  panel.replaceChildren(...(groups.size ? [
    h("header", { class: "rw-panel-head" }, h("h2", { text: `Pistas selecionadas (${groups.size})` }),
      h("small", { class: "muted", text: "Vista lateral em escala; fora da pista a distância é comprimida. ✎ edita a redução, os dados e os obstáculos." }),
      h("span", { class: "grow" }),
      h("button", { type: "button", class: "link", "aria-expanded": !collapsed, text: collapsed ? "Mostrar" : "Recolher",
        onclick: () => {
          try { localStorage.setItem(PANEL_STORE, collapsed ? "0" : "1"); } catch (e) { /* sem storage */ }
          renderRunwayPanel();
        } })),
    ...[...groups.values()].map(physCard)] : []));
}
function physCard({ airport, phys, items }) {
  const eff = items.map((it) => ({ it, ...effectiveRunway(it) }));
  return h("article", { class: "rw-card" },
    h("div", { class: "rw-card-head" },
      h("b", { text: `${airport.icao}${airport.iata ? " / " + airport.iata : ""}` }),
      h("span", { class: "muted", text: phys ? `pista ${phys.a}/${phys.b} · ${kg(phys.L)} m` : `pista ${items[0].rwy}` }),
      h("span", { class: "grow" }),
      ...items.map((it) => h("button", { type: "button", class: `mini${isChanged(it) ? " edited" : ""}`,
        title: `Editar ${runwayId(it)}${isChanged(it) ? ` (${changeText(it)})` : ""}`, text: `✎ ${it.rwy}`, onclick: () => openRunwayEditor(it) }))),
    drawSideView(phys, eff),
    h("div", { class: "rw-card-data" }, ...eff.map((e) => h("span", { class: isChanged(e.it) ? "edited" : null },
      h("b", { text: e.it.rwy }), ` TORA ${kg(e.tora)} · ASDA ${kg(e.asda)} · TODA ${kg(e.toda)} m`
      + (e.cuts ? ` · redução −${kg(e.cuts.beg + e.cuts.end)} m` : "")
      + ` · ${e.obst.length ? `${e.obst.length} obstáculo${e.obst.length > 1 ? "s" : ""}` : "sem obstáculos"}`))));
}
function drawSideView(phys, eff) {
  const W = 900, H = 136, pad = 18, GY = 98, K = 250;
  const svg = s("svg", { viewBox: `0 0 ${W} ${H}`, class: "rw-side", role: "img", "aria-label": "Pista e obstáculos, vista lateral" });
  const L = phys ? phys.L : eff[0].rw.tora;
  const xl = W * 0.24, xr = W * 0.76;
  // obstaculos na coordenada da pista fisica (0 = cabeceira a)
  const pts = [];
  for (const e of eff) {
    const w = phys ? phys.ways[e.it.rwy] : { dir: 1, start: 0 };
    e.dir = w.dir;
    e.start = w.start + w.dir * (e.cuts?.beg || 0);
    const toraEnd = e.start + w.dir * e.tora;
    for (const o of e.obst) pts.push({ x: toraEnd + w.dir * o.dist, o, e });
  }
  const beyondR = Math.max(1, ...pts.map((p) => p.x - L)), beyondL = Math.max(1, ...pts.map((p) => -p.x));
  const sx = (x) => (x < 0 ? xl - (xl - pad) * Math.log1p(-x / K) / Math.log1p(beyondL / K)
    : x > L ? xr + (W - pad - xr) * Math.log1p((x - L) / K) / Math.log1p(beyondR / K)
      : xl + (xr - xl) * x / L);
  const maxH = Math.max(100, ...pts.map((p) => p.o.height));
  const hy = (ft) => GY - 60 * ft / maxH;
  const hatch = `rw-hatch-${++sideUid}`;
  svg.append(s("defs", {}, s("pattern", { id: hatch, width: 7, height: 7, patternUnits: "userSpaceOnUse", patternTransform: "rotate(45)" },
    s("rect", { width: 7, height: 7, class: "hatch-bg" }), s("line", { x1: 0, y1: 0, x2: 0, y2: 7, class: "hatch-line" }))));
  svg.append(s("line", { x1: pad, y1: GY, x2: W - pad, y2: GY, class: "pf-axis" }),
    s("rect", { x: sx(0), y: GY - 9, width: sx(L) - sx(0), height: 9, class: "rw-strip" }));
  if (phys) {
    const closure = state.closures[phys.key] || {};
    for (const [thr, atStart] of [[phys.a, true], [phys.b, false]]) {
      const m = Math.min(closure[thr] || 0, L);
      if (!m) continue;
      const x1 = sx(atStart ? 0 : L - m), x2 = sx(atStart ? m : L);
      svg.append(s("rect", { x: x1, y: GY - 9, width: x2 - x1, height: 9, fill: `url(#${hatch})`, class: "rw-closed-p" }),
        s("text", { x: (x1 + x2) / 2, y: GY + 28, class: "rw-closed-label", "text-anchor": "middle", text: `fechado ${kg(m)} m` }));
    }
    svg.append(s("text", { x: sx(0), y: GY + 16, class: "rw-thr", "text-anchor": "middle", text: phys.a }),
      s("text", { x: sx(L), y: GY + 16, class: "rw-thr", "text-anchor": "middle", text: phys.b }));
    for (const [name, w] of Object.entries(phys.ways)) {
      if (!w.inter) continue;
      svg.append(s("line", { x1: sx(w.start), y1: GY - 12, x2: sx(w.start), y2: GY + 3, class: "rw-inter" }),
        s("text", { x: sx(w.start), y: GY + 15, class: "rw-inter-label", "text-anchor": "middle", text: interLabel(phys, name) }));
    }
  }
  // setas dos sentidos selecionados (acima da pista)
  for (const e of eff) {
    const x = sx(e.start), y = e.dir > 0 ? GY - 22 : GY - 36, tip = x + e.dir * 26;
    svg.append(s("path", { d: `M${x} ${y} L${tip} ${y} M${tip - e.dir * 6} ${y - 5} L${tip} ${y} L${tip - e.dir * 6} ${y + 5}`, class: "rw-arrow" }),
      s("text", { x: tip + e.dir * 4, y: y + 4, class: "rw-bar-label", "text-anchor": e.dir > 0 ? "start" : "end", text: e.it.rwy }));
  }
  // obstaculos (rotulo da altura so quando nao encosta no vizinho; sempre no tooltip)
  const labels = [];
  for (const p of [...pts].sort((u, v) => v.o.height - u.o.height)) {
    const x = sx(p.x), y1 = hy(p.o.height);
    svg.append(s("path", { d: `M${x - 4} ${GY} L${x} ${y1} L${x + 4} ${GY} Z`, class: `pf-obst${p.o.cad == null ? " new" : ""}`,
      onclick: () => openRunwayEditor(p.e.it) },
      s("title", { text: `${p.e.it.rwy}: obstáculo a ${kg(p.o.dist)} m do fim da TORA · ${kg(p.o.height)} ft${p.o.cad == null ? " · novo" : ""}` })));
    if (labels.some((q) => Math.abs(q.x - x) < 22 && Math.abs(q.y - y1) < 14)) continue;
    labels.push({ x, y: y1 });
    svg.append(s("text", { x, y: y1 - 4, class: "pf-label", "text-anchor": "middle", text: kg(p.o.height) }));
  }
  if (!pts.length) svg.append(s("text", { x: W / 2, y: 22, class: "pf-note", "text-anchor": "middle", text: "sem obstáculos nas pistas selecionadas" }));
  return svg;
}

// ------------------------------------------------------------------ calculo
const calcBtn = $("#calc-btn");
const calcForm = conditionsForm($("#calc-conditions"), { onEnter: () => runCalc(), onChange: () => updateCalcButton() });
const busy = () => calcBtn.dataset.busy === "1";
/** Aeronaves x flaps x CG: cada motor marcado conta uma vez por flap e por
 * limite de CG escolhidos. */
function planeUnits() {
  return [...state.planes].reduce((sum, id) => {
    const a = state.meta.aircraft[id.split(":")[0]];
    return sum + flapsOf(a).length * cgsOf(a).length;
  }, 0);
}
function totalCount() {
  const n = calcForm.count();
  return n == null ? null : n * planeUnits() * state.runways.length;
}
function updateCalcButton() {
  if (!state.meta) return;
  const n = calcForm.count(), p = state.planes.size, r = state.runways.length;
  const info = $("#calc-count");
  info.classList.remove("warn");
  const u = p ? planeUnits() : 0;
  const total = n == null ? null : n * u * r;
  if (!p || !r || n == null) {
    info.textContent = !p ? "Marque pelo menos uma aeronave." : !r ? "Marque pelo menos uma pista." : "Confira os valores das faixas.";
    info.classList.add("warn");
    calcBtn.textContent = "Calcular";
  } else {
    const planes = u === p ? `${p} aeronave${p > 1 ? "s" : ""}` : `${u} aeronave${u > 1 ? "s" : ""}/flap${u > 1 ? "s" : ""}/CG`;
    info.replaceChildren(`${planes} × ${r} pista${r > 1 ? "s" : ""} × ${nfKg.format(n)} combinaç${n > 1 ? "ões" : "ão"} = `,
      h("b", { text: `${nfKg.format(total)} cálculo${total > 1 ? "s" : ""}` }));
    calcBtn.textContent = busy() ? "Calculando…" : `Calcular ${nfKg.format(total)}`;
  }
  calcBtn.disabled = !p || !r || n == null || busy();
  // passo a passo: some na primeira selecao (e nao volta nesta sessao)
  if (p || r) state.guideDone = true;
  if (state.guideDone) $("#calc-empty").hidden = true;
  rememberLast();
}
calcBtn.addEventListener("click", runCalc);
document.addEventListener("keydown", (e) => {
  if ((e.ctrlKey || e.metaKey) && e.key === "Enter" && !$("#page-calc").hidden) { e.preventDefault(); runCalc(); }
});

function showOnly(id) {
  for (const x of ["calc-empty", "calc-loading", "calc-error", "calc-result"]) $(`#${x}`).hidden = x !== id;
}
function showCalcError(message) {
  $("#calc-error").replaceChildren(h("strong", { text: "Não foi possível calcular" }), message);
  showOnly("calc-error");
}

async function runCalc() {
  if (calcBtn.disabled) return;
  const total = totalCount();
  if (total > 300 && !confirm(`São ${nfKg.format(total)} cálculos. Calcular mesmo assim?`)) return;
  try {                     // a reducao de pista precisa dos dados de cada aeroporto
    await Promise.all([...new Set(state.runways.map((r) => r.icao))].map(getAirport));
  } catch (e) { return showCalcError(e.message); }
  const body = {
    selection: [...state.planes].map((id) => { const [i, j] = id.split(":"); return { aircraft: +i, variant: +j }; }),
    runways: state.runways.map((r) => ({ icao: r.icao, rwy: r.rwy, override: runwayOverride(r) })), ...calcForm.spec(),
    flaps: Object.fromEntries(chosenModels().filter((a) => a.name in state.flaps).map((a) => [a.name, state.flaps[a.name]])),
    cg: Object.fromEntries(chosenModels().filter((a) => a.name in state.cgs).map((a) => [a.name, state.cgs[a.name]])),
  };
  addRecent();
  calcBtn.dataset.busy = "1"; updateCalcButton();
  $("#calc-progress").style.width = "0";
  $("#calc-loading-text").textContent = "Calculando…";
  $("#calc-loading-sub").textContent = "Os motores rodam em paralelo na sua máquina.";
  showOnly("calc-loading");
  window.scrollTo({ top: 0 });
  const t0 = Date.now();
  try {
    const started = await api("/api/calc", body);
    const job = await pollJob(started.id, (j) => {
      if (!j.total) return;
      $("#calc-progress").style.width = `${(100 * j.done) / j.total}%`;
      $("#calc-loading-text").textContent = j.total > 1 ? `Calculando ${nfKg.format(j.done)} de ${nfKg.format(j.total)}` : "Calculando…";
      if (j.done > 3 && j.done < j.total) {
        const left = ((Date.now() - t0) / j.done) * (j.total - j.done) / 1000;
        $("#calc-loading-sub").textContent = left > 90 ? `Faltam cerca de ${Math.round(left / 60)} min.` : `Faltam cerca de ${Math.max(1, Math.round(left))} s.`;
      }
    });
    if (job.state === "error") throw new Error(job.error);
    state.result = prepareResult(job.result);
    renderResult();
  } catch (e) {
    showCalcError(e.message);
  } finally {
    calcBtn.dataset.busy = ""; updateCalcButton();
  }
}

// ------------------------------------------------------------------ resultado
/* Dimensoes do resultado: aeronave e pista (categoricas, na ordem escolhida)
 * e temperatura, vento e QNH (numericas, ordenadas). */
const DIM = {
  plane: { label: "Aeronave", cat: true, of: (r) => r.plane, text: (v) => v, short: (v) => v },
  runway: { label: "Pista", cat: true, of: (r) => r.runway, text: (v) => v, short: (v) => v },
  temp: { label: "Temperatura", axis: "Temperatura (°C)", of: (r) => r.temp, text: (v) => tempText(v), short: (v) => plain(v) },
  wind: { label: "Vento", axis: "Vento (kt) · negativo = cauda", of: (r) => r.wind, text: (v) => windText(v), short: (v) => plain(v) },
  qnh: { label: "QNH", axis: "QNH (hPa)", of: (r) => r.qnh, text: (v) => `QNH ${qnhText(v)}`, short: (v) => qnhText(v) },
};
const DIM_KEYS = ["plane", "runway", "temp", "wind", "qnh"];
const PREFERRED = { temp: 15, wind: 0, qnh: 1013.25 };
const closest = (values, target) => values.reduce((a, b) => (Math.abs(b - target) < Math.abs(a - target) ? b : a));

function prepareResult(res) {
  res.values = {
    plane: res.planes.map((p) => p.key),
    runway: res.runways.map((r) => r.key),
    temp: uniq(res.rows.map((r) => r.temp)),
    wind: uniq(res.rows.map((r) => r.wind)),
    qnh: uniq(res.rows.map((r) => r.qnh)),
  };
  res.speedsOf = Object.fromEntries(res.planes.map((p) => [p.key, p.speeds]));
  res.anySpeeds = res.planes.some((p) => p.speeds);
  res.varying = DIM_KEYS.filter((k) => res.values[k].length > 1);
  return res;
}
const speedText = (r) => (state.result.speedsOf[r.plane] ? ` · V1 ${v1Text(r)} / VR ${speed(r.vr)} / V2 ${speed(r.v2)}` : "");
function where(r, skip = []) {
  const res = state.result, parts = [];
  if (res.values.plane.length > 1 && !skip.includes("plane")) parts.push(r.plane);
  if (res.values.runway.length > 1 && !skip.includes("runway")) parts.push(r.runway);
  if (!skip.includes("temp")) parts.push(tempText(r.temp));
  if (!skip.includes("wind")) parts.push(windText(r.wind, r.crosswind));
  if (!skip.includes("qnh")) parts.push(`QNH ${qnhText(r.qnh)}`);
  return parts.join(", ");
}
function runwaysTextOf(rws) {
  const groups = {};
  for (const r of rws) (groups[r.icao] ||= []).push(r.rwy + (r.edited ? " (editada)" : ""));
  return Object.entries(groups).map(([icao, list]) => `${icao} ${list.join(", ")}`).join(" · ");
}
function describeConditions(res) {
  const v = res.values, r0 = res.rows[0];
  return [
    v.temp.length > 1 ? `${plain(v.temp[0])} a ${plain(v.temp.at(-1))} °C` : tempText(v.temp[0]),
    v.wind.length > 1 ? `vento ${plain(v.wind[0])} a ${plain(v.wind.at(-1))} kt` : windText(r0.wind, r0.crosswind),
    v.qnh.length > 1 ? `QNH ${qnhText(v.qnh[0])} a ${qnhText(v.qnh.at(-1))} hPa` : `QNH ${qnhText(v.qnh[0])} hPa`,
  ].join(" · ");
}

function renderResult() {
  const res = state.result;
  const p = res.planes, rw = res.runways;
  const airports = [...new Set(rw.map((r) => r.icao))];
  $("#r-title").textContent = rw.length === 1 ? `${rw[0].icao} · pista ${rw[0].rwy}${rw[0].edited ? " (editada)" : ""} · ${rw[0].airport}`
    : airports.length === 1 ? `${rw[0].icao} · ${rw.length} pistas · ${rw[0].airport}` : `${rw.length} pistas em ${airports.length} aeroportos`;
  const tag = (label, value) => h("span", {}, label, h("b", { text: value }));
  $("#r-tags").replaceChildren(
    (() => {      // aeronave = motor; os flaps de um mesmo motor nao contam de novo
      const engines = [...new Set(p.map((x) => `${x.aircraft} ${x.engine}`))];
      return tag(engines.length === 1 ? "Aeronave" : `${engines.length} aeronaves`,
        engines.length === 1 ? engines[0] : [...new Set(p.map((x) => x.aircraft))].join(", "));
    })(),
    ...(rw.length > 1 ? [tag("Pistas", runwaysTextOf(rw))] : []),
    ...(p.some((x) => x.flap) ? [tag("Flaps", Object.entries(p.filter((x) => x.flap).reduce((acc, x) => {
      (acc[x.aircraft] ||= new Set()).add(x.flap.replace("Flap ótimo", "ótimo")); return acc;
    }, {})).map(([ac, s]) => `${ac} ${[...s].join(", ")}`).join(" · "))] : []),
    ...(p.some((x) => x.cg) ? [tag("Limite de CG", Object.entries(p.filter((x) => x.cg).reduce((acc, x) => {
      (acc[x.aircraft] ||= new Set()).add(x.cg.replace(/^CG /, "")); return acc;
    }, {})).map(([ac, s]) => `${ac} ${[...s].join(", ")}`).join(" · "))] : []),
    ...rw.filter((r) => r.edited).map((r) => h("span", { class: "edited" }, `${r.icao} ${r.rwy} editada: `,
      h("b", { text: `TORA ${kg(r.data.tora)} · ASDA ${kg(r.data.asda)} · TODA ${kg(r.data.toda)} m · elev. ${kg(r.data.elev)} ft · `
        + `slope ${num(r.data.slope)}% · ${surfaceText(surfaceOf(r.data.surface))} · largura ${kg(r.data.width)} m · `
        + (r.data.obstacles.length ? `${r.data.obstacles.length} obstáculo(s): `
          + r.data.obstacles.map(([d, ht]) => `${kg(d)} m/${kg(ht)} ft`).join(", ") : "sem obstáculos") }))),
    ...describeConditions(res).split(" · ").map((part) => h("span", { text: part })),
    tag("Cálculos", nfKg.format(res.rows.length)));
  $("#r-csv").href = fileUrl(res.csv);
  const single = res.rows.length === 1;
  $("#r-hero").hidden = !single;
  $("#r-kpis").hidden = single;
  $("#r-views").hidden = single;
  showOnly("calc-result");
  window.scrollTo({ top: 0 });
  if (single) return renderHero(res.rows[0]);

  const ok = res.rows.filter((r) => !r.error), errors = res.rows.length - ok.length;
  const kpi = (label, value, unit, note) => h("dl", { class: "kpi" },
    h("dt", { text: label }), h("dd", {}, value, unit ? h("small", { text: unit }) : null),
    note ? h("p", { text: note }) : null);
  if (ok.length && p.length > 1) {
    // aeronaves de portes diferentes: um cartao por aeronave
    const cards = p.slice(0, 6).map((plane) => {
      const mine = ok.filter((r) => r.plane === plane.key);
      if (!mine.length) return kpi(plane.key, "–", null, "nenhum cálculo deu certo");
      const hi = mine.reduce((a, b) => (b.mtow > a.mtow ? b : a));
      const lo = mine.reduce((a, b) => (b.mtow < a.mtow ? b : a));
      return h("dl", { class: "kpi" }, h("dt", { text: plane.key }),
        h("dd", {}, kg(hi.mtow), h("small", { text: "kg" })),
        h("p", {}, "Menor ", h("b", { text: `${kg(lo.mtow)} kg` }), ` · ${where(lo, ["plane"])}`));
    });
    if (errors) cards.push(kpi("Erros", nfKg.format(errors), null, "veja a lista"));
    $("#r-kpis").replaceChildren(...cards);
  } else if (ok.length) {
    const hi = ok.reduce((a, b) => (b.mtow > a.mtow ? b : a));
    const lo = ok.reduce((a, b) => (b.mtow < a.mtow ? b : a));
    $("#r-kpis").replaceChildren(
      kpi("Maior MTOW", kg(hi.mtow), "kg", where(hi)),
      kpi("Menor MTOW", kg(lo.mtow), "kg", `${where(lo)} · ${lo.limit_text.toLowerCase()}`),
      kpi("Cálculos", nfKg.format(res.rows.length), null, errors ? `${errors} com erro (veja a lista)` : "todos concluídos"));
  } else {
    $("#r-kpis").replaceChildren(kpi("Cálculos", nfKg.format(res.rows.length), null, "nenhum deu certo — veja a lista"));
  }
  // abas: Tabela RTOW (principal), Grafico (se temperatura/vento/QNH variam), Lista
  const avail = { rtow: true, chart: res.varying.some((k) => !DIM[k].cat), list: true };
  document.querySelectorAll(".view-tabs button").forEach((b) => { b.hidden = !avail[b.dataset.view]; });
  state.view = "rtow";
  state.avail = avail;
  initChartState();
  state.rtow = { plane: "all", runway: "all" };
  renderViews();
}

function renderHero(r) {
  const hero = $("#r-hero");
  if (r.error) {
    hero.replaceChildren(h("div", { class: "error-box" }, h("strong", { text: "O motor devolveu erro" }), r.error));
    return;
  }
  const tile = (label, value, cls) => h("dl", { class: `tile${cls ? " " + cls : ""}` }, h("dt", { text: label }), h("dd", { text: value }));
  hero.replaceChildren(
    h("div", {},
      h("div", { class: "hero-value" }, kg(r.mtow), h("small", { text: "kg" })),
      h("p", { class: "hero-label", text: "Peso máximo de decolagem" })),
    h("div", { class: "hero-side" },
      tile("Flap", r.flap), tile("Limitado por", r.limit_text, "wide"),
      ...(state.result.speedsOf[r.plane] ? [tile("V1 (kt)", v1Text(r)), tile("VR (kt)", speed(r.vr)), tile("V2 (kt)", speed(r.v2))]
        : [tile("V1 / VR / V2", "não informados por este motor", "full")])),
  );
}

// ---- abas das visoes
document.querySelectorAll(".view-tabs button").forEach((b) => b.addEventListener("click", () => {
  state.view = b.dataset.view;
  renderViews();
}));
function renderViews() {
  if (!state.result || state.result.rows.length === 1) return;
  document.querySelectorAll(".view-tabs button").forEach((b) => b.setAttribute("aria-selected", b.dataset.view === state.view));
  for (const v of ["chart", "rtow", "list"]) $(`#view-${v}`).hidden = v !== state.view;
  hideTooltip();
  ({ chart: renderChart, rtow: renderRtow, list: renderListView })[state.view]();
}

// ---- seletores reutilizaveis
function chipControl(label, values, isOn, onPick, text) {
  return h("div", { class: "control" }, h("span", { text: label }),
    h("div", { class: "chips", style: "margin:0" }, values.map((v) => h("button", {
      class: "chip", type: "button", text: text(v), "aria-pressed": isOn(v), onclick: () => onPick(v),
    }))));
}
function segControl(label, options, current, pick) {
  return h("div", { class: "control" }, h("span", { text: label }),
    h("div", { class: "seg" }, options.map(([k, text]) => h("button", {
      type: "button", "aria-pressed": k === current, text, onclick: () => pick(k),
    }))));
}

// ------------------------------------------------------------------ resumo (aeronave x pista)
const SEQ = ["#cde2fb", "#b7d3f6", "#9ec5f4", "#86b6ef", "#6da7ec", "#5598e7", "#3987e5",
  "#2a78d6", "#256abf", "#1c5cab", "#184f95", "#104281", "#0d366b"];
function seqColor(t) {
  const pos = Math.max(0, Math.min(1, t)) * (SEQ.length - 1);
  const i = Math.min(SEQ.length - 2, Math.floor(pos)), f = pos - i;
  const a = SEQ[i].match(/\w\w/g).map((x) => parseInt(x, 16)), b = SEQ[i + 1].match(/\w\w/g).map((x) => parseInt(x, 16));
  const rgb = a.map((v, k) => Math.round(v + (b[k] - v) * f));
  const lum = (0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]) / 255;
  return { bg: `rgb(${rgb.join(",")})`, fg: lum > 0.55 ? "#0b1220" : "#ffffff" };
}
function scaleLegend(lo, hi, note) {
  const grad = SEQ.map((c, i) => `${c} ${(100 * i) / (SEQ.length - 1)}%`).join(",");
  return h("div", { class: "scale" }, h("span", { class: "num", text: `${kg(lo)} kg` }),
    h("span", { class: "bar", style: `background:linear-gradient(90deg,${grad})` }),
    h("span", { class: "num", text: `${kg(hi)} kg` }), h("span", { text: note }));
}
function cellTip(title, lines) {
  return h("div", {}, h("div", { class: "tt-title", text: title }), ...lines.map(([label, value, detail]) =>
    h("div", { class: "tt-row" }, h("i", { style: "background:var(--axis)" }), h("b", { text: value }), h("span", { text: label }),
      detail ? h("span", { class: "tt-detail", text: detail }) : null)));
}
function hoverable(el, tip) {
  el.tabIndex = 0;
  el.addEventListener("pointermove", (e) => showTooltip(tip(), e.clientX, e.clientY));
  el.addEventListener("pointerleave", hideTooltip);
  el.addEventListener("focus", () => { const b = el.getBoundingClientRect(); showTooltip(tip(), b.right, b.top); });
  el.addEventListener("blur", hideTooltip);
  return el;
}

function renderSummary(root) {
  const res = state.result, v = res.values;
  const multiCond = res.varying.some((k) => !DIM[k].cat);
  const cells = {};
  for (const r of res.rows) {
    const key = `${r.plane}|${r.runway}`;
    const c = cells[key] || (cells[key] = { rows: [], ok: [] });
    c.rows.push(r);
    if (!r.error) c.ok.push(r);
  }
  // cor: % do maior MTOW da propria aeronave (portes diferentes nao se misturam)
  const planeMax = Object.fromEntries(v.plane.map((pl) => [pl,
    Math.max(...res.rows.filter((r) => r.plane === pl && !r.error).map((r) => r.mtow))]));
  const FLOOR = 0.6;
  const shade = (pl, m) => seqColor((m / planeMax[pl] - FLOOR) / (1 - FLOOR));
  const table = h("table", { class: "summary" });
  table.append(h("thead", {}, h("tr", {}, h("th", { class: "note", text: "aeronave ↓  ·  pista →" }),
    v.runway.map((rw) => h("th", { text: rw })), v.runway.length > 1 ? h("th", { text: "Melhor pista" }) : null)));
  const tbody = h("tbody");
  for (const plane of v.plane) {
    const tr = h("tr", {}, h("th", { text: plane }));
    // melhor pista: maior MTOW; empate -> o maior "pior caso" (minimo da faixa)
    const score = {};
    for (const rw of v.runway) {
      const c = cells[`${plane}|${rw}`];
      if (c?.ok.length) score[rw] = [Math.max(...c.ok.map((r) => r.mtow)), Math.min(...c.ok.map((r) => r.mtow))];
    }
    const ranked = Object.entries(score).sort((a, b) => b[1][0] - a[1][0] || b[1][1] - a[1][1]);
    const bestScore = ranked[0]?.[1];
    const bests = ranked.filter(([, s]) => s[0] === bestScore[0] && s[1] === bestScore[1]).map(([rw]) => rw);
    for (const rw of v.runway) {
      const c = cells[`${plane}|${rw}`];
      if (!c || !c.ok.length) {
        tr.append(hoverable(h("td", { class: "err", text: "erro" }),
          () => cellTip(`${plane} · ${rw}`, [["", "erro", c?.rows[0]?.error?.slice(0, 120)]])));
        continue;
      }
      const mx = c.ok.reduce((a, b) => (b.mtow > a.mtow ? b : a));
      const mn = c.ok.reduce((a, b) => (b.mtow < a.mtow ? b : a));
      const col = shade(plane, mx.mtow);
      const isBest = v.runway.length > 1 && bests.length < v.runway.length && bests.includes(rw);
      const sub = multiCond ? `mín ${kg(mn.mtow)}${c.ok.length < c.rows.length ? ` · ${c.rows.length - c.ok.length} erro(s)` : ""}`
        : `${mx.flap} · ${mx.limit_text}`;
      tr.append(hoverable(h("td", { class: isBest ? "best" : null, style: `background:${col.bg};color:${col.fg}` },
        h("b", { text: kg(mx.mtow) }), h("span", { text: sub })),
      () => cellTip(`${plane} · ${rw}`, multiCond ? [
        ["maior", `${kg(mx.mtow)} kg`, `${where(mx, ["plane", "runway"])} · ${mx.flap} · ${mx.limit_text}`],
        ["menor", `${kg(mn.mtow)} kg`, `${where(mn, ["plane", "runway"])} · ${mn.flap} · ${mn.limit_text}`],
      ] : [["", `${kg(mx.mtow)} kg`, `${mx.flap} · ${mx.limit_text}${speedText(mx)}`]])));
    }
    if (v.runway.length > 1) {
      tr.append(h("th", { text: !bestScore ? "–" : bests.length === v.runway.length ? "todas iguais"
        : `${bests.join(", ")}${bests.length > 1 ? " (empate)" : ""}` }));
    }
    tbody.append(tr);
  }
  table.append(tbody);
  const grad = SEQ.map((c, i) => `${c} ${(100 * i) / (SEQ.length - 1)}%`).join(",");
  root.replaceChildren(
    h("div", { class: "summary-wrap" }, table),
    h("div", { class: "scale wrap" },
      h("span", { class: "scale-item" }, h("span", { class: "num", text: `${FLOOR * 100}%` }),
        h("span", { class: "bar", style: `background:linear-gradient(90deg,${grad})` }),
        h("span", { class: "num", text: "100%" }), " do maior MTOW da aeronave"),
      h("span", { text: multiCond ? "Célula: maior MTOW entre as combinações e, embaixo, o menor. Contorno: melhor pista (no empate, a de maior mínimo)."
        : "Célula: MTOW, flap e limitante. Contorno: melhor pista." })));
}

// ------------------------------------------------------------------ grafico
const css = (name) => getComputedStyle(document.documentElement).getPropertyValue(name).trim();
const RAMP = ["--s1", "--s2", "--s3", "--s4", "--s5"];
const CAT = ["--c1", "--c2", "--c3", "--c4", "--c5", "--c6", "--c7", "--c8"];
function rampColors(n) {
  if (n <= 1) return [css("--s4")];
  const idx = n === 2 ? [1, 4] : n === 3 ? [0, 2, 4] : n === 4 ? [0, 1, 3, 4] : [0, 1, 2, 3, 4];
  return idx.map((i) => css(RAMP[i]));
}
function evenlyPick(values, n) {
  if (values.length <= n) return [...values];
  return [...new Set(Array.from({ length: n }, (_, i) => values[Math.round((i * (values.length - 1)) / (n - 1))]))];
}
const maxSeries = (k) => (DIM[k].cat ? 8 : 5);

function initChartState() {
  const res = state.result, varying = res.varying;
  const nums = varying.filter((k) => !DIM[k].cat);
  if (!nums.length) { state.chart = null; return; }
  const x = nums.includes("temp") ? "temp" : nums[0];
  // linhas: pista > aeronave > vento > QNH (aeronaves de portes diferentes
  // achatam a escala; com varias pistas, a aeronave fica no seletor)
  const series = ["runway", "plane", "wind", "qnh", "temp"].find((k) => k !== x && varying.includes(k)) || null;
  state.chart = { x, series, fixed: {}, shown: series ? evenlyPick(res.values[series], maxSeries(series)) : [] };
  syncFixed();
}
function syncFixed() {
  const c = state.chart, v = state.result.values;
  for (const k of DIM_KEYS) {
    if (k === c.x || k === c.series || v[k].length < 2) { delete c.fixed[k]; continue; }
    if (!v[k].includes(c.fixed[k])) c.fixed[k] = DIM[k].cat ? v[k][0] : closest(v[k], PREFERRED[k]);
  }
}

function renderChart() {
  const c = state.chart, res = state.result, v = res.values;
  const controls = [];
  const nums = res.varying.filter((k) => !DIM[k].cat);
  if (nums.length > 1) {
    controls.push(segControl("Eixo X", nums.map((k) => [k, DIM[k].label]), c.x, (k) => {
      if (c.series === k) c.series = res.varying.find((o) => o !== k) || null;
      c.x = k;
      c.shown = c.series ? evenlyPick(v[c.series], maxSeries(c.series)) : [];
      syncFixed(); renderChart();
    }));
  }
  const others = res.varying.filter((k) => k !== c.x);
  if (others.length) {
    controls.push(segControl("Linhas", [...others.map((k) => [k, DIM[k].label]), ["none", "Nenhuma"]], c.series || "none", (k) => {
      c.series = k === "none" ? null : k;
      c.shown = c.series ? evenlyPick(v[c.series], maxSeries(c.series)) : [];
      syncFixed(); renderChart();
    }));
  }
  if (c.series && v[c.series].length > maxSeries(c.series)) {
    const cap = maxSeries(c.series);
    controls.push(chipControl(`${DIM[c.series].label} (até ${cap})`, v[c.series], (x) => c.shown.includes(x), (x) => {
      if (c.shown.includes(x)) { if (c.shown.length > 1) c.shown = c.shown.filter((y) => y !== x); }
      else if (c.shown.length < cap) c.shown = [...c.shown, x];
      renderChart();
    }, DIM[c.series].short));
  }
  for (const k of Object.keys(c.fixed)) {
    controls.push(chipControl(DIM[k].cat ? DIM[k].label : `${DIM[k].label} fixo`, v[k], (x) => c.fixed[k] === x,
      (x) => { c.fixed[k] = x; renderChart(); }, DIM[k].short));
  }
  $("#chart-controls").replaceChildren(...controls);

  const match = (r) => Object.entries(c.fixed).every(([k, val]) => DIM[k].of(r) === val);
  const sel = res.rows.filter(match);
  // ordem estavel: categoricas na ordem da selecao, numericas crescentes
  const seriesVals = c.series ? v[c.series].filter((x) => c.shown.includes(x)) : [null];
  const colors = !c.series ? [css("--s4")]
    : DIM[c.series].cat ? seriesVals.map((x) => css(CAT[v[c.series].indexOf(x) % CAT.length]))
      : rampColors(seriesVals.length);
  const fixedText = Object.entries(c.fixed).map(([k, val]) => DIM[k].text(val)).join(" · ");
  const groups = seriesVals.map((sv, i) => ({
    value: sv, color: colors[i],
    label: c.series ? DIM[c.series].text(sv) : (fixedText || "MTOW"),
    points: sel.filter((r) => sv === null || DIM[c.series].of(r) === sv)
      .map((r) => ({ x: DIM[c.x].of(r), r })).sort((a, b) => a.x - b.x),
  }));
  $("#chart-legend").replaceChildren(...(groups.length > 1 ? groups.map((g) =>
    h("span", {}, h("i", { style: `background:${g.color}` }), g.label)) : []));
  const errs = sel.filter((r) => r.error).length;
  $("#chart-note").textContent = errs ? `${errs} cálculo(s) com erro ficaram de fora do gráfico (veja a lista).` : "";
  drawLineChart($("#chart"), groups, c);
}

function niceTicks(lo, hi, count = 5) {
  if (lo === hi) { lo -= 1; hi += 1; }
  const raw = (hi - lo) / count, mag = 10 ** Math.floor(Math.log10(raw));
  const step = [1, 2, 2.5, 5, 10].map((m) => m * mag).find((x) => x >= raw);
  const start = Math.floor(lo / step) * step, ticks = [];
  for (let val = start; val <= hi + step * 1e-9; val += step) ticks.push(+val.toFixed(10));
  if (ticks[ticks.length - 1] < hi) ticks.push(+(ticks[ticks.length - 1] + step).toFixed(10));
  return ticks;
}

function drawLineChart(container, groups, c) {
  const W = Math.max(480, container.clientWidth), H = 400;
  const endLabels = groups.length > 1 && groups.length <= 4;
  const labelW = endLabels ? Math.min(220, 16 + 7 * Math.max(...groups.map((g) => g.label.length)) * (groups.length > 2 ? 1.6 : 1)) : 22;
  const m = { l: 64, r: labelW, t: 26, b: 48 };
  const pts = groups.flatMap((g) => g.points.filter((p) => !p.r.error));
  container.replaceChildren();
  if (!pts.length) { container.append(h("p", { class: "hint", text: "Nenhum ponto calculado com esses filtros." })); return; }

  const xsAll = uniq(groups.flatMap((g) => g.points.map((p) => p.x)));
  const xmin = xsAll[0], xmax = xsAll.at(-1);
  const yt = niceTicks(Math.min(...pts.map((p) => p.r.mtow)), Math.max(...pts.map((p) => p.r.mtow)));
  const ymin = yt[0], ymax = yt.at(-1);
  const X = (val) => m.l + (xmax === xmin ? (W - m.l - m.r) / 2 : ((val - xmin) / (xmax - xmin)) * (W - m.l - m.r));
  const Y = (val) => m.t + (1 - (val - ymin) / (ymax - ymin || 1)) * (H - m.t - m.b);
  const xt = xsAll.length <= 12 ? xsAll : niceTicks(xmin, xmax, 8).filter((val) => val >= xmin && val <= xmax);

  const svg = s("svg", { viewBox: `0 0 ${W} ${H}`, role: "img", "aria-label": `MTOW por ${DIM[c.x].label.toLowerCase()}` });
  const surface = css("--surface");
  svg.append(s("text", { class: "axis-title", x: m.l - 56, y: 12, text: "MTOW (kg)" }));
  for (const val of yt) {
    svg.append(s("line", { class: val === ymin ? "baseline" : "gridline", x1: m.l, x2: W - m.r, y1: Y(val), y2: Y(val) }));
    svg.append(s("text", { class: "tick", x: m.l - 10, y: Y(val) + 4, "text-anchor": "end", text: kg(val) }));
  }
  for (const val of xt) svg.append(s("text", { class: "tick", x: X(val), y: H - m.b + 18, "text-anchor": "middle", text: DIM[c.x].short(val) }));
  svg.append(s("text", { class: "axis-title", x: W - m.r, y: H - 8, "text-anchor": "end", text: DIM[c.x].axis }));

  const dense = Math.max(...groups.map((g) => g.points.length)) > 24;
  const ends = [];
  for (const g of groups) {
    let d = "", pen = false;
    for (const p of g.points) {
      if (p.r.error) { pen = false; continue; }
      d += `${pen ? "L" : "M"}${X(p.x).toFixed(1)},${Y(p.r.mtow).toFixed(1)}`;
      pen = true;
    }
    svg.append(s("path", { d, fill: "none", stroke: g.color, "stroke-width": 2, "stroke-linejoin": "round", "stroke-linecap": "round" }));
    if (!dense) for (const p of g.points) {
      if (!p.r.error) svg.append(s("circle", { cx: X(p.x), cy: Y(p.r.mtow), r: 4, fill: g.color, stroke: surface, "stroke-width": 2 }));
    }
    const last = [...g.points].reverse().find((p) => !p.r.error);
    if (last) ends.push({ y: Y(last.r.mtow), x: X(last.x), label: g.label });
  }
  if (endLabels) {
    // rotulos no fim; linhas que terminam juntas (valores iguais) dividem um rotulo
    ends.sort((a, b) => a.y - b.y);
    const clusters = [];
    for (const e of ends) {
      const last = clusters.at(-1);
      if (last && e.y - last.y < 15) last.labels.push(e.label);
      else clusters.push({ y: e.y, x: e.x, labels: [e.label] });
    }
    for (const c of clusters) {
      svg.append(s("text", { class: "end-label", x: c.x + 10, y: c.y + 4, text: c.labels.join(" · ") }));
    }
  }

  const cross = s("line", { class: "crosshair", y1: m.t, y2: H - m.b, visibility: "hidden" });
  const marks = s("g");
  const overlay = s("rect", { class: "overlay", x: m.l, y: m.t, width: W - m.l - m.r, height: H - m.t - m.b, tabindex: 0,
    "aria-label": "Passe o mouse ou use as setas para ver os valores" });
  svg.append(cross, marks, overlay);
  let idx = -1;
  const show = (i, clientX, clientY) => {
    idx = Math.max(0, Math.min(xsAll.length - 1, i));
    const xv = xsAll[idx], px = X(xv);
    cross.setAttribute("x1", px); cross.setAttribute("x2", px); cross.setAttribute("visibility", "visible");
    marks.replaceChildren();
    const lines = [];
    for (const g of groups) {
      const p = g.points.find((q) => q.x === xv);
      if (!p) continue;
      if (!p.r.error) marks.append(s("circle", { cx: px, cy: Y(p.r.mtow), r: 5, fill: g.color, stroke: surface, "stroke-width": 2 }));
      lines.push({ g, r: p.r });
    }
    lines.sort((a, b) => (b.r.mtow || 0) - (a.r.mtow || 0));
    const box = h("div", {}, h("div", { class: "tt-title", text: DIM[c.x].text(xv) }),
      ...lines.map(({ g, r }) => h("div", { class: "tt-row" },
        h("i", { style: `background:${g.color}` }),
        r.error ? h("b", { text: "erro" }) : h("b", { text: `${kg(r.mtow)} kg` }),
        h("span", { text: groups.length > 1 ? g.label : "" }),
        h("span", { class: "tt-detail", text: r.error ? r.error.slice(0, 80) : `${r.flap} · ${r.limit_text}${speedText(r)}` }))));
    const rect = svg.getBoundingClientRect(), scale = rect.width / W;
    showTooltip(box, clientX ?? rect.left + px * scale, clientY ?? rect.top + m.t * scale + 20);
  };
  overlay.addEventListener("pointermove", (e) => {
    const rect = svg.getBoundingClientRect(), vx = ((e.clientX - rect.left) / rect.width) * W;
    let best = 0;
    xsAll.forEach((val, i) => { if (Math.abs(X(val) - vx) < Math.abs(X(xsAll[best]) - vx)) best = i; });
    show(best, e.clientX, e.clientY);
  });
  const leave = () => { cross.setAttribute("visibility", "hidden"); marks.replaceChildren(); hideTooltip(); };
  overlay.addEventListener("pointerleave", leave);
  overlay.addEventListener("blur", leave);
  overlay.addEventListener("focus", () => show(idx < 0 ? 0 : idx));
  overlay.addEventListener("keydown", (e) => {
    if (e.key === "ArrowRight" || e.key === "ArrowLeft") { e.preventDefault(); show(idx + (e.key === "ArrowRight" ? 1 : -1)); }
  });
  container.append(svg);
}

// ------------------------------------------------------------------ RTOW
/* Uma tabela temperatura x vento por aeronave e pista, empilhadas. Filtros
 * opcionais de aeronave e pista; o QNH escolhe qual "fatia" mostrar. Sem
 * faixa de temperatura nem de vento, mostra a matriz aeronave x pista. */
function renderRtow() {
  const res = state.result, v = res.values, f = state.rtow, root = $("#view-rtow");
  if (v.temp.length === 1 && v.wind.length === 1) return renderSummary(root);
  if (!v.qnh.includes(f.qnh)) f.qnh = closest(v.qnh, 1013.25);
  if (f.plane !== "all" && !v.plane.includes(f.plane)) f.plane = "all";
  if (f.runway !== "all" && !v.runway.includes(f.runway)) f.runway = "all";
  const controls = [];
  const opt = (values) => ["all", ...values];
  const lab = (x) => (x === "all" ? "Todas" : x);
  if (v.plane.length > 1) controls.push(chipControl("Aeronave", opt(v.plane), (x) => x === f.plane, (x) => { f.plane = x; renderRtow(); }, lab));
  if (v.runway.length > 1) controls.push(chipControl("Pista", opt(v.runway), (x) => x === f.runway, (x) => { f.runway = x; renderRtow(); }, lab));
  if (v.qnh.length > 1) controls.push(chipControl("QNH", v.qnh, (x) => x === f.qnh, (x) => { f.qnh = x; renderRtow(); }, qnhText));
  const cards = [];
  for (const plane of v.plane) {
    if (f.plane !== "all" && f.plane !== plane) continue;
    for (const rw of v.runway) {
      if (f.runway !== "all" && f.runway !== rw) continue;
      const rows = res.rows.filter((r) => r.plane === plane && r.runway === rw && r.qnh === f.qnh);
      cards.push(h("div", { class: "rtow-card" },
        h("h3", {}, `${plane} · ${rw}`, h("small", { text: `QNH ${qnhText(f.qnh)} hPa` })),
        rtowTable(rows, v, res.speedsOf[plane])));
    }
  }
  root.replaceChildren(
    controls.length ? h("div", { class: "controls" }, controls) : "",
    h("p", { class: "rtow-note", text: "Célula: MTOW (kg) / código do limitante e, embaixo, V1 / VR / V2 (kt) — ou o flap, quando o motor não informa velocidades. "
      + "A cor vai do menor (claro) ao maior (escuro) MTOW de cada tabela; passe o mouse para ver os detalhes." }),
    h("div", { class: "rtow-stack" }, cards));
}
function rtowTable(rows, v, speeds) {
  const ok = rows.filter((r) => !r.error);
  const lo = Math.min(...ok.map((r) => r.mtow)), hi = Math.max(...ok.map((r) => r.mtow));
  const crosswind = rows[0]?.crosswind || 0;
  const table = h("table", { class: "rtow" });
  table.append(h("thead", {}, h("tr", {}, h("th", { class: "corner", text: "OAT ↓  ·  vento →" }),
    v.wind.map((w) => h("th", { text: windText(w, crosswind) })))));
  const tbody = h("tbody");
  for (const t of [...v.temp].reverse()) {           // como a RTOW: mais quente em cima
    const tr = h("tr", {}, h("th", { text: tempText(t) }));
    for (const w of v.wind) {
      const r = rows.find((x) => x.temp === t && x.wind === w);
      if (!r) { tr.append(h("td", {})); continue; }
      if (r.error) {
        tr.append(hoverable(h("td", { class: "err", text: "erro" }), () => cellTip(where(r), [["", "erro", r.error.slice(0, 120)]])));
        continue;
      }
      const col = seqColor(hi === lo ? 1 : (r.mtow - lo) / (hi - lo));
      tr.append(hoverable(h("td", { style: `background:${col.bg};color:${col.fg}` },
        h("b", { text: `${kg(r.mtow)} / ${r.limit}` }),
        h("span", { text: speeds ? `${v1Text(r)} / ${speed(r.vr)} / ${speed(r.v2)}` : r.flap })),
      () => cellTip(where(r), [[r.flap, `${kg(r.mtow)} kg`, `${r.limit_text}${speedText(r)}`]])));
    }
    tbody.append(tr);
  }
  table.append(tbody);
  return h("div", { class: "rtow-wrap" }, table);
}

// ------------------------------------------------------------------ lista
function sortableTable(cols, rows, sortState, rerender, rowClass) {
  const sorted = [...rows].sort((a, b) => {
    const col = cols.find((c) => c.key === sortState.key) || cols[0];
    const va = col.sort ? col.sort(a) : a[col.key], vb = col.sort ? col.sort(b) : b[col.key];
    if (va == null) return 1; if (vb == null) return -1;
    return (va < vb ? -1 : va > vb ? 1 : 0) * sortState.dir;
  });
  return h("div", { class: "table-wrap" }, h("table", { class: "data" },
    h("thead", {}, h("tr", {}, cols.map((c) => h("th", {
      class: c.right ? "r" : null, text: c.label,
      "aria-sort": sortState.key === c.key ? (sortState.dir > 0 ? "ascending" : "descending") : null,
      onclick: () => { sortState.dir = sortState.key === c.key ? -sortState.dir : 1; sortState.key = c.key; rerender(); },
    })))),
    h("tbody", {}, sorted.map((r) => h("tr", { class: rowClass ? rowClass(r) : null }, cols.map((c) => {
      const val = c.show(r);
      const cls = [c.right ? "r" : "", c.err && c.err(r) ? "err" : "", c.cls ? c.cls(r) : ""].join(" ").trim() || null;
      return val?.nodeType || Array.isArray(val) ? h("td", { class: cls }, val) : h("td", { class: cls, text: val });
    }))))));
}
function renderListView() {
  const res = state.result;
  const order = (k) => (r) => res.values[k].indexOf(r[k]);
  const cols = [];
  if (res.values.plane.length > 1) cols.push({ key: "plane", label: "Aeronave", sort: order("plane"), show: (r) => r.plane });
  if (res.values.runway.length > 1) cols.push({ key: "runway", label: "Pista", sort: order("runway"), show: (r) => r.runway });
  cols.push(
    { key: "temp", label: "Temp", show: (r) => tempText(r.temp) },
    { key: "wind", label: "Vento", show: (r) => windText(r.wind, r.crosswind) },
    { key: "qnh", label: "QNH", show: (r) => qnhText(r.qnh) },
    { key: "mtow", label: "MTOW (kg)", right: true, show: (r) => (r.error ? "–" : kg(r.mtow)) },
    { key: "flap", label: "Flap", show: (r) => r.flap || "–" },
    { key: "limit_text", label: "Limitado por", show: (r) => r.error || r.limit_text, err: (r) => !!r.error });
  if (res.anySpeeds) cols.push(
    { key: "v1_min", label: "V1", right: true, show: v1Text },
    { key: "vr", label: "VR", right: true, show: (r) => speed(r.vr) },
    { key: "v2", label: "V2", right: true, show: (r) => speed(r.v2) });
  if (!cols.some((c) => c.key === state.sort.key)) state.sort = { key: cols[0].key, dir: 1 };
  $("#view-list").replaceChildren(sortableTable(cols, res.rows, state.sort, renderListView));
}

// ------------------------------------------------------------------ malha
const malhaForm = conditionsForm($("#malha-conditions"), {
  tempMode: "range", onEnter: () => runMalha(),
  onChange: () => { $("#malha-count").textContent = `${countText(malhaForm.count())} por pista`; },
});
const malhaBtn = $("#malha-btn");
let malhaJob = null, malhaSort = { key: "alert", dir: 1 }, malhaFilter = "all";

/* Peso de referencia do alerta, por aeronave (em branco = estrutural).
 * Fica guardado no navegador. */
STORE.refs = "perf.refs";
STORE.malhaFlaps = "perf.malhaFlaps";
STORE.malhaCg = "perf.malhaCg";
function renderRefs() {
  const saved = load(STORE.refs, {});
  $("#malha-refs").replaceChildren(...state.meta.aircraft.map((a) => {
    const input = h("input", { id: `ref-${a.id}`, type: "number", min: 1000, max: 400000, step: 1, inputmode: "numeric",
      placeholder: "estrutural", "aria-label": `Peso de referência ${a.name}` });
    input.value = saved[a.name] ?? "";
    input.addEventListener("input", () => {
      const refs = load(STORE.refs, {});
      if (input.value === "") delete refs[a.name]; else refs[a.name] = Number(input.value);
      save(STORE.refs, refs);
    });
    input.addEventListener("keydown", (e) => { if (e.key === "Enter") runMalha(); });
    let flap = null;
    if (a.flaps.length > 1) {
      flap = h("select", { "aria-label": `Flap ${a.name}`, title: "Flap: ótimo = o motor escolhe o de maior MTOW" },
        h("option", { value: "", text: "Flap ótimo" }), a.flaps.map((f) => h("option", { value: f.code, text: f.label })));
      flap.value = load(STORE.malhaFlaps, {})[a.name] ?? "";
      flap.addEventListener("change", () => {
        const flaps = load(STORE.malhaFlaps, {});
        if (flap.value === "") delete flaps[a.name]; else flaps[a.name] = Number(flap.value);
        save(STORE.malhaFlaps, flaps);
      });
    }
    let cg = null;
    if (a.cg.length > 1) {
      cg = h("select", { "aria-label": `Limite de CG ${a.name}`, title: "Limite dianteiro de CG (POPT 30)" },
        a.cg.map((c) => h("option", { value: c.code, text: `CG ${c.label}` })));
      cg.value = load(STORE.malhaCg, {})[a.name] ?? 0;
      cg.addEventListener("change", () => {
        const cgs = load(STORE.malhaCg, {});
        if (cg.value === "0") delete cgs[a.name]; else cgs[a.name] = Number(cg.value);
        save(STORE.malhaCg, cgs);
      });
    }
    return h("div", { class: "ref-item" }, h("label", { text: a.name, for: `ref-${a.id}` }),
      h("div", { class: "row" }, input, h("small", { text: "kg" })),
      h("small", { text: a.structural ? `estrutural ${kg(a.structural)} kg` : "estrutural do motor" }),
      flap, cg);
  }));
}
malhaBtn.addEventListener("click", runMalha);
$("#malha-open").addEventListener("click", () => api("/api/open", { job: malhaJob }).catch((e) => alert(e.message)));

async function runMalha() {
  if (malhaBtn.disabled) return;
  if (malhaForm.count() == null) { alert("Confira os valores das faixas."); return; }
  const body = { path: $("#malha-path").value, refs: load(STORE.refs, {}), flaps: load(STORE.malhaFlaps, {}), cg: load(STORE.malhaCg, {}), ...malhaForm.spec() };
  if (state.meta.server) {                 // servidor: a malha vai pelo navegador
    const file = $("#malha-file").files[0];
    if (!file) { alert("Escolha o arquivo da malha (.csv)."); return; }
    body.csv = await file.text();
    body.filename = file.name;
  }
  malhaBtn.disabled = true; malhaBtn.textContent = "Calculando…";
  for (const id of ["malha-error", "malha-result"]) $(`#${id}`).hidden = true;
  $("#malha-loading").hidden = false;
  $("#malha-progress").style.width = "0";
  $("#malha-loading-text").textContent = "Lendo a malha…";
  try {
    const started = await api("/api/malha", body);
    malhaJob = started.id;
    const job = await pollJob(started.id, (j) => {
      if (j.total) $("#malha-progress").style.width = `${(100 * j.done) / j.total}%`;
      if (j.label) $("#malha-loading-text").textContent = `${j.label}…`;
    });
    if (job.state === "error") throw new Error(job.error);
    renderMalha(job.result);
  } catch (e) {
    $("#malha-error").replaceChildren(h("strong", { text: "Não foi possível calcular a malha" }), e.message);
    $("#malha-error").hidden = false;
  } finally {
    $("#malha-loading").hidden = true;
    malhaBtn.disabled = false; malhaBtn.textContent = "Calcular malha";
  }
}
const ALERTS = {
  RESTRITO: { rank: 0, cls: "bad", text: "Restrito", tip: "Nem o melhor caso decola com o peso de referência" },
  ATENCAO: { rank: 1, cls: "warn", text: "Atenção", tip: "Decola com o peso de referência só em parte das condições" },
  OK: { rank: 2, cls: "ok", text: "OK", tip: "Até o pior caso decola com o peso de referência" },
};
const alertOf = (r) => ALERTS[r.alert] || { rank: 3, cls: "none", text: r.mtow == null ? "Erro" : "–", tip: r.obs || "" };

function renderMalha(res) {
  state.malha = res;
  $("#malha-download").hidden = !res.download;
  if (res.download) { $("#malha-download").href = fileUrl(res.download); $("#malha-download").download = res.download; }
  const ok = res.rows.filter((r) => r.mtow != null).length;
  const span = (vals, fmt, unit) => vals.length === 1 ? `${fmt(vals[0])}${unit}`
    : `${fmt(vals[0])} a ${fmt(vals.at(-1))}${unit} (${vals.length} valores)`;
  const conds = [span(res.temps, plain, " °C"),
    res.winds.length === 1 ? windText(res.winds[0], res.crosswind) : `vento ${span(res.winds, plain, " kt")}`,
    `QNH ${span(res.qnhs, qnhText, " hPa")}`].join(" · ");
  $("#malha-sub").textContent = `${ok} de ${res.rows.length} aeroporto(s)/aeronave(s) · ${nfKg.format(res.cases)} combinação(ões) por pista: ${conds} · ${res.path}`;

  const count = (k) => res.rows.filter((r) => (k === "alerts" ? r.alert === "RESTRITO" || r.alert === "ATENCAO" : r.alert === k)).length;
  const filters = [
    { key: "all", label: "Todos", n: res.rows.length },
    { key: "alerts", label: "Só alertas", n: count("alerts") },
    { key: "RESTRITO", label: "Restrito", n: count("RESTRITO"), cls: "bad" },
    { key: "ATENCAO", label: "Atenção", n: count("ATENCAO"), cls: "warn" },
    { key: "OK", label: "OK", n: count("OK"), cls: "ok" },
  ];
  if (!filters.some((f) => f.key === malhaFilter && f.n)) malhaFilter = "all";
  const shown = () => res.rows.filter((r) => malhaFilter === "all"
    || (malhaFilter === "alerts" ? r.alert === "RESTRITO" || r.alert === "ATENCAO" : r.alert === malhaFilter));
  const drawFilters = () => $("#malha-alerts").replaceChildren(...filters.map((f) => h("button", {
    type: "button", "aria-pressed": malhaFilter === f.key, disabled: !f.n && f.key !== "all",
    onclick: () => { malhaFilter = f.key; drawFilters(); draw(); },
  }, f.cls ? h("span", { class: `badge ${f.cls}`, text: f.label }) : f.label, h("b", { text: nfKg.format(f.n) }))));

  const worstCond = (r) => r.worst_mtow == null ? "–"
    : [`pista ${r.worst_rwy}`, tempText(r.worst_temp),
      res.winds.length > 1 ? windText(r.worst_wind, r.worst_crosswind) : null,
      res.qnhs.length > 1 ? `QNH ${qnhText(r.worst_qnh)}` : null].filter(Boolean).join(" · ");
  const cols = [
    { key: "alert", label: "Alerta", sort: (r) => alertOf(r).rank * 1e7 + (r.margin ?? 0),
      show: (r) => { const a = alertOf(r); return h("span", { class: `badge ${a.cls}`, title: a.tip, text: a.text }); } },
    { key: "iata", label: "Partida", show: (r) => (r.icao ? `${r.iata} · ${r.icao}` : r.iata) },
    { key: "aircraft", label: "Aeronave", show: (r) => r.aircraft },
    { key: "mtow", label: "Maior MTOW (kg)", right: true,
      show: (r) => (r.mtow == null ? "–" : [kg(r.mtow), h("small", { text: `pista ${r.rwy} · ${tempText(r.temp)}` })]) },
    { key: "worst_mtow", label: "Pior caso (kg)", right: true,
      show: (r) => (r.worst_mtow == null ? "–" : [kg(r.worst_mtow), h("small", { text: worstCond(r) })]) },
    { key: "ref", label: "Referência (kg)", right: true, show: (r) => (r.ref == null ? "–" : kg(r.ref)) },
    { key: "margin", label: "Margem (kg)", right: true,
      cls: (r) => (r.margin == null ? "" : r.margin < 0 ? "neg" : "pos"),
      show: (r) => (r.margin == null ? "–" : `${r.margin > 0 ? "+" : r.margin < 0 ? "−" : ""}${kg(Math.abs(r.margin))}`) },
    { key: "limit_temp", label: "Decola com a ref. até",
      show: (r) => (r.alert === "OK" ? "todas" : r.alert === "RESTRITO" ? "nenhuma"
        : r.limit_temp == null ? "–" : tempText(r.limit_temp)) },
    { key: "worst_limit_text", label: "Limitado por (pior caso)",
      show: (r) => (r.mtow == null ? r.obs || "erro" : r.worst_limit_text || "–"), err: (r) => r.mtow == null },
  ];
  const rowClass = (r) => (r.alert === "RESTRITO" ? "row-bad" : r.alert === "ATENCAO" ? "row-warn" : null);
  const draw = () => $("#malha-table").replaceChildren(sortableTable(cols, shown(), malhaSort, draw, rowClass));
  drawFilters();
  draw();
  $("#malha-result").hidden = false;
}

// ------------------------------------------------------------------ inicio
let resizeTimer;
new ResizeObserver(() => {
  clearTimeout(resizeTimer);
  resizeTimer = setTimeout(() => { if (state.result && state.chart && state.view === "chart" && !$("#r-views").hidden) renderChart(); }, 120);
}).observe($("#chart"));

// ------------------------------------------------------------------ pouso
/* Um calculo de pouso (despacho) por vez, com valores unicos. Mesma cara da
 * decolagem: consulta a esquerda (aeronave, pista, condicoes, configuracao),
 * resultado a direita (peso, limitante, desenho da distancia, limites). */
const LD_STORE = "perf.pouso";
const ld = { meta: null, ready: false, v: {}, airport: null };
const ldEl = (id) => $(`#ld-${id}`);
const LD_INPUTS = ["icao", "lda", "elev", "slope", "temp", "qnh", "vento", "cpouso", "carr", "mlw", "ga", "lw", "vrefinc"];
const LD_DEFAULTS = { molhada: "0", grooved: "0", athr: "1", reverso: "0", antigelo: "0", ar: "2", autobrake: "0", conf: "" };

async function initPouso() {
  if (ld.ready) return;
  try { ld.meta = await api("/api/pouso/meta"); } catch (e) { return ldShow("error", e.message); }
  ld.ready = true;
  $("#ld-airports").replaceChildren(...(state.meta?.airports || []).map((a) =>
    h("option", { value: a.icao, text: `${a.iata ? a.iata + " · " : ""}${a.name}` })));
  const saved = load(LD_STORE, null) || {};
  ld.v = { ...LD_DEFAULTS, ...(saved.v || {}) };
  const ac = ld.meta.aircraft.find((a) => String(a.id) === String(saved.ac)) || ld.meta.aircraft[0];
  ldPick(ac.id, saved.var ?? ac.variants[0].id, saved.v?.conf);
  for (const k of LD_INPUTS) if (saved[k] != null && saved[k] !== "") ldEl(k).value = saved[k];
  const icao = saved.icao || "SBRJ";
  ldEl("icao").value = icao;
  await ldLoadAirport(icao, saved.rwy || "20L", !saved.lda);
  ldRender();
}
const ldAircraft = () => ld.meta.aircraft.find((a) => a.id === ld.v.ac);

/** Escolhe aeronave/motor e ajusta o que depende do fabricante. */
function ldPick(acId, varId, conf) {
  const a = ld.meta.aircraft.find((x) => x.id === acId);
  ld.v.ac = a.id;
  ld.v.var = a.variants.some((v) => v.id === varId) ? varId : a.variants[0].id;
  ld.v.conf = conf != null && (conf === "" || a.confs.some((c) => c.name === conf)) ? conf
    : (a.confs.find((c) => c.name === "FULL") || a.confs[0])?.name ?? "";   // FULL quando existir
  const anti = ldOptions().antigelo.map(([k]) => k);
  if (!anti.includes(ld.v.antigelo)) ld.v.antigelo = "0";
  if (a.fabricante === "atr") ld.v.reverso = "0";
  ldApplyConf();
  ldRender();
}
function ldApplyConf() {
  const c = ldAircraft().confs.find((x) => x.name === ld.v.conf);
  if (c) { ldEl("cpouso").value = c.pouso; ldEl("carr").value = c.arremetida; }
  ldEl("cpouso").readOnly = ldEl("carr").readOnly = !!c;
}
/** Opcoes de cada escolha, conforme o fabricante. */
function ldOptions() {
  const a = ldAircraft(), fab = a.fabricante;
  return {
    conf: [...a.confs.map((c) => [c.name, `${fab === "airbus" ? "CONF" : "FLAP"} ${c.name}`]), ["", "Outro"]],
    molhada: [["0", "Seca"], ["1", "Molhada"]],
    grooved: [["0", "Normal"], ["1", "Grooved / PFC"]],
    athr: [["1", "A/THR on (+5 kt)"], ["0", "A/THR off"]],
    reverso: fab === "atr" ? [["0", "Sem crédito"]] : [["0", "Sem crédito"], ["1", "Crédito"]],
    antigelo: fab === "atr" ? [["0", "OFF"], ["6", "Condição de gelo"]]
      : fab === "embraer" ? [["0", "OFF"], ["3", "Motor e asa"]] : [["0", "OFF"], ["1", "Motor"], ["3", "Motor e asa"]],
    autobrake: [["0", "OFF"], ["1", "LOW"], ["2", "MED"], ["3", "HI"]],
    ar: [["2", "OFF"], ["1", "ON"]],
  };
}
function ldRender() {
  if (!ld.ready) return;
  const a = ldAircraft(), opts = ldOptions();
  // aeronaves: modelo + motores (como na decolagem), uma escolha so
  $("#ld-planes").replaceChildren(...ld.meta.aircraft.map((m) => h("div", { class: "plane-row" },
    h("button", { class: `model-btn${m.id === a.id ? " on" : ""}`, type: "button", onclick: () => ldPick(m.id, m.variants[0].id) },
      m.name, h("small", { text: { airbus: "Airbus", embraer: "Embraer", atr: "ATR" }[m.fabricante] })),
    h("div", { class: "pills" }, m.variants.map((v) => h("button", {
      class: "pill", type: "button", text: v.label, "aria-pressed": m.id === a.id && v.id === ld.v.var,
      onclick: () => ldPick(m.id, v.id),
    }))))));
  // escolhas segmentadas
  for (const box of document.querySelectorAll("#ld-form .ld-choice")) {
    const key = box.dataset.key, list = opts[key];
    box.hidden = !!box.dataset.fab && box.dataset.fab !== a.fabricante;
    box.replaceChildren(h("span", { text: box.dataset.label }),
      h("div", { class: "seg full" }, list.map(([k, text]) => h("button", {
        type: "button", text, "aria-pressed": String(ld.v[key]) === k,
        onclick: () => { ld.v[key] = k; if (key === "conf") ldApplyConf(); ldRender(); },
      }))));
  }
  for (const el of document.querySelectorAll("#ld-form .ld-field[data-fab]")) el.hidden = el.dataset.fab !== a.fabricante;
  ldEl("cpouso-ref").textContent = a.fabricante === "airbus" ? "CONFL(4)" : "CONFL(5)";
  ldEl("carr-ref").textContent = a.fabricante === "airbus" ? "CONFL(2)" : "CONFL(3)";
  ldRenderRunways();
  const v = a.variants.find((x) => x.id === ld.v.var);
  const conf = opts.conf.find(([k]) => k === ld.v.conf)?.[1] || "códigos";
  ldEl("summary").replaceChildren(h("b", { text: `${a.name} ${v.label}` }),
    ` · ${ldEl("icao").value.toUpperCase() || "?"} ${ld.v.rwy || ""} · ${conf} · ${ld.v.molhada === "1" ? "molhada" : "seca"}`);
}
async function ldLoadAirport(icao, rwy, fill = true) {
  icao = icao.trim().toUpperCase();
  if (!/^[A-Z0-9]{4}$/.test(icao)) return;
  try { ld.airport = await getAirport(icao); } catch (e) { ld.airport = null; ldEl("rwy-info").textContent = e.message; ldRenderRunways(); return; }
  ld.v.rwy = ld.airport.runways.some((r) => r.rwy === rwy) ? rwy : ld.airport.runways[0]?.rwy;
  ldRunwayFill(fill);
  ldRender();
}
function ldRunway() { return ld.airport?.runways.find((r) => r.rwy === ld.v.rwy); }
function ldRenderRunways() {
  const a = ld.airport;
  ldEl("runways").replaceChildren(...(a ? a.runways.map((r) => h("button", {
    class: "pill", type: "button", "aria-pressed": r.rwy === ld.v.rwy,
    title: `TORA ${kg(r.tora)} m · elev. ${kg(r.elev)} ft · slope ${num(r.slope)}%`,
    onclick: () => { ld.v.rwy = r.rwy; ldRunwayFill(true); ldRender(); },
  }, r.rwy, h("small", { text: kg(r.tora) }))) : []));
}
function ldRunwayFill(fill) {
  const r = ldRunway();
  if (!r) return;
  if (fill) {
    ldEl("lda").value = r.tora; ldEl("elev").value = r.elev; ldEl("slope").value = r.slope;
    ld.v.grooved = /GROOVED/i.test(r.surface) ? "1" : "0";
  }
  ldEl("rwy-info").textContent = `${ld.airport.name} · cadastro: TORA ${kg(r.tora)} · TODA ${kg(r.toda)} · ASDA ${kg(r.asda)} m · `
    + `elev. ${kg(r.elev)} ft · slope ${num(r.slope)}% · ${/GROOVED/i.test(r.surface) ? "grooved" : "normal"}`;
}
ldEl("icao").addEventListener("change", () => ldLoadAirport(ldEl("icao").value, null, true));
ldEl("icao").addEventListener("keydown", (e) => { if (e.key === "Enter") { e.preventDefault(); ldLoadAirport(ldEl("icao").value, null, true); } });

function ldShow(which, msg) {
  for (const k of ["empty", "loading", "error", "out"]) ldEl(k).hidden = k !== which;
  if (which === "error") ldEl("error").replaceChildren(h("strong", { text: "Não foi possível calcular" }), msg);
}
ldEl("form").addEventListener("submit", async (e) => {
  e.preventDefault();
  if (!ld.ready || ldEl("btn").disabled) return;
  const a = ldAircraft();
  const body = { aircraft: a.id, variant: ld.v.var, molhada: ld.v.molhada === "1", grooved: ld.v.grooved === "1",
    athr: ld.v.athr === "1", reverso: ld.v.reverso, antigelo: ld.v.antigelo, ar: ld.v.ar, autobrake: ld.v.autobrake,
    lda: ldEl("lda").value, elev: ldEl("elev").value, slope: ldEl("slope").value, temp: ldEl("temp").value,
    qnh: ldEl("qnh").value, vento: ldEl("vento").value, conf_pouso: ldEl("cpouso").value, conf_arremetida: ldEl("carr").value,
    mlw: ldEl("mlw").value, ga_grad: ldEl("ga").value, lw: ldEl("lw").value, vref_inc: ldEl("vrefinc").value };
  save(LD_STORE, { ac: a.id, var: ld.v.var, rwy: ld.v.rwy, v: { ...ld.v }, ...Object.fromEntries(LD_INPUTS.map((k) => [k, ldEl(k).value])) });
  ldEl("btn").disabled = true; ldEl("btn").textContent = "Calculando…";
  ldShow("loading");
  try {
    ldResultado(await api("/api/pouso", body), body);
  } catch (err) {
    ldShow("error", err.message);
  } finally {
    ldEl("btn").disabled = false; ldEl("btn").textContent = "Calcular pouso";
  }
});

function ldResultado(r, body) {
  const a = ldAircraft(), opts = ldOptions(), rw = ldRunway();
  const pct = (x) => (x == null ? "–" : `${num(x)} %`), kt = (x) => (x == null ? "–" : `${Math.round(x)} kt`), m = (x) => (x == null ? "–" : `${kg(x)} m`);
  const flap = opts.conf.find(([k]) => k === ld.v.conf)?.[1] || `${body.conf_pouso}/${body.conf_arremetida}`;
  ldEl("title").textContent = `${ldEl("icao").value.toUpperCase()} · pista ${ld.v.rwy || "?"}${ld.airport ? ` · ${ld.airport.name}` : ""}`;
  const tag = (label, value) => h("span", {}, label, h("b", { text: value }));
  ldEl("tags").replaceChildren(tag("Aeronave", `${r.aircraft} ${r.engine}`), tag("LDA", `${kg(+body.lda)} m`),
    h("span", { text: body.molhada ? `molhada${body.grooved ? " grooved" : ""}` : "seca" }), h("span", { text: `${plain(+body.temp)} °C` }),
    h("span", { text: +body.vento ? windText(+body.vento) : "sem vento" }), h("span", { text: `QNH ${plain(+body.qnh)}` }),
    tag("Flap", flap), ...(a.fabricante === "airbus" ? [h("span", { text: body.athr ? "A/THR on (+5 kt)" : "A/THR off" })] : []),
    ...(+body.reverso ? [h("span", { text: "com reverso" })] : []));
  // destaque, como o MTOW da decolagem
  const tile = (label, value, cls) => h("dl", { class: `tile${cls ? " " + cls : ""}` }, h("dt", { text: label }), h("dd", { text: value }));
  ldEl("hero").replaceChildren(
    h("div", {}, h("div", { class: "hero-value" }, r.mlw == null ? "–" : kg(r.mlw), h("small", { text: "kg" })),
      h("p", { class: "hero-label", text: "Peso máximo de pouso (despacho)" })),
    h("div", { class: "hero-side" },
      tile("Limitado por", r.limitante || "–", "wide"), tile("Flap", flap),
      tile(a.fabricante === "airbus" ? "VAPP" : "VREF", kt(r.vapp)), tile("Gradiente de arremetida", pct(r.gradiente_arremetida)),
      tile("Gradiente de subida de pouso", pct(r.gradiente_pouso)),
      ...(r.mlw == null || r.erflag && !"AD".includes(r.erflag[0]) ? [tile("Motor", [r.erflag && `ERFLAG ${r.erflag}`, ...r.mensagens.slice(0, 2)].filter(Boolean).join(" · ") || "sem resultado", "full")] : [])));
  ldDiagram(r, +body.lda);
  // limites por criterio
  const crit = [["Distância (LDA)", "WEIGHT LIMITED BY LDA"], ["Arremetida", "WEIGHT LIMITED BY ACG"],
    ["Subida de pouso", "WEIGHT LIMITED BY LCG"], ["Energia de freio", "WEIGHT LIMITED BY BRAKE ENERGY"],
    ["Pneus", "WEIGHT LIMITED BY TIRE SPEED"]].filter(([, k]) => r.principal[k] != null);
  const menor = Math.min(...crit.map(([, k]) => r.principal[k]));
  // o MLW (ou o maximo da base) ficou abaixo de todos os criterios: nenhum limita
  const peloPeso = r.mlw != null && r.mlw < menor - 0.5;
  ldEl("limits").replaceChildren(crit.length ? h("section", { class: "ld-block" },
    h("p", { class: "kicker", text: "Peso limitado por cada critério" }),
    h("div", { class: "kpi-strip" }, crit.map(([label, k]) => {
      const x = r.principal[k], limita = !peloPeso && x === menor;
      return h("dl", { class: `kpi${limita ? " ld-min" : ""}` },
        h("dt", { text: label }), h("dd", {}, kg(x), h("small", { text: "kg" })),
        h("p", { text: limita ? "o limitante" : `${kg(x - (peloPeso ? r.mlw : menor))} kg acima ${peloPeso ? "do peso máximo" : "do limitante"}` }));
    }))) : "");
  // no LW informado
  const lw = r.no_lw;
  ldEl("lwbox").replaceChildren(lw ? h("section", { class: "ld-block" },
    h("p", { class: "kicker", text: `No peso de pouso informado (LW ${kg(r.lw)} kg)` }),
    h("div", { class: "kpi-strip" },
      h("dl", { class: "kpi" }, h("dt", { text: "Gradiente de arremetida" }), h("dd", { text: pct(lw.gradiente_arremetida) }), h("p", { text: "um motor inoperante" })),
      h("dl", { class: "kpi" }, h("dt", { text: "Gradiente de subida de pouso" }), h("dd", { text: pct(lw.gradiente_pouso) })),
      h("dl", { class: "kpi" }, h("dt", { text: a.fabricante === "airbus" ? "VAPP" : "VREF" }), h("dd", { text: kt(lw.vapp) })),
      h("dl", { class: "kpi" }, h("dt", { text: "Distância de pouso" }), h("dd", { text: m(lw.ld) }), h("p", { text: lw.ld_exigida == null ? "" : `exigida ${m(lw.ld_exigida)}` })))) : "");
  // detalhes
  const fmt = (x) => (x == null ? "–" : Math.abs(x) >= 100 ? kg(x) : num(x));
  ldEl("details").replaceChildren(
    h("table", { class: "data pouso-table" }, h("tbody", {}, ...Object.entries(r.principal).map(([k, x]) =>
      h("tr", {}, h("td", { text: k }), h("td", { class: "r", text: fmt(x) }))))),
    h("p", { class: "pouso-flag" }, "ERFLAG ", h("b", { text: r.erflag || "?" }), r.mensagens.length ? ` · ${r.mensagens.join(" · ")}` : ""),
    h("pre", { class: "pouso-in", text: r.entrada.replace(/\r/g, "") }));
  ldShow("out");
  window.scrollTo({ top: 0 });
}
/** Desenho: LDA inteira, distancia real de pouso e distancia exigida (fator). */
function ldDiagram(r, lda) {
  const svg = $("#ld-svg"), W = 900, H = 120, x0 = 40, x1 = W - 40;
  svg.setAttribute("viewBox", `0 0 ${W} ${H}`);
  svg.replaceChildren();
  const max = Math.max(lda, r.ld_exigida || 0, r.ld || 0) || 1;
  const sx = (d) => x0 + (x1 - x0) * d / max;
  svg.append(s("rect", { x: sx(0), y: 34, width: sx(lda) - sx(0), height: 18, rx: 3, class: "rw-strip" }),
    s("line", { x1: sx(0) + 6, y1: 43, x2: sx(lda) - 6, y2: 43, class: "rw-center" }),
    s("text", { x: sx(0), y: 26, class: "rw-thr", text: ld.v.rwy || "" }),
    s("text", { x: sx(lda), y: 26, class: "rw-bar-label", "text-anchor": "end", text: `LDA ${kg(lda)} m` }));
  if (r.ld_exigida != null) {
    const over = r.ld_exigida > lda + 0.5;
    svg.append(s("line", { x1: sx(0), y1: 74, x2: sx(r.ld_exigida), y2: 74, class: `rw-bar ${over ? "ld-over" : "toda"}`, "stroke-width": 6 }),
      s("text", { x: sx(r.ld_exigida), y: 92, class: "rw-bar-label", "text-anchor": "end", text: `exigida ${kg(r.ld_exigida)} m` }));
  }
  if (r.ld != null) {
    svg.append(s("line", { x1: sx(0), y1: 60, x2: sx(r.ld), y2: 60, class: "rw-bar tora", "stroke-width": 8 }),
      s("text", { x: sx(r.ld) + 6, y: 64, class: "rw-bar-label", text: `pouso ${kg(r.ld)} m` }));
  }
  $("#ld-diagram-note").textContent = r.ld != null && r.ld_exigida != null
    ? `distância real ${kg(r.ld)} m × fator = ${kg(r.ld_exigida)} m exigidos · sobra ${kg(lda - r.ld_exigida)} m` : "";
}

(async function init() {
  try {
    state.meta = await api("/api/meta");
  } catch (e) {
    showCalcError(`Não consegui falar com o servidor (app.py): ${e.message}`);
    return;
  }
  restore(load(STORE.last, null), { quiet: true });
  renderPlanes(); renderSelectedRunways(); renderAirportRunways();
  renderRecents(); renderRecentAirports();
  $("#malha-path").value = state.meta.malha;
  $("#malha-path-field").hidden = state.meta.server;
  $("#malha-file-field").hidden = !state.meta.server;
  $("#malha-open").hidden = state.meta.server;
  renderRefs();
  $("#malha-count").textContent = `${countText(malhaForm.count())} por pista`;
  updateCalcButton();
})();
