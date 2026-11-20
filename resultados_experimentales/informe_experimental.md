# Informe experimental: Backtracking vs. Simulated Annealing al crecer N

Todos los valores de este informe salen de `datos_individuales.csv`: 910
ejecuciones reales de `reinas_bt/2` y `reinas_sa/4`. No hay datos estimados,
interpolados ni copiados de `resultados.md`. La única excepción es la
**gráfica 5**, que es teórica y está rotulada como tal.

## 1. Entorno

| | |
|---|---|
| Equipo | AMD Ryzen 7 7730U (8 núcleos / 16 hilos, 2.0 GHz nominal), 15.3 GB RAM |
| Sistema | Windows 11 Enterprise 10.0.26200, plan de energía "Equilibrado" |
| Prolog | SWI-Prolog 10.0.2 (x64-win64) |
| Gráficas | Python 3.11.9, Matplotlib 3.10.7, NumPy 2.3.4 |
| Código medido | commit `dfed90c` (los algoritmos no se modificaron) |
| Fecha | 2026-11-19 |

El detalle está en `entorno.json`. El equipo es un portátil con escalado
dinámico de frecuencia y otros programas abiertos: los **tiempos** dependen del
estado de la máquina. Las **inferencias** no dependen de eso; ver §4.1.

## 2. Diseño experimental y decisiones metodológicas

### 2.1 Qué se mide y cómo

* **Instrumento:** `call_time/3` de SWI-Prolog. Devuelve el tiempo de reloj
  (wall), el de CPU y las inferencias, y además el **resultado** del objetivo:
  `true`, `false` o `throw(E)`. Gracias a eso, cada ejecución se clasifica sin
  ambigüedad:

  | Resultado | Estado registrado |
  |---|---|
  | BT `true` | `solucion` |
  | BT `false` | `sin_solucion`: el backtracking recorrió todo el espacio, y como es completo, eso **demuestra** que no hay solución |
  | BT `throw(time_limit_exceeded)` | `timeout`: **no** se trata como terminación |
  | SA con costo 0 | `solucion` |
  | SA con costo > 0 al agotar K | `presupuesto_agotado`: **no** significa "no existe solución" |
  | cualquier otra excepción | `error`, con el mensaje en la columna `error` |

* **Qué queda dentro de la medición:** solo la llamada al algoritmo. Quedan
  fuera `set_random/1`, `garbage_collect/0` (se ejecuta antes de cada medición
  para que la basura de una corrida no se cobre en la siguiente), la
  verificación de la solución y la escritura del CSV. No se genera HTML.
* **Sobrecarga medida de la envoltura:** 7–9 inferencias y unos 0.03 ms para
  `call_time + call_with_time_limit`; −2 inferencias para `call_time` solo.
  Es despreciable frente a lo que se mide, salvo en N ≤ 4.
* **Tiempo que se grafica:** el de reloj. En Windows el tiempo CPU de SWI tiene
  una resolución de 1/64 s (15.6 ms), insuficiente para corridas cortas. Se
  guardan los dos.
* **Calentamiento:** antes de medir se llama una vez a cada algoritmo, para
  que la construcción de los índices JIT de SWI-Prolog no se cobre en la
  primera medición.
* **Verificación independiente:** cada solución reportada se comprueba con un
  verificador O(N²) que compara todos los pares y no usa `costo/2`.
  **Resultado: 0 soluciones inválidas.**
* **Control de calidad:** se marca toda ejecución con reloj > 1.5 × CPU + 50 ms,
  porque eso indica que el proceso estuvo detenido por el sistema.
  **Resultado: 0 ejecuciones sospechosas** en la corrida final (ver §7).

### 2.2 Parámetros

| | A: Backtracking | B: SA fijo | C: SA proporcional |
|---|---|---|---|
| N | 2, 3, 4, 8, 12, 16, 20, 24, 28, 32, 40, 48, 56, 64 | ídem | ídem |
| Repeticiones por N | 5 | 30 | 30 |
| Límite / presupuesto | 10 s de reloj (`call_with_time_limit/2`) | K = 1378 | K = 1000·N |
| Semilla | — (determinista) | `1000·N + corrida` | `1000·N + corrida` |

Justificación de las decisiones:

* **N = 2 y 3 se agregaron** a la lista pedida para mostrar el caso sin
  solución.
* **5 repeticiones de BT:** BT es determinista, así que sus inferencias son
  idénticas en todas las repeticiones (se comprobó, salvo 2 inferencias de arranque en la primera medición: §4.1). Se repite solo para
  ver la variabilidad del tiempo.
* **Semillas `1000·N + corrida`:** son distintas para cada N, así que las
  corridas de distintos N no comparten la misma secuencia aleatoria. Son las
  mismas en B y C (diseño pareado): para un mismo (N, corrida), los dos
  presupuestos parten de la misma permutación inicial.
* **Reproducibilidad comprobada:** se repitieron las 60 corridas de B para
  N = 16 y 32. Iteraciones, costo final y estado coinciden en **60/60**; las
  inferencias, en 59/60. La diferencia es de 1 inferencia y está en la primera
  corrida del lote, por un costo interno de arranque del motor.

### 2.3 Qué se registra por ejecución

`experimento, algoritmo, n, corrida, semilla, max_iter, limite_s,
tiempo_wall_ms, tiempo_cpu_ms, inferencias, iteraciones, costo_final,
costo_ultimo_estado, encontro_solucion, estado, solucion_valida, error`

`costo_final` es el **mejor costo visto**, que es lo que devuelve
`reinas_sa/4`. `costo_ultimo_estado` es el del estado en el que terminó la
búsqueda; se lee del último elemento de `Historia`, sin tocar el algoritmo.
En las corridas agotadas de este experimento ambos coincidieron siempre.

## 3. Resultados

### 3.1 Experimento A: Backtracking (primera solución)

| N | Estado (5 rep.) | Tiempo, mediana (ms) | mín–máx (ms) | Inferencias | Inferencias / (N!·N) |
|---|---|---|---|---|---|
| 2 | sin solución (demostrado) ×5 | 0.025 | 0.022–0.162 | 33 | — ¹ |
| 3 | sin solución (demostrado) ×5 | 0.029 | 0.023–0.044 | 62 | — ¹ |
| 4 | solución ×5 | 0.028 | 0.027–0.034 | 98 | 1.0 |
| 8 | solución ×5 | 0.207 | 0.190–0.416 | 2 714 | 8.4·10⁻³ |
| 12 | solución ×5 | 0.899 | 0.799–1.048 | 12 010 | 2.1·10⁻⁶ |
| 16 | solución ×5 | 48.6 | 45.0–73.1 | 671 332 | 2.0·10⁻⁹ |
| 20 | solución ×5 | 1 257 | 985–1 412 | 18 869 322 | 3.9·10⁻¹³ |
| 24 | solución ×5 | 2 866 | 2 799–2 997 | 56 684 642 | 3.8·10⁻¹⁸ |
| 28 | **timeout ×5** | > 10 000 (desconocido) | — | ≥ 194 579 502 ² | — |
| 32 | **timeout ×5** | > 10 000 | — | ≥ 172 251 873 ² | — |
| 40 | **timeout ×5** | > 10 000 | — | ≥ 182 684 102 ² | — |
| 48 | **timeout ×5** | > 10 000 | — | ≥ 145 424 627 ² | — |
| 56 | **timeout ×5** | > 10 000 | — | ≥ 171 963 677 ² | — |
| 64 | **timeout ×5** | > 10 000 | — | ≥ 178 417 217 ² | — |

¹ Con N ≤ 3 las constantes (la envoltura y la llamada inicial) dominan; el cociente no tiene sentido.
² Son las inferencias hechas hasta la interrupción, mínimo de 5 repeticiones. Es una **cota inferior**
del trabajo necesario, no el trabajo total.

### 3.2 Experimentos B y C: Simulated Annealing (30 corridas por N y presupuesto)

| N | K | Éxitos | % | IC 95 % (Wilson) | Tiempo medio (ms) ± DE | Iter. medias (exitosas) | mín–máx (exitosas) | Costo medio (agotadas) |
|---|---|---|---|---|---|---|---|---|
| 2 | 1378 | 0/30 | 0 | 0–11.4 | 8.5 ± 0.6 | — | — | 1.00 |
| 3 | 1378 | 0/30 | 0 | 0–11.4 | 11.4 ± 0.9 | — | — | 1.00 |
| 4 | 1378 | 30/30 | 100 | 88.6–100 | 0.13 ± 0.10 | 11 | 0–39 | — |
| 8 | 1378 | 30/30 | 100 | 88.6–100 | 3.6 ± 3.0 | 228 | 2–768 | — |
| 12 | 1378 | 27/30 | 90.0 | 74.4–96.5 | 19.9 ± 9.4 | 777 | 365–1 361 | 1.00 |
| 16 | 1378 | 22/30 | 73.3 | 55.6–85.8 | 25.7 ± 8.0 | 809 | 436–1 050 | 1.00 |
| 20 | 1378 | 19/30 | 63.3 | 45.5–78.1 | 43.6 ± 11.3 | 1 088 | 711–1 311 | 1.00 |
| 24 | 1378 | 16/30 | 53.3 | 36.1–69.8 | 45.1 ± 9.9 | 970 | 650–1 290 | 1.07 |
| 28 | 1378 | 10/30 | 33.3 | 19.2–51.2 | 63.0 ± 10.2 | 1 190 | 784–1 366 | 1.10 |
| 32 | 1378 | 9/30 | 30.0 | 16.7–47.9 | 66.8 ± 9.6 | 1 093 | 982–1 193 | 1.19 |
| 40 | 1378 | 6/30 | 20.0 | 9.5–37.3 | 84.1 ± 6.9 | 1 204 | 1 075–1 348 | 1.83 |
| 48 | 1378 | 2/30 | 6.7 | 1.8–21.3 | 97.5 ± 9.8 | 1 224 | 1 202–1 246 | 1.93 |
| 56 | 1378 | 1/30 | 3.3 | 0.6–16.7 | 117.0 ± 9.8 | 1 252 | — | 3.17 |
| 64 | 1378 | 1/30 | 3.3 | 0.6–16.7 | 129.4 ± 10.0 | 1 366 | — | 3.48 |
| | | | | | | | | |
| 2 | 2 000 | 0/30 | 0 | 0–11.4 | 13.0 ± 3.7 | — | — | 1.00 |
| 3 | 3 000 | 0/30 | 0 | 0–11.4 | 21.0 ± 1.3 | — | — | 1.00 |
| 4 | 4 000 | 30/30 | 100 | 88.6–100 | 0.13 ± 0.08 | 11 | 0–39 | — |
| 8 | 8 000 | 30/30 | 100 | 88.6–100 | 4.6 ± 4.8 | 337 | 2–1 342 | — |
| 12 | 12 000 | 30/30 | 100 | 88.6–100 | 69.8 ± 28.4 | 3 705 | 463–5 932 | — |
| 16 | 16 000 | 30/30 | 100 | 88.6–100 | 175.6 ± 24.7 | 7 123 | 5 082–8 927 | — |
| 20 | 20 000 | 30/30 | 100 | 88.6–100 | 296.5 ± 45.2 | 9 359 | 6 750–11 668 | — |
| 24 | 24 000 | 30/30 | 100 | 88.6–100 | 473.5 ± 62.7 | 12 559 | 10 773–14 791 | — |
| 28 | 28 000 | 30/30 | 100 | 88.6–100 | 625.1 ± 56.6 | 14 708 | 11 659–16 885 | — |
| 32 | 32 000 | 30/30 | 100 | 88.6–100 | 836.0 ± 69.8 | 17 448 | 13 677–19 678 | — |
| 40 | 40 000 | 30/30 | 100 | 88.6–100 | 1 330 ± 123 | 22 220 | 19 215–25 755 | — |
| 48 | 48 000 | 30/30 | 100 | 88.6–100 | 1 994 ± 242 | 27 290 | 23 601–32 557 | — |
| 56 | 56 000 | 30/30 | 100 | 88.6–100 | 2 675 ± 172 | 32 459 | 29 565–37 468 | — |
| 64 | 64 000 | 30/30 | 100 | 88.6–100 | 3 690 ± 357 | 38 464 | 32 234–46 384 | — |

La primera mitad de la tabla corresponde a B (K = 1378) y la segunda a C
(K = 1000·N). Los promedios, medianas, desviaciones y percentiles completos
están en `resumen_estadistico.csv`.

### 3.3 Gráficas

| Archivo | Contenido | Tipo |
|---|---|---|
| `01_tiempo_vs_N.png` | Tiempo de reloj. BT: mediana y barras mín–máx; timeouts como triángulos huecos en el límite. SA: media y banda P10–P90 | medición |
| `02_inferencias_vs_N.png` | Inferencias por ejecución. Timeouts de BT como cota inferior | medición |
| `03_exito_simulated_annealing.png` | % de éxito con IC 95 % de Wilson y el conteo k/30 en cada punto | medición |
| `04_iteraciones_vs_N.png` | Cada corrida como un punto: exitosas rellenas, agotadas huecas; media de las exitosas y línea del presupuesto | medición |
| `05_complejidad_teorica_vs_N.png` | Cotas N!·N y K·N·log₂N con constantes = 1 | **teórica** |
| `06_costo_por_iteracion_sa.png` | Tiempo e inferencias por iteración de SA, con ajustes de tres modelos (extra) | medición + ajuste |

## 4. Interpretación

### 4.1 Backtracking

1. **Las inferencias son deterministas; el tiempo no.** Las 5 repeticiones de
   cada N dieron exactamente las mismas inferencias. La única excepción es
   N = 2, cuya primera repetición, la primera medición de toda la corrida,
   tuvo 35 inferencias en vez de 33 por un costo de arranque del motor. Los tiempos variaron hasta
   un 50 % (N = 16: 45–73 ms). Además, el mismo código en la misma máquina dio
   en N = 20 unos 740 ms en `resultados.md` y una mediana de 1 257 ms aquí, con
   **idénticas** inferencias (18 869 322). Para comparar trabajo, las
   inferencias son la métrica más confiable; el tiempo refleja también el
   estado del equipo.
2. **El crecimiento es explosivo pero irregular.** El factor de aumento en
   inferencias fue ×4.4 de 8 a 12, ×56 de 12 a 16, ×28 de 16 a 20 y ×3.0 de 20
   a 24. Esto ocurre porque, para la **primera** solución, el trabajo depende
   de dónde cae esa solución en el orden en que `select/3` prueba las filas, no
   solo de N. Por eso la curva medida **no** es una curva suave como N!·N.
3. **Desde N = 28 ninguna ejecución terminó en 10 s.** Antes de ser
   interrumpidas hicieron entre 1.5·10⁸ y 1.9·10⁸ inferencias. No sabemos
   cuánto habrían tardado y no se estima.
4. **N = 2 y N = 3 se resuelven demostrando que no hay solución**, en 33 y 62
   inferencias: el backtracking recorre todo el árbol (podado) y falla.
5. **La cota N!·N es extremadamente holgada para la primera solución.** El
   trabajo medido es 3.8·10⁻¹⁸ veces la cota en N = 24. Eso no contradice la
   cota (es un peor caso), pero muestra que la gráfica 5 **no** predice los
   tiempos reales.

### 4.2 Simulated Annealing con presupuesto fijo (B)

1. **El éxito cae al crecer N**, de 100 % (N ≤ 8) a 3.3 % (N = 56 y 64). Las
   iteraciones necesarias crecen con N (ver C), pero K no.
2. **Cuando tiene éxito con N grande, lo logra al final del presupuesto.** En
   N = 48 las exitosas usaron 1 202–1 246 de 1 378 iteraciones. Esto se debe a
   que `α = (0.01/10)^(1/K)`: con K pequeño la temperatura baja rápido y la
   fase de "afinado" a baja temperatura es corta.
3. **Las corridas fallidas terminan cerca de una solución:** el costo medio es
   de 1–3.5 pares en conflicto.
4. **Es la opción más rápida, pero ese tiempo mide otra cosa:** en N = 64
   tarda 129 ms, pero solo resuelve 1 de cada 30 corridas.

### 4.3 Simulated Annealing con presupuesto 1000·N (C)

1. **Resolvió las 30 corridas de todos los N entre 4 y 64.** Esto **no** es una
   garantía: con 30/30 el IC 95 % del verdadero porcentaje de éxito va de
   88.6 % a 100 %. SA no es completo.
2. **Iteraciones usadas ≈ 300·N a 600·N.** El cociente iteraciones/N sube
   lentamente: 309 (N = 12), 445 (16), 523 (24), 545 (32), 569 (48) y 601 (64).
   El máximo observado (46 384 en N = 64) es el 72 % del presupuesto, así que
   ninguna corrida estuvo cerca de agotarlo.
3. **Tiempo total.** La pendiente log-log entre N = 16 y N = 64 es ≈ 2.2 para
   el tiempo y ≈ 2.16 para las inferencias. Es coherente con el producto de
   iteraciones ≈ c·N y costo por iteración ≈ lineal (§4.4). Esto es una
   descripción empírica en el rango 16–64, no una demostración.
4. **Punto de cruce con BT:** está entre N = 16 y N = 20. En N = 16 BT tarda
   48.6 ms (mediana) y SA-C 175.6 ms (media); en N = 20, BT 1 257 ms y SA-C
   296.5 ms. Desde N = 28, SA-C resuelve siempre en < 4 s, mientras BT no
   termina en 10 s.
5. **N = 2 y 3:** las 30 corridas de cada presupuesto agotan K con costo 1.
   SA **no** distingue "no existe" de "no la encontré"; solo BT lo demuestra.

### 4.4 Costo de una iteración de SA (gráfica 6)

Ajustes por mínimos cuadrados sobre las corridas de C con ≥ 200 iteraciones:

| Medida | a·N + b | a·N·log₂N + b | a·N² + b |
|---|---|---|---|
| µs por iteración | R² = 0.9876 | R² = 0.9824 | R² = 0.9194 |
| inferencias por iteración | R² = 0.99996 (22.8·N + 47) | R² = 0.9931 | R² = 0.9266 |

* Las **inferencias por iteración son exactamente lineales**. Eso era de
  esperar: `msort/2` está implementado en C y cuenta **1 inferencia** sin
  importar N. Por eso las inferencias **no pueden mostrar** el factor log N
  del ordenamiento.
* En **tiempo**, los modelos N y N·log N son prácticamente indistinguibles en
  N ≤ 64, porque log₂N solo varía entre 2 y 6. Además, el trabajo O(N) en
  Prolog (`vecino/2`, `maplist`, `clumped/2`, `foldl`) tiene una constante
  mucho mayor que el ordenamiento en C. El N² sí ajusta claramente peor.
* Conclusión: los datos son **compatibles** con O(N log N) por iteración y
  descartan un costo cuadrático, pero **no demuestran** el factor log N. La
  complejidad se justifica por el análisis del código (§5), no por la forma
  de la curva.

## 5. Revisión de las complejidades del README

### 5.1 Backtracking: tiempo O(N!·N), correcto como cota superior

* **`select/3`:** produce las alternativas de forma incremental. Pasar de la
  alternativa *i* a la *i+1* al reintentar añade un paso y una celda nueva. Por
  eso, enumerar las m = N−k alternativas de un nodo de profundidad k cuesta
  O(m) en total, es decir, **O(1) amortizado por candidato**. El README dice
  que `select/3` "puede recorrer una lista de hasta N elementos" por intento.
  Es una cota válida, pero pesimista.
* **`segura/3`:** compara la candidata con las k reinas ya puestas y se
  detiene en el primer choque: **O(k) ⊆ O(N)** por candidato.
* **Configuraciones parciales explorables:** cada candidato probado es una
  permutación parcial. Hay a lo sumo
  Σₖ N!/(N−k)! = N!·Σⱼ 1/j! < e·N! de ellas. Ese es el "múltiplo constante de
  N!" que menciona el README, y la constante es e.
* Por lo tanto: **T(N) ≤ e·N!·O(N) = O(N!·N)**, más un `reverse/2` O(N) al
  final. La cota supone que la poda nunca corta nada: es el peor caso. Para la
  primera solución el trabajo real es muchísimo menor (§4.1, punto 5).

### 5.2 Backtracking: espacio, el README dice O(N) y no es exacto

`select(X, [H|T], [H|R])` **copia el prefijo** de la lista hasta el elemento
elegido; el sufijo se comparte. En el camino actual de la recursión, la lista
`Resto` de cada nivel sigue viva, porque es la entrada del nivel siguiente y la
necesita el punto de elección de `select/3` para retroceder. En el peor caso,
el nivel k copió N−k celdas, así que el total es Σ(N−k) = **O(N²) celdas**.
A eso se suman O(N) marcos y puntos de elección. Corrección propuesta:
**espacio auxiliar O(N²) en el peor caso** (O(N) marcos de pila más O(N²)
celdas de lista).

### 5.3 SA: tiempo O(K·N log N), correcto

Por iteración:

* **`vecino/2`:** O(N). Lo componen `length/2`, `random_between/3`, dos
  `nth1/3`, `numlist/3` y `maplist/5` con `poner/5`; cada uno es O(N) u O(1).
* **`costo/2`:** O(N log N). `length`, `numlist` y dos `maplist` son O(N).
  Dos `msort/2` son O(N log N): mergesort en C, y `msort` no elimina
  duplicados. Dos `clumped/2` son O(N), porque recorren una lista ya ordenada
  comparando vecinos. `foldl/4` es O(número de grupos) ⊆ O(N).
* **`aceptar/2` y la actualización de T:** O(1).

Total: O(N log N) por iteración y **O(K·N log N)** con K iteraciones, más la
inicialización. `random_permutation/2` usa `keysort` sobre claves aleatorias,
O(N log N), y `costo` inicial también es O(N log N); ninguno cambia la cota.
Precisión: si la solución aparece antes, se usan I ≤ K iteraciones y el costo
real es Θ(I·N log N).

Observación: las claves `F+C` ∈ [2, 2N] y `F−C` ∈ [1−N, N−1] son enteros
acotados. Un conteo con arreglo permitiría O(N), pero la implementación usa
`msort/2`, así que O(N log N) es la cota correcta **para este código**.

### 5.4 SA: espacio O(N), correcto con una precisión

* Vivos en cada momento: estado actual, vecino, mejor estado y las listas de
  claves (originales, ordenadas y agrupadas). Todos son O(N).
* **Historia:** `Paso = max(1, K // 20)` deja a lo sumo unas 22 instantáneas.
  Cada una **referencia** (no copia) una permutación de N elementos, pero la
  mantiene viva. Una cantidad acotada de instantáneas por O(N) da **O(N)**.
* `recocer/8` es **determinista y con llamada final**: las cláusulas 1 y 2
  tienen corte, la 3 es la última, y todo lo que llama es determinista. Por
  eso las O(K·N) celdas que se asignan en total son basura recuperable por el
  recolector, y el espacio *vivo* es O(N). El total *asignado* sí es O(K·N).

### 5.5 Advertencia sobre "inferencias"

Las inferencias cuentan llamadas a predicados. Los builtins en C (`msort/2`,
`is/2`, `length/2`, …) cuentan 1 sin importar su costo interno. Son una buena
medida del trabajo **en Prolog**, no del costo algorítmico total.

## 6. Limitaciones

* 5 repeticiones de BT y 30 corridas de SA por N. Los IC de Wilson muestran
  que la incertidumbre del % de éxito es grande con 30 corridas (±15–17 puntos
  en torno al 50 %).
* Los tiempos se midieron en un portátil en uso, con plan de energía
  "Equilibrado". Las magnitudes relativas son confiables; los milisegundos
  absolutos no son transferibles a otra máquina.
* Para N ≥ 28 solo se sabe que BT necesita **más de 10 s**. No se extrapola.
* El rango de N (≤ 64) es demasiado pequeño para separar N de N·log N
  empíricamente.
* La lista de N es una muestra. El trabajo de BT para la primera solución no
  es monótono en N (por ejemplo, algunos N impares intermedios pueden ser más
  fáciles), y no se midieron todos los N.

## 7. Incidente documentado: primera corrida interrumpida

La primera corrida completa se detuvo por **falta de memoria en el sistema**
(no del experimento) durante el experimento A, en N = 48. Se conserva como
evidencia en `corrida_interrumpida_parcial.csv` y `corrida_interrumpida.log`,
pero **no se usa** en ningún resultado. En ella:

* Desde N = 40 (repeticiones 4–5), las inferencias hechas en 10 s cayeron de
  unos 2.2·10⁸ a 1.7·10⁷.
* Una ejecución de N = 48 registró **688 s de reloj con 9.25 s de CPU**: el
  proceso estuvo congelado unos 11 minutos.

Por eso se añadió el control de calidad reloj vs. CPU (columna
`n_sospechosas_wall_gt_cpu` del resumen). La corrida final se repitió completa
y tiene 0 ejecuciones sospechosas.

## 8. Reproducción

```bash
python resultados_experimentales/reproducir.py              # todo (~15–20 min)
python resultados_experimentales/reproducir.py --prueba     # prueba corta
python resultados_experimentales/reproducir.py --solo-graficas
```

O por partes:

```bash
swipl -g experimentos -t halt experimentos.pl         # -> datos_individuales.csv
python resultados_experimentales/graficas.py          # -> resumen + PNG
```

`experimentos/1` acepta opciones: `ns/1`, `corridas/1`, `reps_bt/1`,
`limite/1`, `iter_fijo/1`, `salida/1` y `experimentos/1` (subconjunto de
`[a,b,c]`). Con la misma versión de SWI-Prolog, las semillas reproducen
exactamente iteraciones, costos y estados; los tiempos variarán.

## 9. Propuesta de cambios al README

1. **Espacio del backtracking:** cambiar "O(N)" por "O(N²) en el peor caso
   (O(N) marcos y puntos de elección + hasta O(N²) celdas por los prefijos que
   copia `select/3`)", con la explicación de §5.2.
2. **Costo de `select/3`:** precisar que enumerar las alternativas cuesta
   O(1) amortizado por candidato, y que el factor N de la cota viene de
   `segura/3`. Agregar que el número de nodos está acotado por e·N!.
3. **Cota de BT vs. realidad:** añadir una frase indicando que la cota es de
   peor caso. Para la primera solución, el trabajo medido fue 3.8·10⁻¹⁸·N!·N en
   N = 24, y crece de forma irregular con N.
4. **Espacio de SA:** mantener O(N) y aclarar que es espacio *vivo*, gracias a
   que `recocer/8` es determinista y con llamada final. El total asignado es
   O(K·N), recuperado por el recolector.
5. **Inferencias:** aclarar que los builtins en C (como `msort/2`) cuentan
   1 inferencia, por lo que las inferencias de SA crecen linealmente por
   iteración aunque el costo teórico sea O(N log N).
6. **Sección de resultados:** sustituir la tabla de 20 corridas por la de este
   informe (30 corridas, IC 95 %, iteraciones solo de corridas exitosas).
   También hay que corregir la columna "iteraciones usadas (prom.)" de la tabla
   actual, que mezcla corridas exitosas con agotadas.
7. **Punto 2 de "Lo que encontramos":** matizar "resolvió las 20 corridas"
   con el IC: 30/30 da un IC 95 % de 88.6–100 %, no una garantía.
8. **Enlazar** `resultados_experimentales/` y las gráficas, y mencionar
   `experimentos.pl` en la tabla de archivos.
