# Extra: N-reinas con backtracking y con simulated annealing

EIF400 Paradigmas de Programación, II-2026. Grupo 02-3PM.

Se resuelve el mismo problema de búsqueda combinatoria (colocar N reinas en
un tablero de N×N sin que se ataquen) con dos técnicas muy distintas, y se
comparan a medida que crece N:

* **Backtracking**: la forma "natural" de Prolog vista en clase. Prueba una
  opción, y si más adelante no sirve, retrocede y prueba otra.
* **Simulated annealing (recocido simulado)**: parte de un tablero al azar y lo
  mejora poco a poco con cambios pequeños. A veces acepta un cambio peor, con
  una probabilidad que baja con la "temperatura", para no quedarse atascado.

## Cómo correrlo

Requiere SWI-Prolog 9 o superior.

```
cd nreinas-extra
swipl main.pl
?- demo(8).        % resuelve N = 8 con las dos técnicas y escribe tablero.html
?- demo(30).       % cualquier N
?- comparar.       % tabla de comparación en pantalla y en resultados.md
```

`tablero.html` se abre en cualquier navegador.

Tests (18, con plunit):

```
swipl -g run_tests -t halt tests/test_nreinas.pl
```

## Archivos

| Archivo | Qué tiene |
|---|---|
| `backtracking.pl` | `reinas_bt/2` (una solución; con backtracking, todas) y `contar_bt/2` |
| `annealing.pl` | `reinas_sa/3,4` y `costo/2` |
| `benchmark.pl` | `comparar/0,3`: mide las dos técnicas para varios N |
| `html_tablero.pl` | `escribir_html/2`: genera la página con `library(http/html_write)` |
| `main.pl` | `demo/1`: junta todo |
| `tests/test_nreinas.pl` | 18 tests con plunit |
| `referencia/gemini_original.pl` | el código de partida, sin cambios (no carga) |

## Representación

Las dos versiones usan la misma: una lista `Qs` de largo N donde el elemento
*i* es la **fila** de la reina de la **columna** *i*. Ejemplo para N = 4:
`[2,4,1,3]`.

Además, `Qs` es una **permutación** de 1..N: cada fila se usa una sola vez.
Así nunca chocan dos reinas por fila ni por columna, y solo hay que revisar
las **diagonales**. Dos reinas `(F1,C1)` y `(F2,C2)` están en la misma
diagonal si `|F1 − F2| = |C1 − C2|`.

## Backtracking (`backtracking.pl`)

```prolog
colocar(Libres, Puestas, Qs) :-
    select(F, Libres, Resto),        % punto de elección
    segura(F, Puestas, 1),           % poda
    colocar(Resto, [F|Puestas], Qs).
```

* Se coloca una reina por columna. `select/3` escoge una fila libre. Si
  `segura/3` falla, Prolog vuelve al `select` y prueba la siguiente fila. Si
  ninguna sirve, retrocede a la columna anterior.
* La poda es **incremental**: la reina nueva solo se compara con las ya puestas.
  No se genera la permutación completa para revisarla después.
* Es **completo**: si existe una solución la encuentra, y si no existe
  (N = 2, N = 3) recorre todo y **falla**, o sea, demuestra que no hay.
* Con backtracking da todas las soluciones: `contar_bt(8, C)` da `C = 92`.

## Visualización (`html_tablero.pl`)

La página se describe como un término de Prolog con la DCG `html//1` de
`library(http/html_write)` y se escribe con `print_html/2`. `demo(N)` muestra:

* la primera solución del backtracking (o el aviso de que no hay);
* el estado final de simulated annealing;
* unas 20 "fotos" de cómo avanzó simulated annealing, con las reinas en
  conflicto en rojo.

## ¿Qué significa "crecer N"?

No es una sola pregunta. Hay que fijar qué se mide:

* **¿Primera solución o todas?** Backtracking puede dar todas, simulated
  annealing solo una. La cantidad de soluciones crece de forma explosiva
  (92 para N = 8, 14 200 para N = 12), así que la comparación justa es
  **primera solución contra simulated annealing**.
* **¿Con qué presupuesto?** Si simulated annealing tiene un número fijo de
  iteraciones, fallar con N grande es culpa del presupuesto, no de la técnica.
  Por eso se mide con el presupuesto fijo del original (1378) y con uno que
  crece con N (1000·N).
* **¿Cuántas veces?** Simulated annealing es aleatorio: una corrida no dice
  nada. Se hacen varias corridas con semillas fijas (reproducibles) y se
  reporta el **porcentaje de éxito**.
* **¿Tiempo o inferencias?** El tiempo depende de la máquina. Las
  **inferencias** (llamadas a predicados) no, así que también se reportan.
* **Casos sin solución (N = 2, 3).** Backtracking lo demuestra; simulated
  annealing no puede.

## Uso de IA

Este extra se hizo con ayuda de IA, como lo permitió el profesor:

* El código de partida es de **Gemini**, compartido por el profesor
  (`referencia/gemini_original.pl`).
* La adaptación (corrección de errores, permutaciones, costo O(N log N),
  benchmark, HTML, tests) y este README se hicieron con **Claude (Anthropic)**.* Nosotros lo revisamos, lo corrimos y lo estudiamos predicado por predicado
  para poder explicarlo y defenderlo.
