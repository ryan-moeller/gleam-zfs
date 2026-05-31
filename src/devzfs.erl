%% Copyright (c) 2026 Ryan Moeller
%% SPDX-License-Identifier: Apache-2.0

-module(devzfs).
-moduledoc "
Erlang ZFS ioctl glue

This module provides a few glue functions that cannot be implemented in Gleam
for invoking OpenZFS ioctls on FreeBSD.
".

%% API --------------------------------------------------------------------

-export([open/0]).

open() ->
	SharedLib = zfs_drv,
	case erl_ddll:load("priv", SharedLib) of
		ok -> ok;
		{error, already_loaded} -> ok;
		_ -> exit({error, could_not_load_driver})
	end,
	open_port({spawn, SharedLib}, []).
