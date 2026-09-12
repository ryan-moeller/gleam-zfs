%% Copyright (c) 2026 Ryan Moeller
%% SPDX-License-Identifier: BSD-2-Clause

-module(devzfs).
-moduledoc "
Erlang ZFS ioctl glue

This module provides a few glue functions that cannot be implemented in Gleam
for invoking OpenZFS ioctls on FreeBSD.
".

%% API --------------------------------------------------------------------

-export([open/0, ioctl/3]).

open() ->
	SharedLib = zfs_drv,
	case erl_ddll:load("priv", SharedLib) of
		ok -> ok;
		{error, already_loaded} -> ok;
		_ -> exit({error, could_not_load_driver})
	end,
	open_port({spawn, SharedLib}, []).

ioctl(Port, Ioc, Req) ->
	Ref = make_ref(),
	true = port_command(Port, term_to_binary({Ref, Ioc, Req})),
	receive
		{Ref, Res} -> Res
	end.
