:- module(annealing, [reinas_sa/3, reinas_sa/4, costo/2]).

:- use_module(library(random)).
:- use_module(library(lists)).
:- use_module(library(apply)).

temp_inicial(10.0).
temp_final(0.01).

reinas_sa(N, Qs, Info) :-
    MaxIter is 1000 * N,
    reinas_sa(N, MaxIter, Qs, Info).

reinas_sa(N, MaxIter, Qs, info(Costo, Iter, Estado, Historia)) :-
    must_be(positive_integer, N),
    must_be(positive_integer, MaxIter),
    numlist(1, N, Filas),
    random_permutation(Filas, Q0),
    costo(Q0, C0),
    temp_inicial(T0),
    temp_final(Tf),
    Alfa is (Tf / T0) ** (1.0 / MaxIter),
    Paso is max(1, MaxIter // 20),
    recocer(Q0, C0, Q0-C0, T0, params(Alfa, MaxIter, Paso), 0,
            [estado(0, C0, Q0)], fin(Qs, Costo, Iter, Estado, HistInv)),
    reverse(HistInv, Historia).

recocer(Qs, 0, _, _, _, It, H, fin(Qs, 0, It, solucion, [estado(It, 0, Qs)|H])) :-
    !.
recocer(Qs, C, MQ-MC, _, params(_, Max, _), It, H,
        fin(MQ, MC, It, presupuesto_agotado, [estado(It, C, Qs)|H])) :-
    It >= Max,
    !.
recocer(Qs, C, Mejor, T, Params, It, H, Fin) :-
    Params = params(Alfa, _, Paso),
    vecino(Qs, V),
    costo(V, CV),
    Delta is CV - C,
    (   aceptar(Delta, T)
    ->  Q1 = V, C1 = CV
    ;   Q1 = Qs, C1 = C
    ),
    Mejor = _-MC,
    (   C1 < MC -> Mejor1 = Q1-C1 ; Mejor1 = Mejor ),
    It1 is It + 1,
    T1 is T * Alfa,
    (   It1 mod Paso =:= 0
    ->  H1 = [estado(It1, C1, Q1)|H]
    ;   H1 = H
    ),
    recocer(Q1, C1, Mejor1, T1, Params, It1, H1, Fin).

aceptar(Delta, _) :-
    Delta =< 0,
    !.
aceptar(Delta, T) :-
    P is exp(-Delta / T),
    random(R),
    R < P.

vecino(Qs, V) :-
    length(Qs, N),
    random_between(1, N, I),
    J0 is N - 1,
    random_between(1, J0, J1),
    (   J1 >= I -> J is J1 + 1 ; J = J1 ),
    nth1(I, Qs, A),
    nth1(J, Qs, B),
    numlist(1, N, Ks),
    maplist(poner(I-B, J-A), Ks, Qs, V).

poner(I-B, J-A, K, X, Y) :-
    (   K =:= I -> Y = B
    ;   K =:= J -> Y = A
    ;   Y = X
    ).

costo(Qs, Costo) :-
    length(Qs, N),
    numlist(1, N, Cols),
    maplist(diag_suma, Qs, Cols, Sumas),
    maplist(diag_resta, Qs, Cols, Restas),
    pares_iguales(Sumas, C1),
    pares_iguales(Restas, C2),
    Costo is C1 + C2.

diag_suma(F, C, S) :- S is F + C.
diag_resta(F, C, R) :- R is F - C.

pares_iguales(Claves, Pares) :-
    msort(Claves, Ordenadas),
    clumped(Ordenadas, Grupos),
    foldl(sumar_pares, Grupos, 0, Pares).

sumar_pares(_-K, A0, A) :-
    A is A0 + K * (K - 1) // 2.
