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
  for (const page of ["calc", "malha"]) {
    const el = $(`#page-${page}`);
    el.hidden = page !== b.dataset.page;
    el.classList.toggle("active", page === b.dataset.page);
  }
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
  for (const r of state.runways) (groups[r.icao] ||= []).push(r.rwy + (r.edit ? "*" : ""));
  return Object.entries(groups).map(([icao, rwys]) => `${icao} ${rwys.join(", ")}`).join(" · ");
}
function snapshot() {
  return { planes: [...state.planes].map(planeLabel), runways: state.runways.map((r) => ({ ...r })), conds: calcForm.getState(),
    ...(Object.keys(state.flaps).length ? { flaps: { ...state.flaps } } : {}) };
}
function restore(snap, { quiet } = {}) {
  if (!snap) return;
  state.planes = new Set((snap.planes || []).map(planeIdOf).filter(Boolean));
  state.runways = (snap.runways || []).filter((r) => r && r.icao && r.rwy);
  state.flaps = Object.fromEntries(Object.entries(snap.flaps || {})        // antes: um codigo so
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
    class: `pill${state.runways.some((x) => x.icao === a.icao && x.rwy === r.rwy && x.edit) ? " edited" : ""}`,
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
    ...rws.map((r) => h("span", { class: `tag${r.edit ? " edited" : ""}`, title: r.edit ? editText(r.edit) : null }, r.rwy,
      r.edit ? h("small", { class: "flag", text: "editada" }) : null,
      h("button", { type: "button", class: "edit", title: `Editar dados de ${runwayId(r)} (pista parcialmente fechada etc.)`,
        "aria-label": `Editar ${runwayId(r)}`, text: "✎", onclick: () => openRunwayEditor(r) }),
      h("button", { type: "button", title: `Tirar ${runwayId(r)}`, "aria-label": `Tirar ${runwayId(r)}`, text: "×",
        onclick: () => { toggleRunway(r.icao, r.rwy); refreshRunways(); } }))))));
  const n = state.runways.length;
  $("#runways-count").textContent = String(n);
  $("#runways-count").toggleAttribute("data-zero", !n);
  $("#runways-hint").hidden = n > 0 || !!state.airport;
}

// ------------------------------------------------------------------ edicao dos dados da pista
/* Altera so o que vai para o calculo (RWYD 1, 3, 4, 5, 6, 8 e 11); os
 * obstaculos ficam os do cadastro. Limites iguais aos de app.py. */
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
  return "Editada: " + RW_FIELDS.filter((f) => f.key in edit).map((f) => `${f.label} ${fieldText(f, edit[f.key])}`).join(" · ");
}
const editor = $("#rw-editor");
let editing = null;   // { item, orig }
for (const b of editor.querySelectorAll('button[value="cancel"]')) b.formNoValidate = true;

async function openRunwayEditor(item) {
  let a;
  try { a = await getAirport(item.icao); } catch (e) { return alert(e.message); }
  const rw = a.runways.find((r) => r.rwy === item.rwy);
  if (!rw) return;
  const orig = { ...rw, surface: surfaceOf(rw.surface) };
  editing = { item, orig };
  $("#rwe-title").textContent = `Editar pista ${item.icao} ${item.rwy}`;
  $("#rwe-sub").textContent = `${a.name} · ${rw.obstacles.length ? `${rw.obstacles.length} obstáculo(s) do cadastro` : "sem obstáculos no cadastro"}`;
  $("#rwe-cut").value = "";
  $("#rwe-fields").replaceChildren(...RW_FIELDS.map((f) => {
    const value = item.edit?.[f.key] ?? orig[f.key];
    const input = f.key === "surface"
      ? h("select", { id: `rwe-${f.key}` }, h("option", { value: "normal", text: "Normal" }), h("option", { value: "grooved", text: "Grooved" }))
      : h("input", { id: `rwe-${f.key}`, type: "number", min: f.min, max: f.max, step: f.step, required: true, inputmode: "decimal" });
    input.value = value;
    input.addEventListener("input", markChanged);
    return h("div", { class: "rwe-field", "data-key": f.key },
      h("label", { for: `rwe-${f.key}`, text: `${f.label} (${f.rwyd})` }),
      h("div", { class: "row" }, input, f.unit ? h("span", { class: "unit", text: f.unit }) : null),
      h("small", { text: `Cadastro: ${fieldText(f, orig[f.key])}` }));
  }));
  markChanged();
  editor.showModal();
  $("#rwe-tora").focus();
}
function editorValues() {
  const out = {};
  for (const f of RW_FIELDS) {
    const el = $(`#rwe-${f.key}`);
    out[f.key] = f.key === "surface" ? el.value : el.value === "" ? null : Number(el.value);
  }
  return out;
}
function markChanged() {
  const v = editorValues();
  for (const f of RW_FIELDS) {
    $(`.rwe-field[data-key="${f.key}"]`).classList.toggle("changed", v[f.key] != null && v[f.key] !== editing.orig[f.key]);
  }
}
function setDistances(cut) {
  /* Fim da pista fechado: TORA perde o trecho; stopway e clearway ficam alem
   * do trecho fechado, entao ASDA e TODA passam a ser iguais a nova TORA. */
  const tora = Math.max(100, Math.round(editing.orig.tora - cut));
  for (const k of ["tora", "asda", "toda"]) $(`#rwe-${k}`).value = tora;
  markChanged();
}
$("#rwe-third").addEventListener("click", () => setDistances(editing.orig.tora / 3));
$("#rwe-cut-apply").addEventListener("click", () => {
  const cut = Number($("#rwe-cut").value);
  if ($("#rwe-cut").value === "" || !(cut >= 0)) return $("#rwe-cut").focus();
  setDistances(cut);
});
$("#rwe-cut").addEventListener("keydown", (e) => { if (e.key === "Enter") { e.preventDefault(); $("#rwe-cut-apply").click(); } });
$("#rwe-reset").addEventListener("click", () => {
  for (const f of RW_FIELDS) $(`#rwe-${f.key}`).value = editing.orig[f.key];
  markChanged();
});
editor.addEventListener("close", () => {
  if (editor.returnValue === "apply" && editing) {
    const v = editorValues(), edit = {};
    for (const f of RW_FIELDS) if (v[f.key] != null && v[f.key] !== editing.orig[f.key]) edit[f.key] = v[f.key];
    const { item } = editing;
    state.runways = state.runways.map((r) => (r.icao === item.icao && r.rwy === item.rwy
      ? (Object.keys(edit).length ? { icao: r.icao, rwy: r.rwy, edit } : { icao: r.icao, rwy: r.rwy }) : r));
    refreshRunways();
  }
  editor.returnValue = "";
  editing = null;
});

// ------------------------------------------------------------------ calculo
const calcBtn = $("#calc-btn");
const calcForm = conditionsForm($("#calc-conditions"), { onEnter: () => runCalc(), onChange: () => updateCalcButton() });
const busy = () => calcBtn.dataset.busy === "1";
/** Aeronaves x flaps: cada motor marcado conta uma vez por flap escolhido. */
function planeUnits() {
  return [...state.planes].reduce((sum, id) => sum + flapsOf(state.meta.aircraft[id.split(":")[0]]).length, 0);
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
    const planes = u === p ? `${p} aeronave${p > 1 ? "s" : ""}` : `${u} aeronave${u > 1 ? "s" : ""}/flap${u > 1 ? "s" : ""}`;
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
  const body = {
    selection: [...state.planes].map((id) => { const [i, j] = id.split(":"); return { aircraft: +i, variant: +j }; }),
    runways: state.runways.map((r) => ({ icao: r.icao, rwy: r.rwy, override: r.edit || null })), ...calcForm.spec(),
    flaps: Object.fromEntries(chosenModels().filter((a) => a.name in state.flaps).map((a) => [a.name, state.flaps[a.name]])),
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
    ...rw.filter((r) => r.edited).map((r) => h("span", { class: "edited" }, `${r.icao} ${r.rwy} editada: `,
      h("b", { text: `TORA ${kg(r.data.tora)} · ASDA ${kg(r.data.asda)} · TODA ${kg(r.data.toda)} m · elev. ${kg(r.data.elev)} ft · `
        + `slope ${num(r.data.slope)}% · ${surfaceText(surfaceOf(r.data.surface))} · largura ${kg(r.data.width)} m` }))),
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
    return h("div", { class: "ref-item" }, h("label", { text: a.name, for: `ref-${a.id}` }),
      h("div", { class: "row" }, input, h("small", { text: "kg" })),
      h("small", { text: a.structural ? `estrutural ${kg(a.structural)} kg` : "estrutural do motor" }),
      flap);
  }));
}
malhaBtn.addEventListener("click", runMalha);
$("#malha-open").addEventListener("click", () => api("/api/open", { job: malhaJob }).catch((e) => alert(e.message)));

async function runMalha() {
  if (malhaBtn.disabled) return;
  if (malhaForm.count() == null) { alert("Confira os valores das faixas."); return; }
  const body = { path: $("#malha-path").value, refs: load(STORE.refs, {}), flaps: load(STORE.malhaFlaps, {}), ...malhaForm.spec() };
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
