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

## Simulated annealing (`annealing.pl`)

* **Estado**: una permutación al azar (`random_permutation/2`).
* **Costo (energía)**: cantidad de **pares** de reinas que se atacan. Un costo
  de 0 es una solución.
* **Vecino**: se intercambian las filas de dos columnas al azar. Así el vecino
  sigue siendo una permutación.
* **Aceptación (criterio de Metropolis)**: si el vecino es mejor o igual, se
  acepta. Si es peor por `Δ`, se acepta con probabilidad `exp(−Δ/T)`. Con `T`
  alta se acepta casi todo (explora); con `T` baja casi nada (explota).
* **Enfriamiento**: `T` empieza en 10 y se multiplica por `α` en cada
  iteración. `α` se calcula para llegar a 0.01 justo al final del presupuesto:
  `α = (0.01/10)^(1/MaxIter)`.
* **Fin**: cuando el costo llega a 0 (`solucion`) o se acaba el presupuesto
  (`presupuesto_agotado`). En el segundo caso devuelve el **mejor estado visto**
  en toda la búsqueda, no el último, que puede ser peor porque SA acepta
  empeorar.
* **Una sola respuesta**: las dos primeras cláusulas de `recocer` tienen corte y
  la tercera es la última, así que no quedan puntos de elección. Si Prolog
  hace backtracking sobre `reinas_sa`, no "inventa" otros resultados (hay un
  test para esto).
* **No es completo**: puede terminar sin solución, y nunca puede afirmar que
  no existe ninguna. Con N = 3 simplemente se acaba el presupuesto.

### Costo en O(N log N)

En vez de comparar todos los pares (O(N²)), se usa que dos reinas están en la
misma diagonal si comparten `F + C` (una dirección) o `F − C` (la otra). Se
calculan esas claves, se ordenan con `msort/2`, `clumped/2` cuenta los grupos
iguales, y un grupo de K reinas aporta `K·(K−1)/2` pares.

## Cambios al código de partida (Gemini)

1. **`DeltaE <= 0` no compila.** En Prolog el operador es `=<`. Con `<=`,
   swipl da `Syntax error: Operator expected` y el archivo no carga.
2. **Error de precedencia en `attacks/5`.** El original escribe
   `( A ; B -> C ; D )`. Como `->` liga más fuerte que `;`, Prolog lo lee
   `A ; (B -> C ; D)` (comprobado con `write_canonical/1`). Si dos reinas están
   en la misma fila (`A`), `TotalAttacks` queda **sin valor** y el `is`
   siguiente da un error de instanciación. Lo correcto es
   `( (A ; B) -> C ; D )`. En nuestra versión ese predicado ya no hace falta.
3. **N como parámetro.** El 8 estaba fijo en `between(1,8,_)`,
   `random_between(0,7,_)` y `random_between(1,8,_)`.
4. **Permutaciones e intercambio** en vez de "cualquier fila en cada columna".
   El espacio de búsqueda baja de Nᴺ a N! estados, y ya no hay choques por
   fila.
5. **Presupuesto de iteraciones explícito.** Con `T0 = 10`, `α = 0.995` y
   parar en `T < 0.01`, el original hace siempre unas **1378 iteraciones**
   (`ln(0.001)/ln(0.995)`), sea cual sea N.
6. **Historia de estados** para la visualización. Se reemplazó XPCE por HTML,
   como sugirió el profesor.
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

## Resultados

Generados con `comparar.` (el archivo completo queda en `resultados.md`).

* Backtracking: tiempo hasta la **primera** solución, con un límite de 10 s.
* Simulated annealing (SA): 20 corridas por N, con las semillas 1 a 20.
  Se reporta el % de corridas que llegaron a costo 0 y el tiempo promedio.
* Tiempos de reloj en nuestra máquina. Las inferencias son exactas y se
  repiten igual en cualquier máquina.

| N | Backtracking | ms | inferencias | SA 1378 it.: éxito | ms | SA 1000·N it.: éxito | ms | iteraciones usadas (prom.) |
|---|---|---|---|---|---|---|---|---|
| 2 | sin solución | 0 | 39 | 0% | 6 | 0% | 8 | 2 000 |
| 3 | sin solución | 0 | 68 | 0% | 8 | 0% | 16 | 3 000 |
| 4 | ok | 0 | 104 | 100% | 0 | 100% | 0 | 8 |
| 8 | ok | 0 | 2 720 | 100% | 2 | 100% | 4 | 409 |
| 12 | ok | 0 | 12 016 | 85% | 14 | 100% | 57 | 4 100 |
| 16 | ok | 25 | 671 338 | 80% | 19 | 100% | 134 | 7 283 |
| 20 | ok | 724 | 18 869 328 | 75% | 26 | 100% | 226 | 10 000 |
| 24 | ok | 2 183 | 56 684 648 | 40% | 34 | 100% | 330 | 12 722 |
| 28 | se agotó el tiempo | 10 000 | > 250 millones | 50% | 39 | 100% | 443 | 14 781 |
| 32 | se agotó el tiempo | 10 000 | > 250 millones | 20% | 48 | 100% | 622 | 17 682 |
| 48 | se agotó el tiempo | 10 000 | > 250 millones | 10% | 75 | 100% | 1 469 | 27 567 |
| 64 | se agotó el tiempo | 10 000 | > 250 millones | 0% | 96 | 100% | 2 566 | 38 289 |

### Lo que encontramos

1. **Backtracking crece de forma explosiva.** De N = 12 a N = 24 las
   inferencias pasan de 12 mil a 56 millones (unas 4 700 veces más). Desde
   N = 28 no termina en 10 s. Es el costo de recorrer el árbol de búsqueda en
   orden: cuando una decisión temprana es mala, hay que deshacer mucho.
2. **Simulated annealing escala mucho mejor, si se le da presupuesto.** Con
   1000·N iteraciones resolvió las 20 corridas de cada N, hasta N = 64 (en
   N = 64, 2.6 s por corrida en promedio). En la práctica usó entre 350·N (N = 12) y 600·N (N = 64) iteraciones, y cada una
   cuesta O(N log N) por el cálculo del costo.
3. **El punto de cruce está entre N = 16 y N = 20.** Con N ≤ 16 backtracking
   es más rápido (25 ms contra 134 ms). Con N = 20 ya tarda 724 ms, contra
   226 ms de SA.
4. **Con presupuesto fijo, SA "se queda corto" a medida que crece N.** Con
   las 1378 iteraciones del código original, el éxito baja de 100% (N = 8) a
   0% (N = 64). No es un defecto de la técnica: N más grande necesita más
   pasos. Esto muestra por qué hay que pensar qué significa "crecer N".
5. **Solo backtracking puede decir "no hay solución".** Con N = 2 y 3
   termina enseguida y falla (39 y 68 inferencias). SA gasta todo su
   presupuesto y termina con costo > 0, sin poder distinguir entre "no
   existe" y "no la encontré".
6. **SA no es determinista; backtracking sí.** Backtracking siempre da la
   misma primera solución con el mismo costo. SA depende de la semilla, por
   eso se reportan porcentajes sobre 20 corridas y no una sola.

**En resumen:** backtracking conviene para N pequeños, para obtener todas
las soluciones o para demostrar que no hay ninguna. Simulated annealing
conviene para N grandes cuando basta con una solución, siempre que su
presupuesto crezca con N.

## Uso de IA

Este extra se hizo con ayuda de IA, como lo permitió el profesor:

* El código de partida es de **Gemini**, compartido por el profesor
  (`referencia/gemini_original.pl`).
* La adaptación (corrección de errores, permutaciones, costo O(N log N),
  benchmark, HTML, tests) y este README se hicieron con **Claude (Anthropic)**.* Nosotros lo revisamos, lo corrimos y lo estudiamos predicado por predicado
  para poder explicarlo y defenderlo.
