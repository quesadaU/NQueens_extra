% Codigo ORIGINAL de Gemini que compartio el profesor (version sin grafica).
% Se guarda solo como referencia: NO carga, tiene dos errores (ver README):
%   1. "DeltaE <= 0" en accept_move/2: el operador de Prolog es =<.
%   2. attacks/5: "( A ; B -> C ; D )" se lee "A ; (B -> C ; D)"; si A tiene
%      exito, TotalAttacks queda sin valor.
% La version corregida y adaptada esta en ../annealing.pl

:- use_module(library(random)).

% --- Punto de entrada principal ---
% Ejecuta: ?- solve_8_queens.
solve_8_queens :-
    random_state(InitialState),
    cost(InitialState, InitialCost),
    InitialTemp = 10.0,
    CoolingRate = 0.995,
    format('Estado Inicial: ~w (Costo: ~d)~n', [InitialState, InitialCost]),
    anneal(InitialState, InitialCost, InitialTemp, CoolingRate, FinalState),
    cost(FinalState, FinalCost),
    format('Estado Final:   ~w (Costo: ~d)~n', [FinalState, FinalCost]).

% --- Generar un estado aleatorio inicial ---
random_state(State) :-
    findall(R, (between(1, 8, _), random_between(1, 8, R)), State).

% --- Evaluación del Costo (Energía) ---
cost(State, Cost) :-
    cost(State, 1, Cost).

cost([], _, 0).
cost([Q|Queens], Col, TotalCost) :-
    NextCol is Col + 1,
    attacks(Q, Col, Queens, NextCol, Attacks),
    cost(Queens, NextCol, RestCost),
    TotalCost is Attacks + RestCost.

% Contar cuántas reinas atacan a la reina actual
attacks(_, _, [], _, 0).
attacks(Q1, C1, [Q2|Queens], C2, TotalAttacks) :-
    NextC2 is C2 + 1,
    attacks(Q1, C1, Queens, NextC2, RestAttacks),
    ( (Q1 =:= Q2) ; (abs(Q1 - Q2) =:= abs(C1 - C2)) ->
        TotalAttacks is RestAttacks + 1
    ;   TotalAttacks is RestAttacks
    ).

% --- Generar un vecino aleatorio ---
% Cambia la fila de una columna elegida al azar
neighbor(State, Neighbor) :-
    random_between(0, 7, Index),
    random_between(1, 8, NewRow),
    replace(State, Index, NewRow, Neighbor).

replace([_|T], 0, X, [X|T]) :- !.
replace([H|T], I, X, [H|R]) :-
    I > 0,
    I1 is I - 1,
    replace(T, I1, X, R).

% --- Bucle de Recocido Simulado (Simulated Annealing) ---
% Caso base: Se encontró una solución óptima (Costo = 0)
anneal(State, 0, _, _, State) :- !, writeln('¡Solución encontrada!').
% Caso base: La temperatura se enfrió demasiado (Termina la búsqueda local)
anneal(State, _, Temp, _, State) :- Temp < 0.01, !, writeln('Búsqueda finalizada por temperatura baja.').
% Recursión principal del algoritmo
anneal(CurrentState, CurrentCost, Temp, CoolingRate, FinalState) :-
    neighbor(CurrentState, NeighborState),
    cost(NeighborState, NeighborCost),
    DeltaE is NeighborCost - CurrentCost,
    ( accept_move(DeltaE, Temp) ->
        NextState = NeighborState,
        NextCost = NeighborCost
    ;   NextState = CurrentState,
        NextCost = CurrentCost
    ),
    NextTemp is Temp * CoolingRate,
    anneal(NextState, NextCost, NextTemp, CoolingRate, FinalState).

% --- Criterio de aceptación ---
% Si es mejor o igual, se acepta siempre.
accept_move(DeltaE, _) :- DeltaE <= 0, !.
% Si es peor, se calcula la probabilidad probabilística de Boltzmann.
accept_move(DeltaE, Temp) :-
    Prob is exp(-DeltaE / Temp),
    random(Rand), % Genera un flotante aleatorio entre 0.0 y 1.0
    Rand < Prob.
