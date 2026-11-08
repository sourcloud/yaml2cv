-module(yaml2cv_system_ffi).

-export([application_version/0, schedulers_online/0]).

schedulers_online() ->
    erlang:system_info(schedulers_online).

application_version() ->
    _ = application:load(yaml2cv),
    case application:get_key(yaml2cv, vsn) of
        {ok, Vsn} -> {ok, unicode:characters_to_binary(Vsn)};
        undefined -> {error, nil}
    end.
