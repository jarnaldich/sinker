%%%-------------------------------------------------------------------
%%% @author Joan Arnaldich Bernal <jarnaldich@gmail.com>>
%%% @copyright (C) 2011, Joan Arnaldich Bernal
%%% @doc

%%% This module is for experiments and snippets during
%%% development. Should be removed from a final distribution.

%%% @end
%%% Created : 12 Oct 2011 by Joan Arnaldich Bernal <joan@Flatland>
%%%-------------------------------------------------------------------
-module(scratch).
-compile(export_all).

spawner(Bandwith, Func, List) ->
    {ok, Pid} = sink_server:start_link(Bandwith),
    [ sink_server:submit(Pid, 
                         erlang,
                         apply, [Func, [N]]) 
      || N <- List ],
    Waiter = fun() ->
                     receive {host_done, _Pid, Result} -> 
                             Result 
                     after 20000 -> 
                             timeout 
                     end
             end,
    Res = lists:foldl(fun(_, Ac) ->
                              [ Waiter() | Ac ]
                      end,
                      [],
                      List),
    try
        sink_server:stop(Pid)
    catch
        Error:Reason -> io:format("Caught ~p:~p~n", [Error, Reason])
    end,
    Res.


%% timer:tc(scratch, spawner, [10, fun(X) -> timer:sleep(100), X end, lists:seq(1, 20)]).
