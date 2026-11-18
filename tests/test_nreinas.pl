:- use_module(library(plunit)).
:- use_module('../backtracking').

valida(Qs) :-
    length(Qs, N),
    msort(Qs, Ordenadas),
    numlist(1, N, Ordenadas),
    forall(( nth1(C1, Qs, F1), nth1(C2, Qs, F2), C2 > C1 ),
           abs(F1 - F2) =\= C2 - C1).

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

