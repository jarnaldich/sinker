%%%-------------------------------------------------------------------
%%% @author Joan Arnaldich Bernal <jarnaldich@gmail.com>>
%%% @copyright (C) 2011, Joan Arnaldich Bernal
%%% @doc

%%% This module implements a clustered execution sink. An
%%% execution sink is a placewhere tasks can be executed, by answering
%%% to the submit(M,F,A) async call. Once the call has been processed,
%%% they return the message {host_done, Result} to the caller.

%%% The `cluster` execution sink implemented here takes as init
%%% argument a list of child `server` execution sinks, and will
%%% balance its load among them according to their bandwidth.

%%% @end
%%% Created : 12 Oct 2011 by Joan Arnaldich Bernal <joan@Flatland>
%%%-------------------------------------------------------------------
-module(sink_cluster).
-behaviour(gen_server).
-include("types.hrl").

%% API
-export([start_link/1, start_link/2,
         start/2, start/1,
         setup/2,
         submit/4, submit/5,
         get_bandwidth/1,
         stop/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-record(state, { rep_member_list :: [atom()]  } ).

%%%===================================================================
%%% API
%%%===================================================================



%%--------------------------------------------------------------------
%% @doc

%% Sets up a named cluster. 
%% TODO: Interface still very rough

%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
-spec setup(server_ref(), [{server_ref(), integer()}]) -> start_link_res().
setup(Name, ChildSpecList) ->
    F = fun({Ref, BW}) ->
                sink_server:start(Ref, BW),
                Ref;
           (BW) when is_integer(BW) -> 
                {ok, Srv} = sink_server:start(BW),
                Srv
        end,
    start(Name, [ F(C) || C <- ChildSpecList ]).
                  
%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
-spec start_link(server_ref(), [server_ref()]) -> start_link_res().
start_link(Name, MemberList) ->
    gen_server:start_link(Name, ?MODULE, [MemberList], []).

-spec start_link([server_ref()]) -> start_link_res().
start_link(MemberList) ->
    gen_server:start_link(?MODULE, [MemberList], []).
-spec start(server_ref(), integer()) -> start_link_res().
start(Name, BandWidth) ->
    gen_server:start(Name, ?MODULE, [BandWidth], []).

-spec start(integer()) -> {ok, pid()} | ignore | {error, any()}.
start(BandWidth) ->
    gen_server:start(?MODULE, [BandWidth], []).

-spec stop(server_ref()) -> ok.
stop(Sink) ->
    gen_server:call(Sink, stop).

-spec submit(server_ref(), atom(), atom(), [any()]) -> ok.
submit(Sink, M, F, A) ->
    submit(Sink, self(), M, F, A).

-spec submit(server_ref(), server_ref(), atom(), atom(), [any()]) -> ok.
submit(Sink, ReplyTo, M, F, A) ->
    gen_server:cast(Sink, {submit, ReplyTo, M, F, A} ).

-spec get_bandwidth(server_ref()) -> integer().
get_bandwidth(Sink) ->
    gen_server:call(Sink, get_bandwidth).

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
init([MemberList]) ->
    Repl = lists:flatmap(fun(S) -> 
                                 lists:duplicate(sink_server:get_bandwidth(S), S) 
                         end, 
                         MemberList),
    {ok, #state{ rep_member_list = Repl }}.


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
    {reply, length(State#state.rep_member_list), State};
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
    Target = get_server(State),
    sink_server:submit(Target, Caller, M, F, A),
    {noreply, State};
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
handle_info(_Info, State) ->
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
get_server(State) ->
    L = State#state.rep_member_list,
    lists:nth(random:uniform(length(L)), L).
