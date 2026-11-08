-module(yaml2cv_udp_ffi).

-export([send/3]).

%% Sends one UDP datagram from a short-lived socket, so no socket has to be
%% owned across heartbeats.
send(Host, Port, Packet) ->
    case resolve(unicode:characters_to_list(Host)) of
        {ok, Family, Address} ->
            case gen_udp:open(0, [binary, Family]) of
                {ok, Socket} ->
                    Result = gen_udp:send(Socket, Address, Port, Packet),
                    gen_udp:close(Socket),
                    case Result of
                        ok -> {ok, nil};
                        {error, Reason} -> {error, describe(Reason)}
                    end;
                {error, Reason} -> {error, describe(Reason)}
            end;
        {error, Reason} -> {error, describe(Reason)}
    end.

resolve(Host) ->
    case inet:getaddr(Host, inet) of
        {ok, Address} -> {ok, inet, Address};
        {error, _} ->
            case inet:getaddr(Host, inet6) of
                {ok, Address} -> {ok, inet6, Address};
                {error, Reason} -> {error, Reason}
            end
    end.

describe(Reason) ->
    unicode:characters_to_binary(io_lib:format("~p", [Reason])).
