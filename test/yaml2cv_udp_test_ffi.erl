-module(yaml2cv_udp_test_ffi).

-export([open_receiver/0, 'receive'/2]).

open_receiver() ->
    {ok, Socket} = gen_udp:open(0, [binary, {active, false}, {ip, {127, 0, 0, 1}}]),
    {ok, Port} = inet:port(Socket),
    {Socket, Port}.

'receive'(Socket, Timeout) ->
    case gen_udp:recv(Socket, 0, Timeout) of
        {ok, {_Address, _Port, Packet}} -> {ok, Packet};
        {error, _} -> {error, nil}
    end.
