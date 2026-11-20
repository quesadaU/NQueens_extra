:- module(experimentos, [experimentos/0, experimentos/1, prueba_pequena/0]).

/** <module> Instrumentación de los experimentos A, B y C

Ejecuta realmente reinas_bt/2 y reinas_sa/4 y escribe UNA FILA POR EJECUCIÓN
en un CSV. No modifica los algoritmos: solo los llama dentro de call_time/3.

  A  backtracking, primera solución, límite de tiempo por ejecución
  B  simulated annealing, presupuesto fijo de 1378 iteraciones
  C  simulated annealing, presupuesto 1000*N iteraciones

Uso:
    swipl -g experimentos -t halt experimentos.pl
    swipl -g prueba_pequena -t halt experimentos.pl

Lo que queda DENTRO de la medición es solo la llamada al algoritmo (más la
envoltura de call_time/3 y call_with_time_limit/2, unas decenas de
inferencias). Fuera de la medición: set_random/1, garbage_collect/0, la
validación de la solución y la escritura del CSV.
*/

:- use_module(library(statistics)).
:- use_module(library(time)).
:- use_module(library(random)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(backtracking).
:- use_module(annealing).

ns_por_defecto([2, 3, 4, 8, 12, 16, 20, 24, 28, 32, 40, 48, 56, 64]).

%!  experimentos is det.
%!  experimentos(+Opciones) is det.
%
%   Opciones: ns(Lista), corridas(C) (SA, por N y presupuesto),
%   reps_bt(R), limite(Segundos), iter_fijo(K), salida(Archivo),
%   experimentos(Lista de a/b/c).

experimentos :-
    experimentos([]).

experimentos(Op) :-
    ns_por_defecto(NsDef),
    option(ns(Ns), Op, NsDef),
    option(corridas(Corridas), Op, 30),
    option(reps_bt(RepsBT), Op, 5),
    option(limite(Limite), Op, 10),
    option(iter_fijo(Fijo), Op, 1378),
    option(salida(Archivo), Op, 'resultados_experimentales/datos_individuales.csv'),
    option(experimentos(Exps), Op, [a, b, c]),
    calentar,
    setup_call_cleanup(
        open(Archivo, write, S, [encoding(utf8)]),
        ( cabecera(S),
          (   memberchk(a, Exps)
          ->  forall(( member(N, Ns), between(1, RepsBT, Rep) ),
                     ( medir_bt(N, Limite, Rep, Reg), escribir(S, Reg) ))
          ;   true
          ),
          (   memberchk(b, Exps)
          ->  forall(( member(N, Ns), between(1, Corridas, C) ),
                     ( medir_sa('B_sa_fijo', N, Fijo, C, Reg), escribir(S, Reg) ))
          ;   true
          ),
          (   memberchk(c, Exps)
          ->  forall(( member(N, Ns), between(1, Corridas, C) ),
                     ( K is 1000 * N,
                       medir_sa('C_sa_1000N', N, K, C, Reg), escribir(S, Reg) ))
          ;   true
          )
        ),
        close(S)),
    format(user_error, 'Datos escritos en ~w~n', [Archivo]).

%!  prueba_pequena
%
%   Corrida corta para comprobar que la instrumentación funciona.

prueba_pequena :-
    experimentos([ ns([2, 3, 8, 16, 28]), corridas(3), reps_bt(1), limite(2),
                   salida('resultados_experimentales/prueba_pequena.csv') ]).

%   Primera llamada a cada predicado: SWI-Prolog construye los índices JIT de
%   las cláusulas en la primera llamada; así esa construcción no cae dentro de
%   la primera medición real.
calentar :-
    once(reinas_bt(8, _)),
    set_random(seed(0)),
    reinas_sa(8, 500, _, _),
    costo([2,4,1,3], _).

semilla(N, Corrida, Semilla) :-
    Semilla is 1000 * N + Corrida.

%   reg(Experimento, Algoritmo, N, Corrida, Semilla, MaxIter, LimiteS,
%       WallMs, CpuMs, Inferencias, Iteraciones, CostoFinal, CostoUltimo,
%       Encontro, Estado, Valida, Error)
%   El átomo '' representa "no corresponde" (celda vacía en el CSV).

medir_bt(N, Limite, Rep, Reg) :-
    format(user_error, 'A  bt  N=~w  rep=~w~n', [N, Rep]),
    garbage_collect,
    call_time(call_with_time_limit(Limite, once(reinas_bt(N, Qs))), T, R),
    tiempos(T, Wall, Cpu, Inf),
    (   R == true
    ->  Estado = solucion, Encontro = true,
        verificar(N, Qs, Valida), costo(Qs, Costo), Error = ''
    ;   R == false
    ->  Estado = sin_solucion, Encontro = false, Valida = '', Costo = '', Error = ''
    ;   R = throw(time_limit_exceeded)
    ->  Estado = timeout, Encontro = false, Valida = '', Costo = '', Error = ''
    ;   R = throw(E),
        Estado = error, Encontro = false, Valida = '', Costo = '',
        texto_error(E, Error)
    ),
    Reg = reg('A_backtracking', backtracking, N, Rep, '', '', Limite,
              Wall, Cpu, Inf, '', Costo, '', Encontro, Estado, Valida, Error).

medir_sa(Exp, N, MaxIter, Corrida, Reg) :-
    format(user_error, '~w  N=~w  corrida=~w~n', [Exp, N, Corrida]),
    semilla(N, Corrida, Semilla),
    garbage_collect,
    set_random(seed(Semilla)),
    call_time(reinas_sa(N, MaxIter, Qs, info(Costo, Iter, EstSA, Hist)), T, R),
    tiempos(T, Wall, Cpu, Inf),
    (   R == true
    ->  last(Hist, estado(_, CostoUlt, _)),
        Estado = EstSA, Error = '',
        (   Costo =:= 0 -> Encontro = true ; Encontro = false ),
        verificar(N, Qs, Valida0),
        (   Encontro == true -> Valida = Valida0 ; Valida = '' )
    ;   R == false
    ->  Estado = error, Error = 'reinas_sa fallo', Iter = '', Costo = '',
        CostoUlt = '', Encontro = false, Valida = ''
    ;   R = throw(E),
        texto_error(E, Error), Estado = error, Iter = '', Costo = '',
        CostoUlt = '', Encontro = false, Valida = ''
    ),
    Reg = reg(Exp, simulated_annealing, N, Corrida, Semilla, MaxIter, '',
              Wall, Cpu, Inf, Iter, Costo, CostoUlt, Encontro, Estado, Valida, Error).

tiempos(T, Wall, Cpu, Inf) :-
    Wall is T.wall * 1000,
    Cpu is T.cpu * 1000,
    Inf = T.inferences.

texto_error(E, Texto) :-
    format(atom(Texto), '~q', [E]).

%   Verificación independiente de los algoritmos (comparación de todos los
%   pares, O(N^2)): permutación de 1..N y ningún par en la misma diagonal.
verificar(N, Qs, Valida) :-
    (   length(Qs, N),
        msort(Qs, Ord), numlist(1, N, Ord),
        \+ ( nth1(C1, Qs, F1), nth1(C2, Qs, F2), C2 > C1,
             abs(F1 - F2) =:= C2 - C1 )
    ->  Valida = true
    ;   Valida = false
    ).

cabecera(S) :-
    format(S, 'experimento,algoritmo,n,corrida,semilla,max_iter,limite_s,\c
tiempo_wall_ms,tiempo_cpu_ms,inferencias,iteraciones,costo_final,\c
costo_ultimo_estado,encontro_solucion,estado,solucion_valida,error~n', []).

escribir(S, reg(Exp, Alg, N, Corr, Sem, Max, Lim, Wall, Cpu, Inf, It,
                Costo, CUlt, Enc, Est, Val, Err)) :-
    csv_campo(Err, ErrQ),
    format(S, '~w,~w,~w,~w,~w,~w,~w,~4f,~4f,~w,~w,~w,~w,~w,~w,~w,~w~n',
           [Exp, Alg, N, Corr, Sem, Max, Lim, Wall, Cpu, Inf, It,
            Costo, CUlt, Enc, Est, Val, ErrQ]),
    flush_output(S).

csv_campo('', '') :- !.
csv_campo(A, Q) :-
    atomic_list_concat(Partes, '"', A),
    atomic_list_concat(Partes, '""', A1),
    format(atom(Q), '"~w"', [A1]).
