#!/usr/bin/env python3
"""Frontend: escolhe aeronave/motor, aeroporto e pista e calcula a performance
de decolagem para uma temperatura ou para uma faixa de temperaturas."""

import csv
import os
import platform
import re
import subprocess
import threading
import tkinter as tk
import tkinter.font as tkfont
from pathlib import Path
from tkinter import messagebox, ttk

import malha
import scap_engine
from aircraft import AIRCRAFT
from airports import align_values, load_airports, load_toalign
from batch import COLUMNS, condition_columns, result_row, temperatures

HERE = Path(__file__).resolve().parent
RESULTS_DIR = HERE / "resultados"
ASSETS = HERE / "assets"

C = {
    "bg": "#F3F5F9", "card": "#FFFFFF", "line": "#E2E6EE",
    "brand": "#00338E", "brand_dark": "#002470", "accent": "#00A9EF",
    "text": "#1C2433", "muted": "#6B7385", "soft": "#F2F5FA",
    "zebra": "#F8FAFD", "error": "#B42318", "error_bg": "#FEF3F2",
}

# limitation.lis, em portugues
LIMITS = {
    0: "Verificação de pista seca", 1: "Peso estrutural",
    2: "Distância – todos os motores", 3: "Distância – motor inoperante",
    9: "VMCG", 10: "Velocidade dos pneus", 12: "Energia dos freios",
    13: "V2 mínimo (VMCA)", 14: "Subida – 1º segmento",
    15: "Subida – 2º segmento", 17: "Aceleração (3º segmento)",
    18: "Subida – segmento final", 19: "Obstáculo",
    20: "Corrida – motor inoperante", 21: "Corrida – todos os motores",
    24: "Inclinação da pista", 25: "Pista – motor inoperante",
    26: "Pista – todos os motores", 30: "V2 mínimo (VMU)", 51: "Arremetida",
}


def limit_text(code):
    return LIMITS.get(code, f"Código {code}") if code != "" else ""


def num(value, decimals=0):
    """Numero no formato brasileiro: 78.764 / -0,48."""
    text = f"{value:,.{decimals}f}"
    return text.replace(",", "X").replace(".", ",").replace("X", ".")


def speed(value):
    return "–" if value in (None, "") else f"{value:.0f}"


def v1_text(row):
    lo, hi = row.get("v1_min_kt"), row.get("v1_max_kt")
    if lo in (None, ""):
        return "–"
    return f"{lo:.0f}" if round(lo) == round(hi) else f"{lo:.0f}–{hi:.0f}"


def qnh_text(q):
    """QNH sem separador de milhar: 1000 / 1013,25."""
    return f"{q:g}".replace(".", ",")


def wind_text(cond, unit=True):
    kt = " kt" if unit else ""
    if cond.crosswind:
        side = "D" if cond.crosswind > 0 else "E"
        return f"través {abs(cond.crosswind):g}{kt} ({side})"
    if cond.wind > 0:
        return f"proa {cond.wind:g}{kt}"
    if cond.wind < 0:
        return f"cauda {-cond.wind:g}{kt}"
    return "sem vento"


def describe_cases(cases):
    """Texto curto das condicoes: valor unico ou faixa de cada grandeza."""
    temps = sorted({t for t, _ in cases})
    winds = sorted({(c.wind, c.crosswind) for _, c in cases})
    qnhs = sorted({c.qnh for _, c in cases})
    parts = [f"{num(temps[0], 0)} °C" if len(temps) == 1 else
             f"{num(temps[0], 0)} a {num(temps[-1], 0)} °C"]
    parts.append(wind_text(cases[0][1]) if len(winds) == 1 else
                 f"vento {winds[0][0]:g} a {winds[-1][0]:g} kt")
    parts.append(f"QNH {qnh_text(qnhs[0])} hPa" if len(qnhs) == 1 else
                 f"QNH {qnh_text(qnhs[0])} a {qnh_text(qnhs[-1])} hPa")
    return "   ·   ".join(parts)


def cases_slug(cases):
    """Pedaco do nome do arquivo com as condicoes."""
    temps = sorted({t for t, _ in cases})
    winds = sorted({(c.wind, c.crosswind) for _, c in cases})
    qnhs = sorted({c.qnh for _, c in cases})
    slug = f"{temps[0]}C" if len(temps) == 1 else f"{temps[0]}a{temps[-1]}C"
    if len(winds) > 1:
        slug += f"_vento{winds[0][0]:g}a{winds[-1][0]:g}kt"
    elif winds[0] != (0, 0):
        w, x = winds[0]
        slug += (f"_traves{x:+g}kt" if x else
                 f"_{'proa' if w > 0 else 'cauda'}{abs(w):g}kt")
    if len(qnhs) > 1:
        slug += f"_QNH{qnhs[0]:g}a{qnhs[-1]:g}"
    elif qnhs[0] != scap_engine.CALM.qnh:
        slug += f"_QNH{qnhs[0]:g}"
    return slug


def open_path(path):
    if platform.system() == "Windows":
        os.startfile(path)
    else:
        opener = "open" if platform.system() == "Darwin" else "xdg-open"
        subprocess.Popen([opener, str(path)])


class Frontend:
    def __init__(self, root):
        self.root = root
        root.title("Performance de Decolagem")
        root.geometry("1260x995")
        root.minsize(1160, 940)
        root.configure(bg=C["bg"])

        self.airports = load_airports()
        self.toalign = load_toalign()
        self.airport_labels = [f"{icao} – {a['name'].title()}"
                               for icao, a in sorted(self.airports.items())]
        self.last_csv = None
        self.images = {}

        self.setup_fonts()
        self.setup_style()
        self.load_images()

        self.build_header()
        body = tk.Frame(root, bg=C["bg"])
        body.pack(fill=tk.BOTH, expand=True, padx=24, pady=(20, 8))
        body.columnconfigure(0, minsize=372)
        body.columnconfigure(1, weight=1)
        body.rowconfigure(0, weight=1)

        form = tk.Frame(body, bg=C["bg"])
        form.grid(row=0, column=0, sticky=tk.NSEW, padx=(0, 20))
        self.build_form(form)

        self.results = self.card(body, "Resultado", pack=False)
        self.results[0].grid(row=0, column=1, sticky=tk.NSEW)
        self.build_results(self.results[1])

        self.status_var = tk.StringVar()
        tk.Label(root, textvariable=self.status_var, bg=C["bg"],
                 fg=C["muted"], font=self.f_small, anchor=tk.W).pack(
            fill=tk.X, padx=24, pady=(0, 12))

        self.aircraft_box.current(0)
        self.on_aircraft()
        self.show_view("empty")

    # ------------------------------------------------------------ visual

    def setup_fonts(self):
        families = set(tkfont.families())
        family = next((f for f in ("Segoe UI", "Inter", "Noto Sans",
                                   "Ubuntu", "DejaVu Sans") if f in families),
                      "TkDefaultFont")
        F = lambda size, weight="normal": tkfont.Font(family=family,
                                                       size=size, weight=weight)
        self.f_body = F(11)
        self.f_small = F(9)
        self.f_label = F(9, "bold")
        self.f_title = F(15, "bold")
        self.f_button = F(12, "bold")
        self.f_hero = F(44, "bold")
        self.f_hero_unit = F(18)
        self.f_tile = F(22, "bold")
        self.f_chip = F(11, "bold")
        self.root.option_add("*TCombobox*Listbox.font", self.f_body)
        self.root.option_add("*TCombobox*Listbox.selectBackground", C["brand"])

    def setup_style(self):
        s = ttk.Style(self.root)
        s.theme_use("clam")
        s.configure("TCombobox", padding=7, fieldbackground=C["card"],
                    background=C["card"], bordercolor=C["line"],
                    lightcolor=C["card"], darkcolor=C["card"],
                    arrowcolor=C["brand"], foreground=C["text"])
        s.map("TCombobox",
              fieldbackground=[("readonly", C["card"])],
              foreground=[("readonly", C["text"])],
              selectbackground=[("focus", C["card"]), ("readonly", C["card"])],
              selectforeground=[("focus", C["text"]), ("readonly", C["text"])],
              bordercolor=[("focus", C["accent"])])
        s.configure("TEntry", padding=7, fieldbackground=C["card"],
                    bordercolor=C["line"], lightcolor=C["card"],
                    darkcolor=C["card"], foreground=C["text"])
        s.map("TEntry", bordercolor=[("focus", C["accent"])])
        s.configure("Brand.Horizontal.TProgressbar", troughcolor=C["soft"],
                    background=C["accent"], bordercolor=C["soft"],
                    lightcolor=C["accent"], darkcolor=C["accent"],
                    thickness=6)
        s.configure("Results.Treeview", background=C["card"],
                    fieldbackground=C["card"], foreground=C["text"],
                    rowheight=32, borderwidth=0, font=self.f_body)
        s.map("Results.Treeview",
              background=[("selected", "#E6EEFB")],
              foreground=[("selected", C["text"])])
        s.layout("Results.Treeview",
                 [("Results.Treeview.treearea", {"sticky": "nswe"})])
        s.configure("Results.Treeview.Heading", background=C["card"],
                    foreground=C["muted"], font=self.f_label, relief="flat",
                    borderwidth=0, padding=(6, 8))
        s.map("Results.Treeview.Heading",
              background=[("active", C["card"])])
        s.configure("Vertical.TScrollbar", background=C["soft"],
                    troughcolor=C["card"], bordercolor=C["card"],
                    arrowcolor=C["muted"], lightcolor=C["soft"],
                    darkcolor=C["soft"])

    def load_images(self):
        for name in ("plane", "icon"):
            try:
                self.images[name] = tk.PhotoImage(file=ASSETS / f"{name}.png")
            except tk.TclError:
                pass
        if "icon" in self.images:
            self.root.iconphoto(True, self.images["icon"])

    def card(self, parent, title, pack=True):
        outer = tk.Frame(parent, bg=C["card"], highlightthickness=1,
                         highlightbackground=C["line"],
                         highlightcolor=C["line"])
        tk.Label(outer, text=title.upper(), bg=C["card"], fg=C["muted"],
                 font=self.f_label).pack(anchor=tk.W, padx=18, pady=(12, 6))
        inner = tk.Frame(outer, bg=C["card"])
        inner.pack(fill=tk.BOTH, expand=True, padx=18, pady=(0, 14))
        if pack:
            outer.pack(fill=tk.X, pady=(0, 10))
        return outer, inner

    def field(self, parent, label, widget_factory):
        tk.Label(parent, text=label, bg=C["card"], fg=C["muted"],
                 font=self.f_small).pack(anchor=tk.W, pady=(4, 3))
        widget = widget_factory(parent)
        widget.pack(fill=tk.X)
        return widget

    # ------------------------------------------------------------ layout

    def build_header(self):
        header = tk.Frame(self.root, bg=C["card"])
        header.pack(fill=tk.X)
        inner = tk.Frame(header, bg=C["card"])
        inner.pack(fill=tk.X, padx=24, pady=12)
        tk.Frame(inner, bg=C["accent"], width=4, height=26).pack(
            side=tk.LEFT, padx=(0, 12))
        tk.Label(inner, text="Performance de Decolagem", bg=C["card"],
                 fg=C["brand"], font=self.f_title).pack(side=tk.LEFT)
        malha = tk.Button(
            inner, text="Calcular malha", font=self.f_label, bg=C["card"],
            fg=C["brand"], activebackground=C["soft"],
            activeforeground=C["brand"], relief=tk.FLAT, bd=0,
            highlightthickness=1, highlightbackground=C["brand"],
            highlightcolor=C["brand"], padx=14, pady=6, cursor="hand2",
            command=lambda: MalhaDialog(self))
        malha.pack(side=tk.RIGHT)
        tk.Frame(self.root, bg=C["brand"], height=3).pack(fill=tk.X)

    def build_form(self, form):
        _, body = self.card(form, "Aeronave")
        self.aircraft_box = self.field(body, "Modelo", lambda p: ttk.Combobox(
            p, state="readonly", font=self.f_body,
            values=[a.name for a in AIRCRAFT]))
        self.aircraft_box.bind("<<ComboboxSelected>>", self.on_aircraft)
        self.variant_box = self.field(body, "Motor", lambda p: ttk.Combobox(
            p, state="readonly", font=self.f_body))
        self.variant_box.bind("<<ComboboxSelected>>", self.on_variant)

        _, body = self.card(form, "Aeroporto")
        self.airport_var = tk.StringVar()
        self.airport_box = self.field(
            body, "Busque pelo código ou nome", lambda p: ttk.Combobox(
                p, textvariable=self.airport_var, font=self.f_body,
                values=self.airport_labels))
        self.airport_box.bind("<KeyRelease>", self.filter_airports)
        self.airport_box.bind("<<ComboboxSelected>>", self.on_airport)
        self.airport_box.bind("<Return>", self.on_airport)
        self.runway_box = self.field(body, "Pista", lambda p: ttk.Combobox(
            p, state="readonly", font=self.f_body))
        self.runway_box.bind("<<ComboboxSelected>>", self.on_runway)
        self.runway_var = tk.StringVar()
        tk.Label(body, textvariable=self.runway_var, bg=C["card"],
                 fg=C["muted"], font=self.f_small, justify=tk.LEFT,
                 anchor=tk.W, wraplength=330).pack(fill=tk.X, pady=(10, 0))

        _, body = self.card(form, "Condições")
        self.panel = ConditionsPanel(self, body, on_enter=self.run)

        self.run_button = tk.Button(
            form, text="Calcular", font=self.f_button, bg=C["brand"],
            fg="white", activebackground=C["brand_dark"],
            activeforeground="white", disabledforeground="#C9D3E8",
            relief=tk.FLAT, bd=0, cursor="hand2", pady=10,
            highlightthickness=0, command=self.run)
        self.run_button.pack(fill=tk.X, pady=(2, 0))
        self.progress = ttk.Progressbar(form, style="Brand.Horizontal.TProgressbar")

    def temp_entry(self, parent, var, width, padx=(0, 0)):
        entry = ttk.Entry(parent, textvariable=var, width=width,
                          font=self.f_body, justify=tk.CENTER)
        entry.pack(side=tk.LEFT, padx=padx)
        entry.bind("<Return>", lambda _e: self.run())
        return entry

    def small_label(self, parent, text, top=0):
        label = tk.Label(parent, text=text, bg=C["card"], fg=C["muted"],
                         font=self.f_small)
        label.pack(anchor=tk.W, pady=(top, 4))
        return label

    def segmented(self, parent, options, command, pady=(0, 10), ipady=5):
        """Botoes lado a lado; o escolhido fica azul."""
        seg = tk.Frame(parent, bg=C["soft"], padx=3, pady=3)
        seg.pack(side=tk.LEFT if pady == (0, 0) else tk.TOP,
                 fill=tk.X, pady=pady)
        buttons = {}
        for key, text in options:
            b = tk.Label(seg, text=text, font=self.f_body, cursor="hand2",
                         pady=ipady, padx=8)
            b.pack(side=tk.LEFT, fill=tk.X, expand=True)
            b.bind("<Button-1>", lambda _e, k=key: command(k))
            buttons[key] = b
        return buttons

    @staticmethod
    def highlight(buttons, selected):
        for key, b in buttons.items():
            on = key == selected
            b.configure(bg=C["brand"] if on else C["soft"],
                        fg="white" if on else C["text"])

    def build_results(self, parent):
        self.views = {}

        # vazio
        view = tk.Frame(parent, bg=C["card"])
        center = tk.Frame(view, bg=C["card"])
        center.place(relx=0.5, rely=0.45, anchor=tk.CENTER)
        if "plane" in self.images:
            tk.Label(center, image=self.images["plane"], bg=C["card"]).pack()
        tk.Label(center, text="Escolha a aeronave e a pista\n"
                              "e clique em Calcular",
                 bg=C["card"], fg=C["muted"], font=self.f_body,
                 justify=tk.CENTER).pack(pady=(16, 0))
        self.views["empty"] = view

        # calculando
        view = tk.Frame(parent, bg=C["card"])
        self.loading_var = tk.StringVar()
        tk.Label(view, textvariable=self.loading_var, bg=C["card"],
                 fg=C["muted"], font=self.f_title).place(
            relx=0.5, rely=0.45, anchor=tk.CENTER)
        self.views["loading"] = view

        # uma temperatura
        view = tk.Frame(parent, bg=C["card"])
        self.single_title = tk.StringVar()
        tk.Label(view, textvariable=self.single_title, bg=C["card"],
                 fg=C["muted"], font=self.f_body, anchor=tk.W).pack(
            fill=tk.X)
        hero = tk.Frame(view, bg=C["card"])
        hero.pack(anchor=tk.W, pady=(18, 0))
        self.mtow_var = tk.StringVar()
        tk.Label(hero, textvariable=self.mtow_var, bg=C["card"],
                 fg=C["brand"], font=self.f_hero).pack(side=tk.LEFT)
        tk.Label(hero, text="kg", bg=C["card"], fg=C["brand"],
                 font=self.f_hero_unit).pack(side=tk.LEFT, anchor=tk.S,
                                             pady=(0, 12), padx=(8, 0))
        tk.Label(view, text="Peso máximo de decolagem", bg=C["card"],
                 fg=C["muted"], font=self.f_body).pack(anchor=tk.W)

        chips = tk.Frame(view, bg=C["card"])
        chips.pack(anchor=tk.W, pady=(22, 0))
        self.flap_var, self.limit_var = tk.StringVar(), tk.StringVar()
        for label, var in (("Flap", self.flap_var),
                           ("Limitado por", self.limit_var)):
            chip = tk.Frame(chips, bg=C["soft"], padx=14, pady=8)
            chip.pack(side=tk.LEFT, padx=(0, 10))
            tk.Label(chip, text=label, bg=C["soft"], fg=C["muted"],
                     font=self.f_small).pack(anchor=tk.W)
            tk.Label(chip, textvariable=var, bg=C["soft"], fg=C["text"],
                     font=self.f_chip).pack(anchor=tk.W)

        tiles = self.tiles = tk.Frame(view, bg=C["card"])
        tiles.pack(fill=tk.X, pady=(22, 0))
        self.speed_vars = {}
        for i, name in enumerate(("V1", "VR", "V2")):
            tiles.columnconfigure(i, weight=1, uniform="tiles")
            tile = tk.Frame(tiles, bg=C["card"], highlightthickness=1,
                            highlightbackground=C["line"],
                            highlightcolor=C["line"], padx=16, pady=12)
            tile.grid(row=0, column=i, sticky=tk.EW,
                      padx=(0 if i == 0 else 6, 0 if i == 2 else 6))
            var = tk.StringVar()
            tk.Label(tile, text=f"{name}  (kt)", bg=C["card"], fg=C["muted"],
                     font=self.f_small).pack(anchor=tk.W)
            tk.Label(tile, textvariable=var, bg=C["card"], fg=C["text"],
                     font=self.f_tile).pack(anchor=tk.W)
            self.speed_vars[name] = var
        self.no_speeds = tk.Label(
            view, text="V1, VR e V2 não são informados pelo takeoff_module "
                       "para esta aeronave.", bg=C["card"], fg=C["muted"],
            font=self.f_small)
        self.views["single"] = view

        # varias temperaturas
        view = tk.Frame(parent, bg=C["card"])
        self.range_title = tk.StringVar()
        self.range_summary = tk.StringVar()
        tk.Label(view, textvariable=self.range_title, bg=C["card"],
                 fg=C["muted"], font=self.f_body, anchor=tk.W).pack(fill=tk.X)
        tk.Label(view, textvariable=self.range_summary, bg=C["card"],
                 fg=C["text"], font=self.f_chip, anchor=tk.W,
                 justify=tk.LEFT).pack(fill=tk.X, pady=(6, 12))
        table = tk.Frame(view, bg=C["card"], highlightthickness=1,
                         highlightbackground=C["line"],
                         highlightcolor=C["line"])
        table.pack(fill=tk.BOTH, expand=True)
        cols = (("temp", "TEMP", 58, tk.CENTER),
                ("wind", "VENTO", 82, tk.CENTER),
                ("qnh", "QNH", 62, tk.CENTER),
                ("mtow", "MTOW (KG)", 80, tk.E),
                ("flap", "FLAP", 70, tk.CENTER),
                ("limit", "LIMITADO POR", 210, tk.W),
                ("v1", "V1", 60, tk.CENTER), ("vr", "VR", 40, tk.CENTER),
                ("v2", "V2", 40, tk.CENTER))
        self.tree = ttk.Treeview(table, columns=[c[0] for c in cols],
                                 show="headings", style="Results.Treeview")
        for key, title, width, anchor in cols:
            self.tree.heading(key, text=title, anchor=anchor)
            self.tree.column(key, width=width, minwidth=min(width, 40),
                             anchor=anchor, stretch=True)
        self.tree.tag_configure("odd", background=C["zebra"])
        self.tree.tag_configure("error", foreground=C["error"])
        scroll = ttk.Scrollbar(table, command=self.tree.yview)
        self.tree.configure(yscrollcommand=scroll.set)
        self.tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scroll.pack(side=tk.RIGHT, fill=tk.Y)
        self.views["range"] = view

        # erro (uma temperatura)
        view = tk.Frame(parent, bg=C["card"])
        box = tk.Frame(view, bg=C["error_bg"], padx=18, pady=16)
        box.pack(fill=tk.X)
        tk.Label(box, text="Não foi possível calcular", bg=C["error_bg"],
                 fg=C["error"], font=self.f_chip).pack(anchor=tk.W)
        self.error_var = tk.StringVar()
        tk.Label(box, textvariable=self.error_var, bg=C["error_bg"],
                 fg=C["text"], font=self.f_small, justify=tk.LEFT,
                 wraplength=560).pack(anchor=tk.W, pady=(6, 0))
        self.views["error"] = view

        # rodape com o CSV
        self.footer = tk.Frame(parent, bg=C["card"])
        self.saved_var = tk.StringVar()
        tk.Label(self.footer, textvariable=self.saved_var, bg=C["card"],
                 fg=C["muted"], font=self.f_small).pack(side=tk.LEFT)
        open_csv = tk.Label(self.footer, text="Abrir planilha", bg=C["card"],
                            fg=C["brand"], font=self.f_label, cursor="hand2")
        open_csv.pack(side=tk.RIGHT)
        open_csv.bind("<Button-1>", lambda _e: self.last_csv
                      and open_path(self.last_csv))

    def show_view(self, name):
        for view in self.views.values():
            view.pack_forget()
        self.footer.pack_forget()
        self.views[name].pack(fill=tk.BOTH, expand=True)
        if name in ("single", "range") and self.last_csv:
            self.footer.pack(fill=tk.X, side=tk.BOTTOM, pady=(12, 0))

    # ---------------------------------------------------------- selecao

    def selected(self):
        aircraft = AIRCRAFT[self.aircraft_box.current()]
        return aircraft, aircraft.variants[self.variant_box.current()]

    def selected_runway(self):
        icao = self.airport_var.get().split("–", 1)[0].strip().upper()
        airport = self.airports.get(icao)
        rwy = self.runway_box.get()
        if not airport or rwy not in airport["runways"]:
            return None
        return airport["runways"][rwy]

    def on_aircraft(self, _event=None):
        aircraft = AIRCRAFT[self.aircraft_box.current()]
        self.variant_box["values"] = [v.display for v in aircraft.variants]
        self.variant_box.current(0)
        self.on_variant()

    def on_variant(self, _event=None):
        aircraft, variant = self.selected()
        ready = False
        if not aircraft.supported:
            self.status_var.set(f"O {aircraft.name} ainda não pode ser "
                                f"calculado por aqui.")
        else:
            try:
                scap_engine.check(aircraft, variant)
                ready = True
                self.status_var.set(f"Base de dados: {variant.acmdbi}")
            except scap_engine.ScapError as e:
                self.status_var.set(str(e).replace("\n", " "))
        self.run_button.configure(state=tk.NORMAL if ready else tk.DISABLED,
                                  bg=C["brand"] if ready else C["muted"])
        self.on_runway()

    def filter_airports(self, event):
        if event.keysym in ("Up", "Down", "Return", "Escape", "Tab"):
            return
        text = self.airport_var.get().strip().upper()
        self.airport_box["values"] = [a for a in self.airport_labels
                                      if text in a.upper()]

    def on_airport(self, _event=None):
        icao = self.airport_var.get().split("–", 1)[0].strip().upper()
        airport = self.airports.get(icao)
        if not airport:
            self.runway_box["values"] = []
            self.runway_box.set("")
            self.runway_var.set(f"Não encontrei o aeroporto “{icao}”.")
            return
        self.airport_var.set(f"{icao} – {airport['name'].title()}")
        self.airport_box["values"] = self.airport_labels
        self.runway_box["values"] = list(airport["runways"])
        self.runway_box.current(0)
        self.on_runway()

    def on_runway(self, _event=None):
        rw = self.selected_runway()
        if rw is None:
            self.runway_var.set("")
            return
        n = len(rw.obstacles)
        obst = ("sem obstáculos" if n == 0 else
                f"{n} obstáculo" + ("s" if n > 1 else ""))
        align = rw.to_align or "0"
        self.runway_var.set(
            f"{num(rw.tora)} m de pista  ·  TODA {num(rw.toda)}  ·  "
            f"ASDA {num(rw.asda)}\n"
            f"Elevação {num(rw.elev)} ft  ·  inclinação {num(rw.slope, 2)}%"
            f"  ·  {num(rw.width)} m de largura\n"
            f"{obst.capitalize()}  ·  alinhamento {align}°".replace(
                "180PAD°", "180° (pad)"))

    # ---------------------------------------------------------- calculo

    def run(self):
        if str(self.run_button["state"]) == tk.DISABLED:
            return
        aircraft, variant = self.selected()
        rw = self.selected_runway()
        if rw is None:
            messagebox.showinfo("Pista", "Escolha o aeroporto e a pista.")
            return
        try:
            cases = self.panel.cases()
            align = align_values(rw, aircraft.align, self.toalign)
            scap_engine.check(aircraft, variant)
        except (ValueError, scap_engine.ScapError) as e:
            messagebox.showerror("Não foi possível calcular", str(e))
            return
        if len(cases) > 300 and not messagebox.askyesno(
                "Muitos cálculos",
                f"São {len(cases)} combinações de temperatura, vento e QNH. "
                f"Calcular mesmo assim?"):
            return

        self.run_button.configure(state=tk.DISABLED, bg=C["muted"],
                                  text="Calculando…")
        self.progress.configure(maximum=len(cases), value=0)
        self.progress.pack(fill=tk.X, pady=(10, 0))
        self.loading_var.set("Calculando…" if len(cases) == 1 else
                             f"Calculando 0 de {len(cases)}…")
        self.show_view("loading")

        def progress(done, total):
            def update():
                self.progress.configure(value=done)
                if total > 1:
                    self.loading_var.set(f"Calculando {done} de {total}…")
            self.root.after(0, update)

        def work():
            try:
                results = scap_engine.compute_cases(
                    aircraft, variant, rw, cases, on_progress=progress,
                    align=align)
                error = None
            except scap_engine.ScapError as e:
                results, error = [], str(e)
            self.root.after(0, self.done, aircraft, variant, rw, cases,
                            results, error)

        threading.Thread(target=work, daemon=True).start()

    def done(self, aircraft, variant, rw, cases, results, error):
        self.run_button.configure(state=tk.NORMAL, bg=C["brand"],
                                  text="Calcular")
        self.progress.pack_forget()
        if error:
            self.error_var.set(error)
            self.show_view("error")
            return

        rows = []
        for (temp, cond), res in zip(cases, results):
            row = {"aircraft": aircraft.name, "engine": variant.display,
                   "icao": rw.icao, "airport": rw.name, "rwy": rw.rwy,
                   "to_align": rw.to_align, "n_obst": len(rw.obstacles),
                   "temp_c": temp, **condition_columns(cond), "cond": cond}
            if "error" in res:
                row["error"] = " | ".join(res["error"].split("\n"))
            else:
                row.update(result_row(res))
            rows.append(row)

        self.last_csv = self.save(rows, aircraft, variant, rw, cases)
        self.saved_var.set(f"Salvo em resultados/{self.last_csv.name}")
        title = (f"{rw.icao} · pista {rw.rwy}   ·   {aircraft.name} "
                 f"{variant.display}   ·   {describe_cases(cases)}")
        errors = sum(bool(r.get("error")) for r in rows)
        self.status_var.set(f"{len(rows) - errors} de {len(rows)} "
                            f"cálculo(s) concluído(s).")

        if len(rows) == 1:
            self.show_single(rows[0], title)
        else:
            self.show_range(rows, title)

    def show_single(self, row, title):
        if row.get("error"):
            self.error_var.set(row["error"])
            self.show_view("error")
            return
        self.single_title.set(title)
        self.mtow_var.set(num(row["mtow_kg"]))
        self.flap_var.set(row["flap"])
        self.limit_var.set(limit_text(row["limit_code"]))
        self.speed_vars["V1"].set(v1_text(row))
        self.speed_vars["VR"].set(speed(row["vr_kt"]))
        self.speed_vars["V2"].set(speed(row["v2_kt"]))
        self.tiles.pack_forget()
        self.no_speeds.pack_forget()
        if row["vr_kt"] is None:
            self.no_speeds.pack(anchor=tk.W, pady=(22, 0))
        else:
            self.tiles.pack(fill=tk.X, pady=(22, 0))
        self.show_view("single")

    def show_range(self, rows, title):
        self.tree.delete(*self.tree.get_children())
        for i, row in enumerate(rows):
            temp = f"{num(row['temp_c'], 0)} °C"
            cond = row["cond"]
            head = (temp, wind_text(cond, unit=False), qnh_text(cond.qnh))
            if row.get("error"):
                values = head + ("–", "–", "Erro: " + row["error"][:60],
                                 "–", "–", "–")
                tags = ("error",)
            else:
                values = head + (num(row["mtow_kg"]), row["flap"],
                                 limit_text(row["limit_code"]), v1_text(row),
                                 speed(row["vr_kt"]), speed(row["v2_kt"]))
                tags = ("odd",) if i % 2 else ()
            self.tree.insert("", tk.END, values=values, tags=tags)

        ok = [r for r in rows if not r.get("error")]
        self.range_title.set(title)
        if ok:
            def where(r):
                return (f"{num(r['temp_c'], 0)} °C, {wind_text(r['cond'])}, "
                        f"QNH {qnh_text(r['cond'].qnh)}")
            hi = max(ok, key=lambda r: r["mtow_kg"])
            lo = min(ok, key=lambda r: r["mtow_kg"])
            self.range_summary.set(
                f"Maior MTOW  {num(hi['mtow_kg'])} kg   ({where(hi)})\n"
                f"Menor MTOW  {num(lo['mtow_kg'])} kg   ({where(lo)})")
        else:
            self.range_summary.set("Nenhum cálculo deu certo.")
        self.show_view("range")

    def save(self, rows, aircraft, variant, rw, cases):
        RESULTS_DIR.mkdir(exist_ok=True)
        name = (f"{rw.icao}_{rw.rwy}_{aircraft.name}_{variant.display}_"
                f"{cases_slug(cases)}")
        name = re.sub(r"[^\w.+-]+", "_", name.replace("/", "-")).strip("_")
        path = RESULTS_DIR / f"{name}.csv"
        with open(path, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, COLUMNS, extrasaction="ignore")
            writer.writeheader()
            writer.writerows(rows)
        return path


class ConditionsPanel:
    """Temperatura, vento (relativo a pista) e QNH, cada um com Uma/Varias.
    cases() devolve a lista de combinacoes (temperatura, Conditions)."""

    MAX_CASES = 3000

    def __init__(self, app, parent, on_enter=None, temp_mode="single"):
        self.app = app
        self.on_enter = on_enter
        self.modes, self.toggles, self.frames = {}, {}, {}
        self.vars = {}

        # temperatura
        single, multi = self.block(parent, "temp", "Temperatura")
        self.vars["temp"] = self.entry(single, "25", 7)
        self.unit(single, "°C")
        self.range_row(multi, "temp", ("-10", "45", "1"), "°C")

        # vento
        single, multi = self.block(parent, "wind", "Vento (em relação à pista)",
                                   top=12)
        self.kind_buttons = app.segmented(
            single, (("calm", "Sem vento"), ("head", "Proa"),
                     ("tail", "Cauda"), ("cross", "Través")),
            self.set_kind, pady=(0, 8), ipady=5)
        self.speed_row = tk.Frame(single, bg=C["card"])
        self.vars["wind"] = self.entry(self.speed_row, "10", 5)
        self.unit(self.speed_row, "kt", right=12)
        self.side_frame = tk.Frame(self.speed_row, bg=C["card"])
        self.side_buttons = app.segmented(
            self.side_frame, (("right", "da direita"), ("left", "da esquerda")),
            self.set_side, pady=(0, 0), ipady=3)
        self.range_row(multi, "wind", ("-10", "20", "5"), "kt")

        # QNH
        single, multi = self.block(parent, "qnh", "QNH", top=12)
        self.vars["qnh"] = self.entry(single, "1013,25", 8)
        self.unit(single, "hPa")
        self.range_row(multi, "qnh", ("990", "1030", "10"), "hPa")

        self.set_side("right")
        self.set_kind("calm")
        for key in ("temp", "wind", "qnh"):
            self.set_mode(key, temp_mode if key == "temp" else "single")

    # ------------------------------------------------------------ layout

    def block(self, parent, key, title, top=0):
        header = tk.Frame(parent, bg=C["card"])
        header.pack(fill=tk.X, pady=(top, 4))
        label = tk.Label(header, text=title, bg=C["card"], fg=C["muted"],
                         font=self.app.f_small)
        label.pack(side=tk.LEFT)
        toggle = tk.Frame(header, bg=C["soft"], padx=2, pady=2)
        toggle.pack(side=tk.RIGHT)
        buttons = {}
        for mode, text in (("single", "Uma"), ("range", "Várias")):
            b = tk.Label(toggle, text=text, font=self.app.f_small,
                         cursor="hand2", padx=8, pady=1)
            b.pack(side=tk.LEFT)
            b.bind("<Button-1>", lambda _e, m=mode: self.set_mode(key, m))
            buttons[mode] = b
        holder = tk.Frame(parent, bg=C["card"])
        holder.pack(fill=tk.X)
        single = tk.Frame(holder, bg=C["card"])
        multi = tk.Frame(holder, bg=C["card"])
        self.toggles[key] = buttons
        self.frames[key] = (single, multi, label, title)
        return single, multi

    def entry(self, parent, value, width, padx=(0, 0)):
        var = tk.StringVar(value=value)
        e = ttk.Entry(parent, textvariable=var, width=width,
                      font=self.app.f_body, justify=tk.CENTER)
        e.pack(side=tk.LEFT, padx=padx)
        if self.on_enter:
            e.bind("<Return>", lambda _e: self.on_enter())
        return var

    def unit(self, parent, text, right=0):
        tk.Label(parent, text=text, bg=C["card"], fg=C["muted"],
                 font=self.app.f_body).pack(side=tk.LEFT, padx=(8, right))

    def range_row(self, parent, key, defaults, unit):
        vars_ = []
        for label, value in zip(("De", "até", "a cada"), defaults):
            tk.Label(parent, text=label, bg=C["card"], fg=C["muted"],
                     font=self.app.f_body).pack(side=tk.LEFT, padx=(0, 6))
            vars_.append(self.entry(parent, value, 5, (0, 10)))
        tk.Label(parent, text=unit, bg=C["card"], fg=C["muted"],
                 font=self.app.f_body).pack(side=tk.LEFT)
        self.vars[key + "_range"] = vars_

    def set_mode(self, key, mode):
        self.modes[key] = mode
        self.app.highlight(self.toggles[key], mode)
        single, multi, label, title = self.frames[key]
        single.pack_forget()
        multi.pack_forget()
        (single if mode == "single" else multi).pack(anchor=tk.W, fill=tk.X)
        if key == "wind":
            label.configure(text=title + ("  ·  negativo = cauda"
                                          if mode == "range" else ""))
            if mode == "single":
                self.set_kind(self.kind)

    def set_kind(self, kind):
        self.kind = kind
        self.app.highlight(self.kind_buttons, kind)
        self.speed_row.pack_forget()
        self.side_frame.pack_forget()
        if kind != "calm":
            self.speed_row.pack(anchor=tk.W)
        if kind == "cross":
            self.side_frame.pack(side=tk.LEFT)
        if self.modes.get("wind", "single") == "single":
            _, _, label, title = self.frames["wind"]
            label.configure(text=title + ("  ·  través só entra no Airbus"
                                          if kind == "cross" else ""))
        single = self.frames["wind"][0]
        if kind == "calm":
            single.configure(height=1)  # o Tk nao encolhe sozinho

    def set_side(self, side):
        self.side = side
        self.app.highlight(self.side_buttons, side)

    # ------------------------------------------------------------ valores

    @staticmethod
    def number(var, name):
        try:
            return float(var.get().replace(",", "."))
        except ValueError:
            raise ValueError(f"{name}: valor inválido “{var.get()}”")

    def values(self, key, name):
        if self.modes[key] == "single":
            return [self.number(self.vars[key], name)]
        lo, hi, step = (self.number(v, name) for v in self.vars[key + "_range"])
        values = temperatures(lo, hi, step)
        if not values:
            raise ValueError(f"{name}: o valor inicial é maior que o final.")
        return values

    def cases(self):
        """[(temperatura, Conditions)] na ordem temperatura > vento > QNH."""
        temps = [int(t) if float(t).is_integer() else t
                 for t in self.values("temp", "Temperatura")]
        qnhs = self.values("qnh", "QNH")
        for q in qnhs:
            if not 900 <= q <= 1100:
                raise ValueError(f"QNH fora da faixa (900 a 1100 hPa): "
                                 f"{num(q, 2)}")
        if self.modes["wind"] == "range":
            winds = [(w, 0.0) for w in self.values("wind", "Vento")]
        else:
            speed_kt = 0.0 if self.kind == "calm" else \
                self.number(self.vars["wind"], "Vento")
            if speed_kt < 0:
                raise ValueError("Vento: informe a velocidade sem sinal e "
                                 "escolha proa, cauda ou través.")
            winds = [{"calm": (0.0, 0.0), "head": (speed_kt, 0.0),
                      "tail": (-speed_kt, 0.0),
                      "cross": (0.0, speed_kt if self.side == "right"
                                else -speed_kt)}[self.kind]]
        cases = [(t, scap_engine.Conditions(w, x, q))
                 for t in temps for w, x in winds for q in qnhs]
        if len(cases) > self.MAX_CASES:
            raise ValueError(f"São {len(cases)} combinações; o limite é "
                             f"{self.MAX_CASES}. Aumente os intervalos.")
        return cases


class MalhaDialog:
    """Janela da malha: le a coluna C (partida) do Malha.csv, calcula o maior
    MTOW de cada aeroporto/aeronave e grava na propria malha."""

    def __init__(self, app):
        self.app = app
        self.path = None
        win = self.win = tk.Toplevel(app.root)
        win.title("Calcular malha")
        win.geometry("1120x900")
        win.minsize(940, 760)
        win.configure(bg=C["bg"])
        win.transient(app.root)

        outer = tk.Frame(win, bg=C["bg"])
        outer.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        _, body = app.card(outer, "Malha")
        tk.Label(body, text="Arquivo (aeroporto de partida na coluna C)",
                 bg=C["card"], fg=C["muted"], font=app.f_small).pack(
            anchor=tk.W, pady=(0, 3))
        row = tk.Frame(body, bg=C["card"])
        row.pack(fill=tk.X)
        self.file_var = tk.StringVar(value=str(malha.DEFAULT_MALHA))
        ttk.Entry(row, textvariable=self.file_var, font=app.f_body).pack(
            side=tk.LEFT, fill=tk.X, expand=True)
        choose = tk.Label(row, text="Escolher…", bg=C["card"], fg=C["brand"],
                          font=app.f_label, cursor="hand2")
        choose.pack(side=tk.LEFT, padx=(12, 0))
        choose.bind("<Button-1>", lambda _e: self.choose())

        conditions = tk.Frame(body, bg=C["card"])
        conditions.pack(fill=tk.X, pady=(14, 0))
        left = tk.Frame(conditions, bg=C["card"], width=380)
        left.pack(side=tk.LEFT, anchor=tk.N)
        self.panel = ConditionsPanel(app, left, on_enter=self.run,
                                     temp_mode="range")
        tk.Label(conditions, text="Para cada aeroporto/aeronave, todas as "
                                  "pistas são\ncalculadas em todas as "
                                  "combinações e fica\no maior MTOW.",
                 bg=C["card"], fg=C["muted"], font=app.f_small,
                 justify=tk.LEFT).pack(side=tk.LEFT, anchor=tk.N, padx=(28, 0),
                                       pady=(22, 0))
        self.run_button = tk.Button(
            conditions, text="Calcular malha", font=app.f_button,
            bg=C["brand"], fg="white", activebackground=C["brand_dark"],
            activeforeground="white", disabledforeground="#C9D3E8",
            relief=tk.FLAT, bd=0, cursor="hand2", padx=22, pady=8,
            highlightthickness=0, command=self.run)
        self.run_button.pack(side=tk.RIGHT, anchor=tk.S)

        results, body = app.card(outer, "Resultado", pack=False)
        results.pack(fill=tk.BOTH, expand=True)
        self.status_var = tk.StringVar(
            value="O maior MTOW de cada aeroporto entra em colunas novas no "
                  "fim da malha (uma cópia do original fica em .bak).")
        tk.Label(body, textvariable=self.status_var, bg=C["card"],
                 fg=C["muted"], font=app.f_body, anchor=tk.W,
                 justify=tk.LEFT).pack(fill=tk.X)
        self.progress = ttk.Progressbar(
            body, style="Brand.Horizontal.TProgressbar")
        self.progress.pack(fill=tk.X, pady=(8, 12))

        footer = tk.Frame(body, bg=C["card"])
        footer.pack(side=tk.BOTTOM, fill=tk.X, pady=(10, 0))
        self.open_link = tk.Label(footer, text="", bg=C["card"],
                                  fg=C["brand"], font=app.f_label,
                                  cursor="hand2")
        self.open_link.pack(side=tk.RIGHT)
        self.open_link.bind("<Button-1>", lambda _e: self.path
                            and open_path(self.path))

        table = tk.Frame(body, bg=C["card"], highlightthickness=1,
                         highlightbackground=C["line"],
                         highlightcolor=C["line"])
        table.pack(fill=tk.BOTH, expand=True)
        cols = (("dep", "PARTIDA", 95, tk.CENTER),
                ("aircraft", "AERONAVE", 150, tk.W),
                ("mtow", "MAIOR MTOW (KG)", 120, tk.E),
                ("rwy", "PISTA", 55, tk.CENTER),
                ("temp", "TEMP", 60, tk.CENTER),
                ("wind", "VENTO", 80, tk.CENTER),
                ("qnh", "QNH", 60, tk.CENTER),
                ("flap", "FLAP", 70, tk.CENTER),
                ("limit", "LIMITADO POR", 200, tk.W))
        self.tree = ttk.Treeview(table, columns=[c[0] for c in cols],
                                 show="headings", style="Results.Treeview")
        for key, title, width, anchor in cols:
            self.tree.heading(key, text=title, anchor=anchor)
            self.tree.column(key, width=width, minwidth=width, anchor=anchor,
                             stretch=True)
        self.tree.tag_configure("odd", background=C["zebra"])
        self.tree.tag_configure("error", foreground=C["error"])
        self.tree.pack(fill=tk.BOTH, expand=True)

    def choose(self):
        from tkinter import filedialog
        path = filedialog.askopenfilename(
            parent=self.win, title="Escolher malha",
            initialdir=str(Path(self.file_var.get()).parent),
            filetypes=[("CSV", "*.csv"), ("Todos", "*")])
        if path:
            self.file_var.set(path)

    def run(self):
        path = Path(self.file_var.get())
        try:
            cases = self.panel.cases()
            if not path.exists():
                raise ValueError(f"Arquivo não encontrado:\n{path}")
        except ValueError as e:
            messagebox.showerror("Malha", str(e), parent=self.win)
            return
        self.cond_text = describe_cases(cases).replace("   ·   ", " · ")
        self.run_button.configure(state=tk.DISABLED, bg=C["muted"],
                                  text="Calculando…")
        self.tree.delete(*self.tree.get_children())
        self.open_link.configure(text="")
        self.progress.configure(value=0, maximum=1)
        self.status_var.set("Lendo a malha…")

        def progress(n, total, done, jobs):
            self.win.after(0, lambda: (
                self.progress.configure(maximum=total, value=n - 1 + done / jobs),
                self.status_var.set(f"Aeroporto {n} de {total}…")))

        def work():
            try:
                summary, error = malha.process(path, cases, None, progress,
                                               log=lambda _msg: None), None
            except (malha.MalhaError, scap_engine.ScapError, OSError) as e:
                summary, error = None, str(e)
            self.win.after(0, self.done, path, summary, error)

        threading.Thread(target=work, daemon=True).start()

    def done(self, path, summary, error):
        self.run_button.configure(state=tk.NORMAL, bg=C["brand"],
                                  text="Calcular malha")
        if error:
            self.status_var.set("Não foi possível calcular a malha.")
            messagebox.showerror("Malha", error, parent=self.win)
            return
        for i, info in enumerate(summary):
            dep = f"{info['iata']} · {info['icao']}" if info["icao"] \
                else info["iata"]
            if info["mtow"] is None:
                values = (dep, info["aircraft"] or info["eqp"], "–", "–", "–",
                          "–", "–", "–", info["obs"])
                tags = ("error",)
            else:
                cond = info["cond"]
                values = (dep, info["aircraft"], num(info["mtow"]),
                          info["rwy"], f"{num(info['temp'], 0)} °C",
                          wind_text(cond, unit=False), qnh_text(cond.qnh),
                          info["flap"], limit_text(info["limit"]))
                tags = ("odd",) if i % 2 else ()
            self.tree.insert("", tk.END, values=values, tags=tags)
        self.progress.configure(value=self.progress["maximum"])
        ok = sum(info["mtow"] is not None for info in summary)
        self.status_var.set(f"{ok} de {len(summary)} aeroporto(s)/aeronave(s) "
                            f"calculados ({self.cond_text}). "
                            f"Malha atualizada: {path.name}")
        self.path = path
        self.open_link.configure(text="Abrir malha")


if __name__ == "__main__":
    root = tk.Tk()
    Frontend(root)
    root.mainloop()
