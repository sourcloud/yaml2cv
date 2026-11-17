-module(yaml2cv_stdio_ffi).

%% Raw byte access to standard input and output for the command line
%% (ADR 0048). Standard I/O is switched to latin1 encoding, and
%% `file:read/2` and `file:write/2` send latin1 requests, so bytes pass
%% through unchanged. With the default unicode encoding every byte above
%% 127 would be re-encoded as UTF-8, and `io:put_chars/2` would reject a
%% binary that is not UTF-8.

-export([read_stdin/0, write_stdout/1, write_stderr/1]).

read_stdin() ->
    ok = raw(),
    read_all([]).

read_all(Chunks) ->
    case file:read(standard_io, 65536) of
        eof -> {ok, iolist_to_binary(lists:reverse(Chunks))};
        {error, Reason} ->
            {error, unicode:characters_to_binary(io_lib:format("~p", [Reason]))};
        {ok, Data} -> read_all([Data | Chunks])
    end.

write_stdout(Bytes) ->
    ok = raw(),
    ok = file:write(standard_io, Bytes),
    nil.

write_stderr(Text) ->
    ok = io:put_chars(standard_error, unicode:characters_to_list(Text)),
    nil.

raw() ->
    io:setopts(standard_io, [binary, {encoding, latin1}]).
