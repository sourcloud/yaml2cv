-module(yaml2cv_network_ffi).

-export([interfaces/0]).

%% Returns {raw_interface, Name, Up, Addresses} records for every interface,
%% addresses rendered as text.
interfaces() ->
    case inet:getifaddrs() of
        {ok, Interfaces} -> [interface(Name, Options) || {Name, Options} <- Interfaces];
        {error, _} -> []
    end.

interface(Name, Options) ->
    Flags = proplists:get_value(flags, Options, []),
    Addresses = [unicode:characters_to_binary(inet:ntoa(Address))
                 || {addr, Address} <- Options],
    {raw_interface, unicode:characters_to_binary(Name), lists:member(up, Flags), Addresses}.
