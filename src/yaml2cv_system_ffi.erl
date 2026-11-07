-module(yaml2cv_system_ffi).

-export([schedulers_online/0]).

schedulers_online() ->
    erlang:system_info(schedulers_online).
