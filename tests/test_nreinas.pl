:- use_module(library(plunit)).
:- use_module('../backtracking').
:- use_module('../annealing').

valida(Qs) :-
    length(Qs, N),
    msort(Qs, Ordenadas),
    numlist(1, N, Ordenadas),
    forall(( nth1(C1, Qs, F1), nth1(C2, Qs, F2), C2 > C1 ),
           abs(F1 - F2) =\= C2 - C1).

pares_en_choque(Qs, K) :-
    aggregate_all(count,
                  ( nth1(C1, Qs, F1), nth1(C2, Qs, F2), C2 > C1,
                    ( F1 =:= F2 ; abs(F1 - F2) =:= C2 - C1 ) ),
                  K).

:- begin_tests(backtracking).

test(n4, Qs == [2,4,1,3]) :-
    once(reinas_bt(4, Qs)).
test(n8_es_valida) :-
    once(reinas_bt(8, Qs)),
    valida(Qs).
test(todas_validas_n6) :-
    forall(reinas_bt(6, Qs), valida(Qs)).
test(n2_sin_solucion, [fail]) :-
    reinas_bt(2, _).
test(n3_sin_solucion, [fail]) :-
    reinas_bt(3, _).
test(cuenta_n6, C == 4) :-
    contar_bt(6, C).
test(cuenta_n8, C == 92) :-
    contar_bt(8, C).
test(n_invalido, [error(type_error(positive_integer, 0))]) :-
    reinas_bt(0, _).

:- end_tests(backtracking).

:- begin_tests(costo).

test(solucion, C == 0) :-
    costo([2,4,1,3], C).
test(diagonal_principal, C == 6) :-
    costo([1,2,3,4], C).
test(coincide_con_fuerza_bruta) :-
    set_random(seed(7)),
    forall(between(1, 200, _),
           ( random_between(1, 12, N),
             numlist(1, N, Filas),
             random_permutation(Filas, Qs),
             costo(Qs, C),
             pares_en_choque(Qs, C)
           )).

:- end_tests(costo).

:- begin_tests(annealing).

test(vecino_sigue_siendo_permutacion) :-
    set_random(seed(3)),
    forall(between(1, 100, _),
           ( annealing:vecino([3,1,4,2,5,7,6,8], V),
             msort(V, [1,2,3,4,5,6,7,8])
           )).
test(vecino_cambia_dos_columnas, Distintas == 2) :-
    set_random(seed(5)),
    Qs = [3,1,4,2,5,7,6,8],
    annealing:vecino(Qs, V),
    aggregate_all(count, ( nth1(I, Qs, A), nth1(I, V, B), A =\= B ), Distintas).
test(n8_encuentra_solucion, Estado == solucion) :-
    set_random(seed(1)),
    reinas_sa(8, 8000, Qs, info(0, _, Estado, _)),
    valida(Qs).
test(n3_agota_presupuesto, Estado == presupuesto_agotado) :-
    set_random(seed(1)),
    reinas_sa(3, 500, _, info(Costo, 500, Estado, _)),
    Costo > 0.
test(devuelve_el_mejor_visto) :-
    set_random(seed(2)),
    reinas_sa(16, 300, Qs, info(Costo, _, _, _)),
    costo(Qs, Costo).
test(una_sola_respuesta, Respuestas == 1) :-
    set_random(seed(1)),
    aggregate_all(count, reinas_sa(8, 8000, _, _), Respuestas).
test(n_invalido, [error(type_error(positive_integer, -1))]) :-
    reinas_sa(-1, 100, _, _).

:- end_tests(annealing).
