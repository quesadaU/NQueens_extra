"""Resumen estadístico y gráficas a partir de datos_individuales.csv.

Solo lee mediciones reales escritas por experimentos.pl. No interpola, no
completa datos faltantes y no convierte un timeout en un tiempo estimado.

    python resultados_experimentales/graficas.py
"""
from __future__ import annotations

import csv
import math
from collections import defaultdict
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402

DIR = Path(__file__).resolve().parent
DATOS = DIR / "datos_individuales.csv"
RESUMEN = DIR / "resumen_estadistico.csv"

# Paleta categórica validada (slots 1-3, válidos para todos los pares).
COLOR = {
    "A_backtracking": "#2a78d6",
    "B_sa_fijo": "#eb6834",
    "C_sa_1000N": "#1baf7a",
}
NOMBRE = {
    "A_backtracking": "Backtracking (primera solución)",
    "B_sa_fijo": "SA, K = 1378",
    "C_sa_1000N": "SA, K = 1000·N",
}
TEXTO, TEXTO2, GRILLA, FONDO = "#0b0b0b", "#52514e", "#e4e3df", "#fcfcfb"

plt.rcParams.update({
    "figure.facecolor": FONDO, "axes.facecolor": FONDO, "savefig.facecolor": FONDO,
    "axes.edgecolor": TEXTO2, "axes.labelcolor": TEXTO, "text.color": TEXTO,
    "xtick.color": TEXTO2, "ytick.color": TEXTO2,
    "axes.grid": True, "grid.color": GRILLA, "grid.linewidth": 0.8, "grid.linestyle": "-",
    "axes.spines.top": False, "axes.spines.right": False,
    "lines.linewidth": 2, "lines.markersize": 6, "font.size": 10,
    "legend.frameon": False, "figure.dpi": 150,
})


# --------------------------------------------------------------------------
# Lectura
# --------------------------------------------------------------------------

def _num(x: str):
    if x == "":
        return None
    try:
        return int(x)
    except ValueError:
        return float(x)


def leer(path: Path = DATOS) -> list[dict]:
    filas = []
    with path.open(encoding="utf8", newline="") as f:
        for r in csv.DictReader(f):
            for k in ("n", "corrida", "semilla", "max_iter", "limite_s", "tiempo_wall_ms",
                      "tiempo_cpu_ms", "inferencias", "iteraciones", "costo_final",
                      "costo_ultimo_estado"):
                r[k] = _num(r[k])
            r["encontro_solucion"] = r["encontro_solucion"] == "true"
            filas.append(r)
    return filas


def agrupar(filas):
    g = defaultdict(list)
    for r in filas:
        g[(r["experimento"], r["n"])].append(r)
    return g


# --------------------------------------------------------------------------
# Estadística
# --------------------------------------------------------------------------

def wilson(k: int, n: int, z: float = 1.959964):
    """Intervalo de confianza de Wilson (95 %) para una proporción, en %."""
    if n == 0:
        return (math.nan, math.nan)
    p = k / n
    den = 1 + z * z / n
    centro = (p + z * z / (2 * n)) / den
    medio = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / den
    return (100 * max(0.0, centro - medio), 100 * min(1.0, centro + medio))


def est(v):
    v = np.asarray([x for x in v if x is not None], dtype=float)
    if v.size == 0:
        return dict(n=0, media="", mediana="", desv="", min="", max="", p10="", p90="")
    return dict(n=int(v.size), media=v.mean(), mediana=float(np.median(v)),
                desv=float(v.std(ddof=1)) if v.size > 1 else 0.0,
                min=float(v.min()), max=float(v.max()),
                p10=float(np.percentile(v, 10)), p90=float(np.percentile(v, 90)))


def resumir(filas) -> list[dict]:
    salida = []
    for (exp, n), rs in sorted(agrupar(filas).items(), key=lambda kv: (kv[0][0], kv[0][1])):
        total = len(rs)
        estados = defaultdict(int)
        for r in rs:
            estados[r["estado"]] += 1
        exitos = sum(r["encontro_solucion"] for r in rs)
        invalidas = sum(r["solucion_valida"] == "false" for r in rs)
        lo, hi = wilson(exitos, total)
        terminadas = [r for r in rs if r["estado"] not in ("timeout", "error")]
        ok = [r for r in rs if r["encontro_solucion"]]
        fallidas = [r for r in rs if r["estado"] == "presupuesto_agotado"]
        fila = {
            "experimento": exp, "n": n, "corridas": total,
            "max_iter": rs[0]["max_iter"] if rs[0]["max_iter"] is not None else "",
            "exitos": exitos, "pct_exito": 100 * exitos / total,
            "ic95_exito_inf": lo, "ic95_exito_sup": hi,
            "n_solucion": estados["solucion"], "n_presupuesto_agotado": estados["presupuesto_agotado"],
            "n_timeout": estados["timeout"], "n_sin_solucion": estados["sin_solucion"],
            "n_error": estados["error"], "n_solucion_invalida": invalidas,
            # Control de calidad: reloj >> CPU indica que el proceso estuvo detenido por el
            # sistema (memoria, suspensión). Margen de 50 ms por la resolución de 15.6 ms de CPU.
            "n_sospechosas_wall_gt_cpu": sum(
                r["tiempo_wall_ms"] > 1.5 * r["tiempo_cpu_ms"] + 50 for r in rs),
        }
        # Tiempo e inferencias: solo de ejecuciones que TERMINARON (no timeouts).
        for nombre, clave in (("wall_ms", "tiempo_wall_ms"), ("cpu_ms", "tiempo_cpu_ms"),
                              ("inferencias", "inferencias")):
            e = est([r[clave] for r in terminadas])
            for k in ("media", "mediana", "desv", "min", "max", "p10", "p90"):
                fila[f"{nombre}_{k}"] = e[k]
        # Para timeouts se guarda la cota inferior observada (no es un tiempo de ejecución).
        to = [r for r in rs if r["estado"] == "timeout"]
        fila["timeout_inferencias_min"] = min((r["inferencias"] for r in to), default="")
        if exp != "A_backtracking":
            e_all = est([r["iteraciones"] for r in rs])
            e_ok = est([r["iteraciones"] for r in ok])
            fila.update(iter_media_todas=e_all["media"],
                        iter_media_exito=e_ok["media"], iter_mediana_exito=e_ok["mediana"],
                        iter_desv_exito=e_ok["desv"], iter_min_exito=e_ok["min"],
                        iter_max_exito=e_ok["max"])
            e_c = est([r["costo_final"] for r in fallidas])
            fila.update(costo_final_media_fallidas=e_c["media"], costo_final_max_fallidas=e_c["max"])
            e_us = est([1000 * r["tiempo_wall_ms"] / r["iteraciones"]
                        for r in rs if r["iteraciones"]])
            e_ip = est([r["inferencias"] / r["iteraciones"] for r in rs if r["iteraciones"]])
            fila.update(us_por_iter_media=e_us["media"], us_por_iter_desv=e_us["desv"],
                        inf_por_iter_media=e_ip["media"], inf_por_iter_desv=e_ip["desv"])
        salida.append(fila)
    return salida


def escribir_resumen(res, path: Path = RESUMEN):
    campos = []
    for r in res:
        for k in r:
            if k not in campos:
                campos.append(k)

    def fmt(x):
        if isinstance(x, float):
            return f"{x:.12g}"
        return x

    with path.open("w", encoding="utf8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=campos, restval="")
        w.writeheader()
        for r in res:
            w.writerow({k: fmt(v) for k, v in r.items()})


# --------------------------------------------------------------------------
# Gráficas
# --------------------------------------------------------------------------

def _serie(res, exp, clave):
    rs = [r for r in res if r["experimento"] == exp and r[clave] != ""]
    return np.array([r["n"] for r in rs]), rs


def _pie(fig, texto):
    fig.text(0.01, 0.005, texto, fontsize=7.5, color=TEXTO2, ha="left", va="bottom", wrap=True)


def _etiqueta_final(ax, x, y, texto, color, dy=0):
    ax.annotate(texto, (x, y), xytext=(6, dy), textcoords="offset points",
                fontsize=8.5, color=TEXTO, va="center",
                bbox=dict(boxstyle="round,pad=0.2", fc=FONDO, ec=color, lw=1))


def _ejes_n(ax, ns):
    ax.set_xticks([n for n in ns if n != 3])  # N = 3 se grafica; solo se omite su rótulo
    ax.set_xlabel("N (tamaño del tablero)")


def grafica_tiempo(filas, res, ns, limite):
    fig, ax = plt.subplots(figsize=(9, 5.6))
    # Backtracking: mediana de las repeticiones que terminaron, barras min-max.
    bt = [r for r in res if r["experimento"] == "A_backtracking"]
    ok = [r for r in bt if r["n_solucion"] == r["corridas"]]
    sin = [r for r in bt if r["n_sin_solucion"] == r["corridas"]]
    to = [r for r in bt if r["n_timeout"] > 0]
    c = COLOR["A_backtracking"]
    if ok:
        x = np.array([r["n"] for r in ok]); y = np.array([r["wall_ms_mediana"] for r in ok])
        lo = y - np.array([r["wall_ms_min"] for r in ok]); hi = np.array([r["wall_ms_max"] for r in ok]) - y
        ax.errorbar(x, y, yerr=[lo, hi], color=c, marker="o", capsize=3, label=NOMBRE["A_backtracking"] + ": solución (mediana, mín–máx)")
        _etiqueta_final(ax, x[-1], y[-1], "Backtracking", c, dy=8)
    if sin:
        ax.scatter([r["n"] for r in sin], [r["wall_ms_mediana"] for r in sin], marker="X", s=70,
                   color=c, zorder=5, label="Backtracking: sin solución (espacio agotado = demostración)")
    if to:
        xs = [r["n"] for r in to]
        tws = [max(x["tiempo_wall_ms"] for x in filas if x["experimento"] == "A_backtracking" and x["n"] == r["n"]) for r in to]
        ax.scatter(xs, tws, marker="^", s=70, facecolors="none", edgecolors=c, linewidths=1.8, zorder=5,
                   label=f"Backtracking: timeout (interrumpido a {limite} s; el tiempo real es desconocido, > {limite} s)")
    ax.axhline(limite * 1000, color=TEXTO2, lw=1, ls=(0, (4, 3)))
    ax.text(ns[0], limite * 1000 * 1.25, f"límite {limite} s", fontsize=8, color=TEXTO2)
    for exp, dy in (("B_sa_fijo", -10), ("C_sa_1000N", 10)):
        x, rs = _serie(res, exp, "wall_ms_media")
        y = np.array([r["wall_ms_media"] for r in rs])
        ax.fill_between(x, [r["wall_ms_p10"] for r in rs], [r["wall_ms_p90"] for r in rs],
                        color=COLOR[exp], alpha=0.18, lw=0)
        ax.plot(x, y, color=COLOR[exp], marker="s", label=f"{NOMBRE[exp]}: media de {rs[0]['corridas']} corridas (banda P10–P90)")
        _etiqueta_final(ax, x[-1], y[-1], NOMBRE[exp], COLOR[exp], dy=dy)
    ax.set_yscale("log")
    _ejes_n(ax, ns)
    ax.set_ylabel("Tiempo de reloj por ejecución (ms, escala log)")
    ax.set_title("Tiempo de ejecución medido vs. N", loc="left", fontweight="bold")
    ax.legend(loc="upper left", fontsize=7.8, bbox_to_anchor=(0, -0.13), ncol=1)
    _pie(fig, "Mediciones reales con call_time/3 (SWI-Prolog). SA: semillas 1000·N + corrida. "
              "Los timeouts se dibujan donde fueron interrumpidos; no son tiempos de terminación.")
    fig.tight_layout(rect=(0, 0.03, 1, 1))
    fig.savefig(DIR / "01_tiempo_vs_N.png")
    plt.close(fig)


def grafica_inferencias(filas, res, ns):
    fig, ax = plt.subplots(figsize=(9, 5.6))
    c = COLOR["A_backtracking"]
    bt = [r for r in res if r["experimento"] == "A_backtracking"]
    ok = [r for r in bt if r["n_timeout"] == 0]
    to = [r for r in bt if r["n_timeout"] > 0]
    x = np.array([r["n"] for r in ok]); y = np.array([r["inferencias_mediana"] for r in ok])
    ax.plot(x, y, color=c, marker="o", label="Backtracking: inferencias hasta terminar (determinista)")
    _etiqueta_final(ax, x[-1], y[-1], "Backtracking", c, dy=8)
    if to:
        ax.scatter([r["n"] for r in to], [r["timeout_inferencias_min"] for r in to], marker="^", s=70,
                   facecolors="none", edgecolors=c, linewidths=1.8, zorder=5,
                   label="Backtracking: timeout — inferencias hechas hasta la interrupción (cota inferior)")
    for exp, dy in (("B_sa_fijo", -10), ("C_sa_1000N", 10)):
        xs, rs = _serie(res, exp, "inferencias_media")
        ys = np.array([r["inferencias_media"] for r in rs])
        ax.fill_between(xs, [r["inferencias_p10"] for r in rs], [r["inferencias_p90"] for r in rs],
                        color=COLOR[exp], alpha=0.18, lw=0)
        ax.plot(xs, ys, color=COLOR[exp], marker="s", label=f"{NOMBRE[exp]}: media (banda P10–P90)")
        _etiqueta_final(ax, xs[-1], ys[-1], NOMBRE[exp], COLOR[exp], dy=dy)
    ax.set_yscale("log")
    _ejes_n(ax, ns)
    ax.set_ylabel("Inferencias por ejecución (escala log)")
    ax.set_title("Inferencias medidas vs. N", loc="left", fontweight="bold")
    ax.legend(loc="upper left", fontsize=7.8, bbox_to_anchor=(0, -0.13))
    _pie(fig, "Inferencias = llamadas a predicados contadas por SWI-Prolog. Los builtins en C (msort/2, is/2...) "
              "cuentan 1 sin importar su costo interno.")
    fig.tight_layout(rect=(0, 0.03, 1, 1))
    fig.savefig(DIR / "02_inferencias_vs_N.png")
    plt.close(fig)


def grafica_exito(res, ns):
    fig, ax = plt.subplots(figsize=(9, 5.2))
    for exp, off in (("B_sa_fijo", -0.35), ("C_sa_1000N", 0.35)):
        todas = [r for r in res if r["experimento"] == exp]
        sin_sol = [r for r in todas if r["n"] <= 3]
        rs = [r for r in todas if r["n"] > 3]
        # N = 2, 3 como puntos sueltos: unirlos con N = 4 sugeriría una continuidad que no existe.
        ax.scatter([r["n"] + off for r in sin_sol], [r["pct_exito"] for r in sin_sol],
                   marker="o", s=30, facecolors="none", edgecolors=COLOR[exp], zorder=5)
        x = np.array([r["n"] for r in rs]) + off
        y = np.array([r["pct_exito"] for r in rs])
        lo = y - np.array([r["ic95_exito_inf"] for r in rs]); hi = np.array([r["ic95_exito_sup"] for r in rs]) - y
        ax.errorbar(x, y, yerr=[lo, hi], color=COLOR[exp], marker="o", capsize=3,
                    label=f"{NOMBRE[exp]} ({rs[0]['corridas']} corridas por N; barras: IC 95 % de Wilson)")
        for xi, yi, r in zip(x, y, rs):
            ax.annotate(f"{r['exitos']}/{r['corridas']}", (xi, yi), xytext=(0, 7 if exp == "C_sa_1000N" else -13),
                        textcoords="offset points", ha="center", fontsize=6.8, color=TEXTO2)
    ax.axvspan(1.5, 3.5, color=GRILLA, alpha=0.7, lw=0)
    ax.text(2.5, 50, "N = 2, 3:\nno existe\nsolución\n(demostrado\npor BT;\n0/30 en\nambos SA)", ha="center", va="center", fontsize=7.5, color=TEXTO2)
    ax.set_ylim(-8, 112)
    _ejes_n(ax, ns)
    ax.set_ylabel("Corridas con solución (%)")
    ax.set_title("Simulated annealing: porcentaje de éxito vs. N", loc="left", fontweight="bold")
    ax.legend(loc="upper left", bbox_to_anchor=(0, -0.12), fontsize=8)
    _pie(fig, "% = corridas exitosas / total de corridas × 100. Un 100 % observado no es una garantía: "
              "con 30/30 el IC 95 % llega solo hasta ~88.6 %.")
    fig.tight_layout(rect=(0, 0.03, 1, 1))
    fig.savefig(DIR / "03_exito_simulated_annealing.png")
    plt.close(fig)


def grafica_iteraciones(filas, res, ns):
    fig, axs = plt.subplots(1, 2, figsize=(11, 5.4), sharey=True)
    rng = np.random.default_rng(0)  # solo para separar puntos horizontalmente (jitter visual)
    for ax, exp in zip(axs, ("B_sa_fijo", "C_sa_1000N")):
        rs = [r for r in filas if r["experimento"] == exp]
        ok = [r for r in rs if r["encontro_solucion"]]
        ag = [r for r in rs if r["estado"] == "presupuesto_agotado"]
        j = lambda k: rng.uniform(-0.9, 0.9, k)
        ax.scatter(np.array([r["n"] for r in ok]) + j(len(ok)), [r["iteraciones"] for r in ok], s=12,
                   color=COLOR[exp], alpha=0.55, lw=0, label="corrida exitosa (iteraciones hasta costo 0)")
        ax.scatter(np.array([r["n"] for r in ag]) + j(len(ag)), [r["iteraciones"] for r in ag], s=16,
                   facecolors="none", edgecolors=TEXTO2, lw=0.9, label="corrida que agotó el presupuesto")
        sr = [r for r in res if r["experimento"] == exp and r["iter_media_exito"] != ""]
        ax.plot([r["n"] for r in sr], [r["iter_media_exito"] for r in sr], color=COLOR[exp], marker="D",
                markeredgecolor=FONDO, label="media de las exitosas")
        nn = np.array(ns, dtype=float)
        presup = np.full_like(nn, 1378) if exp == "B_sa_fijo" else 1000 * nn
        ax.plot(nn, presup, color=TEXTO2, lw=1, ls=(0, (4, 3)), label="presupuesto K")
        ax.set_yscale("log")
        _ejes_n(ax, ns)
        ax.tick_params(axis="x", labelsize=8)
        ax.set_title(NOMBRE[exp], loc="left", fontweight="bold")
        ax.legend(loc="lower right", fontsize=7.5)
    axs[0].set_ylabel("Iteraciones usadas (escala log)")
    fig.suptitle("Simulated annealing: iteraciones usadas por corrida vs. N", x=0.01, ha="left", fontweight="bold")
    _pie(fig, "Cada punto es una corrida real. El desplazamiento horizontal dentro de cada N es solo visual.")
    fig.tight_layout(rect=(0, 0.03, 1, 1))
    fig.savefig(DIR / "04_iteraciones_vs_N.png")
    plt.close(fig)


def grafica_teorica(ns):
    n = np.arange(1, max(ns) + 1, dtype=float)
    fact = np.array([math.factorial(int(k)) for k in n], dtype=float)
    fig, ax = plt.subplots(figsize=(9, 5.4))
    curvas = [
        ("A_backtracking", fact * n, "Backtracking: N!·N"),
        ("B_sa_fijo", 1378 * n * np.log2(np.maximum(n, 2)), "SA: K·N·log₂N con K = 1378"),
        ("C_sa_1000N", 1000 * n * n * np.log2(np.maximum(n, 2)), "SA: K·N·log₂N con K = 1000·N"),
    ]
    for (exp, y, lab), dy in zip(curvas, (0, -9, 9)):
        ax.plot(n, y, color=COLOR[exp], ls=(0, (6, 3)), lw=2, label=lab)
        _etiqueta_final(ax, n[-1], y[-1], lab, COLOR[exp], dy=dy)
    ax.set_yscale("log")
    _ejes_n(ax, ns)
    ax.set_xlim(0, max(ns) * 1.55)
    ax.set_ylabel("Valor de la cota (sin unidades, constantes = 1, escala log)")
    ax.set_title("TEÓRICO — cotas superiores de complejidad (no son mediciones)", loc="left", fontweight="bold")
    ax.text(0.02, 0.97, "CURVAS TEÓRICAS\nNo contienen datos experimentales.\nSolo muestran la forma del crecimiento;\n"
            "las constantes ocultas de O(·) se fijaron en 1.", transform=ax.transAxes, va="top", fontsize=8.5,
            color=TEXTO2, bbox=dict(boxstyle="round,pad=0.4", fc=FONDO, ec=TEXTO2, ls="--"))
    ax.legend(loc="center left", fontsize=8)
    _pie(fig, "N!·N es una cota del peor caso (recorrido completo sin poda útil). La búsqueda de la primera solución "
              "suele hacer muchísimo menos trabajo.")
    fig.tight_layout(rect=(0, 0.03, 1, 1))
    fig.savefig(DIR / "05_complejidad_teorica_vs_N.png")
    plt.close(fig)


def _ajuste(x, y, f):
    """Mínimos cuadrados y = a·f(x) + b; devuelve (a, b, R²)."""
    A = np.vstack([f(x), np.ones_like(x)]).T
    (a, b), *_ = np.linalg.lstsq(A, y, rcond=None)
    pred = A @ np.array([a, b])
    r2 = 1 - np.sum((y - pred) ** 2) / np.sum((y - y.mean()) ** 2)
    return a, b, r2


def costo_por_iteracion(filas):
    """Costo por iteración de SA en el experimento C (más iteraciones por corrida = menos ruido)."""
    rs = [r for r in filas if r["experimento"] == "C_sa_1000N" and r["iteraciones"] and r["iteraciones"] >= 200]
    x = np.array([r["n"] for r in rs], dtype=float)
    us = np.array([1000 * r["tiempo_wall_ms"] / r["iteraciones"] for r in rs])
    ip = np.array([r["inferencias"] / r["iteraciones"] for r in rs])
    return x, us, ip


def grafica_costo_iteracion(filas, ns):
    x, us, ip = costo_por_iteracion(filas)
    fig, axs = plt.subplots(1, 2, figsize=(11, 5))
    modelos = {"a·N + b": lambda v: v, "a·N·log₂N + b": lambda v: v * np.log2(v),
               "a·N² + b": lambda v: v * v}
    estilos = {"a·N + b": (0, (1, 2)), "a·N·log₂N + b": (0, (6, 3)), "a·N² + b": (0, (3, 1, 1, 1))}
    xx = np.linspace(x.min(), x.max(), 200)
    salida = {}
    for ax, y, lab, clave in ((axs[0], us, "Tiempo por iteración (µs)", "us"),
                              (axs[1], ip, "Inferencias por iteración", "inf")):
        ax.scatter(x + np.random.default_rng(1).uniform(-0.6, 0.6, x.size), y, s=10,
                   color=COLOR["C_sa_1000N"], alpha=0.5, lw=0, label="corridas reales (K = 1000·N)")
        for nom, f in modelos.items():
            a, b, r2 = _ajuste(x, y, f)
            salida[(clave, nom)] = (a, b, r2)
            ax.plot(xx, a * f(xx) + b, color=TEXTO2, lw=1.2, ls=estilos[nom], label=f"ajuste {nom}  (R² = {r2:.4f})")
        ax.set_xticks([n for n in ns if n >= 4])
        ax.tick_params(axis="x", labelsize=8)
        ax.set_xlabel("N (tamaño del tablero)")
        ax.set_ylabel(lab)
        ax.legend(loc="upper left", fontsize=7.5)
    axs[0].set_title("Tiempo por iteración", loc="left", fontweight="bold")
    axs[1].set_title("Inferencias por iteración", loc="left", fontweight="bold")
    fig.suptitle("Simulated annealing: costo medido de UNA iteración vs. N (mediciones; las líneas grises son ajustes)",
                 x=0.01, ha="left", fontweight="bold")
    _pie(fig, "Corridas del experimento C con ≥ 200 iteraciones (N = 2, 3 incluidos porque agotan el presupuesto). "
              "Un buen R² no demuestra una complejidad: en este rango de N los modelos son difíciles de distinguir.")
    fig.tight_layout(rect=(0, 0.03, 1, 1))
    fig.savefig(DIR / "06_costo_por_iteracion_sa.png")
    plt.close(fig)
    return salida


def main():
    import sys
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    filas = leer()
    res = resumir(filas)
    escribir_resumen(res)
    ns = sorted({r["n"] for r in filas})
    limite = next((r["limite_s"] for r in filas if r["limite_s"]), 10)
    grafica_tiempo(filas, res, ns, limite)
    grafica_inferencias(filas, res, ns)
    grafica_exito(res, ns)
    grafica_iteraciones(filas, res, ns)
    grafica_teorica(ns)
    ajustes = grafica_costo_iteracion(filas, ns)
    print(f"{len(filas)} ejecuciones leídas; resumen en {RESUMEN.name}")
    for (clave, nom), (a, b, r2) in ajustes.items():
        print(f"ajuste {clave:3s} {nom:16s} a={a:.5g} b={b:.5g} R2={r2:.5f}")


if __name__ == "__main__":
    main()
