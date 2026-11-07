-module(yaml2cv_process_ffi).

-export([run/4]).

run(Executable, Arguments, Directory, Timeout) ->
    case resolve(Executable) of
        false ->
            {error, {executable_not_found, Executable}};
        Path ->
            Port = open_port({spawn_executable, Path}, [
                {args, Arguments},
                {cd, Directory},
                exit_status,
                stderr_to_stdout,
                binary,
                hide
            ]),
            Deadline = erlang:monotonic_time(millisecond) + Timeout,
            collect(Port, Deadline, [])
    end.

%% Names containing a slash are paths; anything else is looked up on PATH.
resolve(Executable) ->
    Name = binary_to_list(Executable),
    case lists:member($/, Name) of
        true ->
            Path = filename:absname(Name),
            case filelib:is_regular(Path) of
                true -> Path;
                false -> false
            end;
        false ->
            os:find_executable(Name)
    end.

collect(Port, Deadline, Output) ->
    Remaining = max(0, Deadline - erlang:monotonic_time(millisecond)),
    receive
        {Port, {data, Data}} ->
            collect(Port, Deadline, [Data | Output]);
        {Port, {exit_status, Status}} ->
            {ok, {exit, Status, iolist_to_binary(lists:reverse(Output))}}
    after Remaining ->
        kill(Port),
        {error, timed_out}
    end.

%% Closing a port does not stop the OS process, so kill it explicitly, then
%% drop any messages the port sent in the meantime.
kill(Port) ->
    case erlang:port_info(Port, os_pid) of
        {os_pid, OsPid} -> os:cmd("kill -9 " ++ integer_to_list(OsPid));
        undefined -> ok
    end,
    catch port_close(Port),
    flush(Port).

flush(Port) ->
    receive
        {Port, _} -> flush(Port)
    after 0 -> ok
    end.
