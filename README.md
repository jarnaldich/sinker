# Sinker - Erlang execution sinks

Execution sinks are an attempt to abstract a kind of parallel pattern
 I found myself using on several other projects.

At their simplest implementation, they're essentially job queues that
can process a configurable number of jobs in parallel (their
*bandwidth*) with an asynchronous interface. This kind of sinks are
useful, for example, to model a machine that can only take a certain
workload.

Simple sinks can also be composed to build other abstractions. For
example, to build clusters that balance their load among their
members according to their bandwidths.

This library will implement new sink abstractions as I need them,
and will hopefully help to fix the common interface needed for greater
composability, if that proves desirable as new abstractions appear.

## Status

This project is much of an experiment right now, but I still want it
to be robust, so bug reports and feedback in general will be greatly
appreciated.

## Compiling

This project uses [rebar](https://github.com/basho/rebar). 

## Modules

``sink_server.erl`` implements a simple sink as a ``gen_server``.
``sink_cluster.erl`` implements a cluster of sink servers as a ``gen_server``.
``scratch.erl`` is a module for tests ans snippets, and should
disappear in any further releas.

## TODO

* Documentation. The project is small enough, at the moment, to infer
  its usage from the source code.
* Eunit tests.
* Dialize it.

