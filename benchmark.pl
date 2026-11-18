:- module(benchmark, [comparar/0, comparar/3, medir_bt/3, medir_sa/4]).

:- use_module(library(time)).
:- use_module(library(random)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(backtracking).
:- use_module(annealing).

iter_original(1378).

comparar :-
    comparar([2, 3, 4, 8, 12, 16, 20, 24, 28, 32, 48, 64], 20, 'resultados.md').

comparar(Ns, Corridas, Archivo) :-
    calentar,
    maplist(fila(Corridas), Ns, Filas),
    imprimir(user_output, Corridas, Filas),
    setup_call_cleanup(
        open(Archivo, write, S, [encoding(utf8)]),
        imprimir(S, Corridas, Filas),
        close(S)).

calentar :-
    medir_bt(6, 10, _),
    medir_sa(6, 1, 100, _).

fila(Corridas, N, fila(N, BT, SAfijo, SAesc)) :-
    format(user_error, 'N = ~w ...~n', [N]),
    medir_bt(N, 10, BT),
    iter_original(Fijo),
    medir_sa(N, Corridas, Fijo, SAfijo),
    Esc is 1000 * N,
    medir_sa(N, Corridas, Esc, SAesc).

medir_bt(N, Limite, bt(Estado, Ms, Inf)) :-
    get_time(T0),
    statistics(inferences, I0),
    catch(( call_with_time_limit(Limite, reinas_bt(N, _))
          -> Estado = ok
          ;  Estado = sin_solucion
          ),
          time_limit_exceeded,
          Estado = tiempo_agotado),
    get_time(T1),
    statistics(inferences, I1),
    Ms is round((T1 - T0) * 1000),
    Inf is I1 - I0.

medir_sa(N, Corridas, MaxIter, sa(MaxIter, Pct, MsProm, ItProm)) :-
    numlist(1, Corridas, Semillas),
    maplist(una_corrida(N, MaxIter), Semillas, Rs),
    foldl(acumular, Rs, t(0, 0, 0), t(Exitos, MsTot, ItTot)),
    Pct is round(100 * Exitos / Corridas),
    MsProm is round(MsTot / Corridas),
    ItProm is round(ItTot / Corridas).

una_corrida(N, MaxIter, Semilla, r(Exito, Ms, It)) :-
    set_random(seed(Semilla)),
    get_time(T0),
    reinas_sa(N, MaxIter, _, info(Costo, It, _, _)),
    get_time(T1),
    Ms is (T1 - T0) * 1000,
    (   Costo =:= 0 -> Exito = 1 ; Exito = 0 ).

acumular(r(E, Ms, It), t(E0, M0, I0), t(E1, M1, I1)) :-
    E1 is E0 + E,
    M1 is M0 + Ms,
    I1 is I0 + It.

imprimir(S, Corridas, Filas) :-
    iter_original(Fijo),
    format(S, '# Resultados~n~n', []),
    format(S, 'Backtracking: primera solucion, limite 10 s. ', []),
    format(S, 'Simulated annealing: ~w corridas por N (semillas 1..~w).~n~n', [Corridas, Corridas]),
    format(S, '| N | BT estado | BT ms | BT inferencias | SA ~w it: exito | ms | SA 1000*N it: exito | ms | iter. prom. |~n', [Fijo]),
    format(S, '|---|---|---|---|---|---|---|---|---|~n', []),
    forall(member(F, Filas), imprimir_fila(S, F)),
    nl(S).

imprimir_fila(S, fila(N, bt(Est, BMs, BInf), sa(_, P1, Ms1, _), sa(_, P2, Ms2, It2))) :-
    format(S, '| ~w | ~w | ~w | ~D | ~w% | ~w | ~w% | ~w | ~D |~n',
           [N, Est, BMs, BInf, P1, Ms1, P2, Ms2, It2]).
