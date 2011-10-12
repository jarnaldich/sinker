%%%-------------------------------------------------------------------
%%% @author Joan Arnaldich Bernal <jarnaldich@gmail.com>>
%%% @copyright (C) 2011, Joan Arnaldich Bernal
%%% @doc

%%% Generic server implementing the simplest execution sink. An
%%% execution sink is a placewhere tasks can be executed, by answering
%%% to the submit(M,F,A) async call. Once the call has been processed,
%%% they return the message {host_done, Result} to the caller.

%%% The `server` execution sink implemented here takes as init
%%% argument the server bandwith, that is, the maximum allowed
%%% parallel executions. If at any moment the submissions sent exceed
%%% this number, they will be queued up.

%%% @end
%%% Created : 12 Oct 2011 by Joan Arnaldich Bernal <joan@Flatland>
%%%-------------------------------------------------------------------
-module(sink_server).

-behaviour(gen_server).
-include("types.hrl").

%% API
-export([start_link/2, start_link/1, 
         start/2, start/1,
         submit/4, submit/5,
         get_bandwidth/1,
         stop/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-record(state, { bandwidth :: integer(),
                 pending_mfas :: queue(),
                 currently_spawned :: dict() }).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server. 
%%
%% @end
%%--------------------------------------------------------------------
-spec start_link(server_ref(), integer()) -> start_link_res().
start_link(Name, BandWidth) ->
    gen_server:start_link(Name, ?MODULE, [BandWidth], []).

-spec start_link(integer()) -> {ok, pid()} | ignore | {error, any()}.
start_link(BandWidth) ->
    gen_server:start_link(?MODULE, [BandWidth], []).

-spec start(server_ref(), integer()) -> start_link_res().
start(Name, BandWidth) ->
    gen_server:start(Name, ?MODULE, [BandWidth], []).

-spec start(integer()) -> {ok, pid()} | ignore | {error, any()}.
start(BandWidth) ->
    gen_server:start(?MODULE, [BandWidth], []).

-spec get_bandwidth(server_ref()) -> integer().
get_bandwidth(Sink) ->
    gen_server:call(Sink, get_bandwidth).

-spec stop(server_ref()) -> ok.
stop(Sink) ->
    gen_server:call(Sink, stop).

-spec submit(server_ref(), atom(), atom(), [any()]) -> ok.
submit(Sink, M, F, A) ->
    submit(Sink, self(), M, F, A).

-spec submit(server_ref(), server_ref(), atom(), atom(), [any()]) -> ok.
submit(Sink, ReplyTo, M, F, A) ->
    gen_server:cast(Sink, {submit, ReplyTo, M, F, A} ).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
init([BandWidth]) ->
    process_flag(trap_exit, true),
    {ok, #state{ bandwidth = BandWidth,
                 pending_mfas = queue:new(),
                 currently_spawned = dict:new() }}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call(get_bandwidth, _From, State) ->
    {reply, State#state.bandwidth, State};
handle_call(stop, _From, State) ->
    {stop, normal, State}.


%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_cast({submit, Caller, M, F, A}, State) -> 
    %io:format("Before Submit State: ~p~n", [State]),
    OldDict = State#state.currently_spawned,
    case dict:size(OldDict) < State#state.bandwidth of
        true -> 
            NewDict = spawn_and_update_dict(Caller, M, F, A, OldDict),
            {noreply, 
             State#state{ 
               currently_spawned = NewDict }};
        false -> % just queue them...
            {noreply, 
             State#state{ 
               pending_mfas = queue:in({Caller, M, F, A}, 
                                       State#state.pending_mfas) }}
    end;
handle_cast(_Msg, State) -> {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info({'EXIT', Pid, _Reason}, State) -> 
    %io:format("EXIT: Pid=~p~n Reason=~p~n", [Pid, Reason]),
    OldSpawned = State#state.currently_spawned,
    case dict:find(Pid, OldSpawned) of
        {ok, _} ->
            PidRemovedDict = dict:erase(Pid, OldSpawned),
            NewState = case queue:out(State#state.pending_mfas) of
                           {empty, _ } -> 
                               State#state{ 
                                 currently_spawned = PidRemovedDict };
                           {{value, {Caller, M,F,A}}, Rest} ->
                               NewSpawns = spawn_and_update_dict(Caller, M, F, A, PidRemovedDict),
                               State#state{ currently_spawned = NewSpawns,
                                            pending_mfas = Rest }
                       end,            
            {noreply, NewState };
        error ->
            %% Unknown subprocess 
            {noreply, State}
    end;
handle_info(_Msg, State) -> 
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
-spec spawn_and_update_dict(server_ref(), atom(), atom(), [any()], dict()) -> dict().
spawn_and_update_dict(Caller, M, F, A, OldDict) ->
    NewPid = spawn_link(fun() ->
                                Result = apply(M, F, A),
                                %io:format("RESULT: ~p Caller: ~p Pid: ~p~n", [Result, Caller, self()]),
                                Caller ! {host_done, self(), Result}
                        end),
    dict:store(NewPid, {Caller, M, F, A}, OldDict).
