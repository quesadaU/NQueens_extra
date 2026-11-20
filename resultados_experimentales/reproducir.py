"""Reproduce los experimentos y las gráficas.

    python resultados_experimentales/reproducir.py              # todo (~15 min)
    python resultados_experimentales/reproducir.py --prueba     # prueba pequeña
    python resultados_experimentales/reproducir.py --solo-graficas

1. Registra el entorno (equipo, SO, versiones) en entorno.json.
2. Ejecuta experimentos.pl con SWI-Prolog -> datos_individuales.csv.
3. Ejecuta graficas.py -> resumen_estadistico.csv y las PNG.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import platform
import subprocess
import sys
from pathlib import Path

DIR = Path(__file__).resolve().parent
RAIZ = DIR.parent


def _salida(cmd: list[str], encoding: str | None = None) -> str:
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=60,
                              encoding=encoding, errors="replace").stdout.strip()
    except (OSError, subprocess.SubprocessError) as e:
        return f"no disponible ({e.__class__.__name__})"


def entorno() -> dict:
    import matplotlib
    import numpy

    info = {
        "fecha": dt.datetime.now().isoformat(timespec="seconds"),
        "swipl": _salida(["swipl", "--version"]),
        "python": sys.version.split()[0],
        "matplotlib": matplotlib.__version__,
        "numpy": numpy.__version__,
        "so": platform.platform(),
        "procesador": platform.processor(),
        "git_commit": _salida(["git", "-C", str(RAIZ), "rev-parse", "--short", "HEAD"]),
    }
    if sys.platform == "win32":
        ps = ("$p = Get-CimInstance Win32_Processor | Select-Object -First 1; "
              "$c = Get-CimInstance Win32_ComputerSystem; "
              "\"$($p.Name.Trim())|$($p.NumberOfCores)|$($p.NumberOfLogicalProcessors)|"
              "$($p.MaxClockSpeed)|$([math]::Round($c.TotalPhysicalMemory/1GB,1))\"")
        partes = _salida(["powershell", "-NoProfile", "-Command", ps]).split("|")
        if len(partes) == 5:
            info.update(cpu=partes[0], nucleos=partes[1], hilos=partes[2],
                        mhz_nominal=partes[3], ram_gb=partes[4])
        plan = _salida(["powercfg", "/getactivescheme"], encoding="oem")
        info["plan_energia"] = plan[plan.rfind("(") + 1:plan.rfind(")")] if "(" in plan else plan
    return info


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--prueba", action="store_true", help="corrida corta de verificación")
    ap.add_argument("--solo-graficas", action="store_true")
    a = ap.parse_args()

    if not a.solo_graficas:
        (DIR / "entorno.json").write_text(json.dumps(entorno(), indent=2, ensure_ascii=False), encoding="utf8")
        meta = "prueba_pequena" if a.prueba else "experimentos"
        with (DIR / "ejecucion.log").open("w", encoding="utf8") as log:
            r = subprocess.run(["swipl", "-g", meta, "-t", "halt", "experimentos.pl"],
                               cwd=RAIZ, stdout=log, stderr=subprocess.STDOUT)
        if r.returncode != 0:
            sys.exit(f"swipl terminó con código {r.returncode}; ver ejecucion.log")
        if a.prueba:
            print("Prueba escrita en prueba_pequena.csv")
            return

    sys.path.insert(0, str(DIR))
    import graficas
    graficas.main()


if __name__ == "__main__":
    main()
