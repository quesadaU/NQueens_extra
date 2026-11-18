:- module(backtracking, [reinas_bt/2, contar_bt/2]).

:- use_module(library(lists)).
:- use_module(library(aggregate)).

reinas_bt(N, Qs) :-
    must_be(positive_integer, N),
    numlist(1, N, Filas),
    colocar(Filas, [], Qs).

colocar([], Puestas, Qs) :-
    reverse(Puestas, Qs).
colocar(Libres, Puestas, Qs) :-
    select(F, Libres, Resto),
    segura(F, Puestas, 1),
    colocar(Resto, [F|Puestas], Qs).

segura(_, [], _).
segura(F, [F1|Fs], D) :-
    abs(F - F1) =\= D,
    D1 is D + 1,
    segura(F, Fs, D1).

contar_bt(N, Cantidad) :-
    aggregate_all(count, reinas_bt(N, _), Cantidad).
