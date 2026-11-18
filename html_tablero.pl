:- module(html_tablero, [escribir_html/2]).

:- use_module(library(http/html_write)).
:- use_module(library(lists)).

escribir_html(Archivo, Secciones) :-
    phrase(pagina(Secciones), Tokens),
    setup_call_cleanup(
        open(Archivo, write, S, [encoding(utf8)]),
        print_html(S, Tokens),
        close(S)).

pagina(Secciones) -->
    { css(Css) },
    page([ title('N-reinas'),
           meta([name(viewport), content('width=device-width, initial-scale=1')]),
           style(\[Css])
         ],
         [ h1('N-reinas: backtracking vs simulated annealing'),
           p(class(leyenda),
             ['Cada columna tiene una reina. En rojo, las reinas que ',
              'atacan a otra (comparten diagonal).']),
           \secciones(Secciones)
         ]).

secciones([]) --> [].
secciones([seccion(Titulo, Elementos)|Resto]) -->
    html([ h2(Titulo), div(class(fila), \elementos(Elementos)) ]),
    secciones(Resto).

elementos([]) --> [].
elementos([E|Es]) --> elemento(E), elementos(Es).

elemento(nota(Texto)) -->
    html(p(class(nota), Texto)).
elemento(tablero(Etiqueta, Qs)) -->
    { length(Qs, N),
      Tam is max(4, min(36, 320 // N)),
      format(atom(Estilo), 'font-size:~wpx', [Tam]),
      numlist(1, N, Filas),
      en_choque(Qs, Choques)
    },
    html(div(class(caja),
             [ table([class(tablero), style(Estilo)],
                     \filas(Filas, Qs, Choques)),
               p(Etiqueta)
             ])).

filas([], _, _) --> [].
filas([F|Fs], Qs, Choques) -->
    { length(Qs, N), numlist(1, N, Cols) },
    html(tr(\celdas(Cols, F, Qs, Choques))),
    filas(Fs, Qs, Choques).

celdas([], _, _, _) --> [].
celdas([C|Cs], F, Qs, Choques) -->
    { nth1(C, Qs, FilaReina),
      (   (F + C) mod 2 =:= 0 -> Fondo = claro ; Fondo = oscuro ),
      (   FilaReina =:= F
      ->  (   memberchk(C, Choques) -> Clase = [Fondo, choque] ; Clase = [Fondo, reina] ),
          Contenido = \['&#9819;']
      ;   Clase = [Fondo], Contenido = ''
      )
    },
    html(td(class(Clase), Contenido)),
    celdas(Cs, F, Qs, Choques).

en_choque(Qs, Columnas) :-
    length(Qs, N),
    findall(C,
            ( between(1, N, C), nth1(C, Qs, F),
              between(1, N, D), D =\= C, nth1(D, Qs, G),
              abs(F - G) =:= abs(C - D)
            ),
            Cs),
    sort(Cs, Columnas).

css('
body { font-family: system-ui, sans-serif; margin: 16px; background: #fafafa; color: #222; }
h2 { margin-top: 28px; border-bottom: 1px solid #ddd; padding-bottom: 4px; }
.leyenda, .nota { color: #555; }
.fila { display: flex; flex-wrap: wrap; gap: 16px; }
.caja { text-align: center; }
.caja p { margin: 4px 0 0; font-size: 13px; color: #444; }
.tablero { border-collapse: collapse; border: 2px solid #333; }
.tablero td { width: 1.2em; height: 1.2em; padding: 0; text-align: center; line-height: 1.2em; }
.claro { background: #f0d9b5; }
.oscuro { background: #b58863; }
.reina { color: #111; }
.choque { color: #d00; }
').
