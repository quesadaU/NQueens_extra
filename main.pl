:- use_module(backtracking).
:- use_module(annealing).
:- use_module(benchmark).
:- use_module(html_tablero).

demo(N) :-
    demo(N, 'tablero.html').

demo(N, Archivo) :-
    seccion_bt(N, SecBT),
    reinas_sa(N, Qs, info(Costo, Iter, Estado, Historia)),
    format('Simulated annealing: ~w, costo ~w en ~w iteraciones~n', [Estado, Costo, Iter]),
    seccion_sa(Costo, Iter, Qs, SecSA),
    maplist(foto, Historia, Fotos),
    escribir_html(Archivo,
                  [ SecBT,
                    SecSA,
                    seccion('Simulated annealing: como avanza la busqueda', Fotos)
                  ]),
    format('HTML escrito en ~w~n', [Archivo]).

seccion_bt(N, seccion(Titulo, [tablero('Primera solucion', Qs)])) :-
    reinas_bt(N, Qs),
    !,
    format('Backtracking: ~w~n', [Qs]),
    format(atom(Titulo), 'Backtracking (N = ~w)', [N]).
seccion_bt(N, seccion(Titulo, [nota('No hay solucion: el backtracking recorrio todo el espacio.')])) :-
    format('Backtracking: no hay solucion para N = ~w~n', [N]),
    format(atom(Titulo), 'Backtracking (N = ~w)', [N]).

seccion_sa(Costo, Iter, Qs, seccion('Simulated annealing: estado final', [tablero(Etiqueta, Qs)])) :-
    (   Costo =:= 0
    ->  format(atom(Etiqueta), 'Solucion en ~w iteraciones', [Iter])
    ;   format(atom(Etiqueta), 'Sin solucion tras ~w iteraciones. Mejor estado visto: ~w pares en conflicto', [Iter, Costo])
    ).

foto(estado(It, Costo, Qs), tablero(Etiqueta, Qs)) :-
    format(atom(Etiqueta), 'iteracion ~w, costo ~w', [It, Costo]).
