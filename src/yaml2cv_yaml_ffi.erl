-module(yaml2cv_yaml_ffi).

-include_lib("yamerl/include/yamerl_errors.hrl").
-include_lib("yamerl/include/yamerl_nodes.hrl").

-export([parse/3]).

%% Parses a binary into the root nodes of its documents, converted to the
%% `yaml2cv/yaml.Node` representation, in a separate process that is killed
%% after `Timeout` milliseconds.
parse(Source, MaxNodes, Timeout) ->
    {Pid, Ref} = spawn_monitor(fun() -> exit({parsed, parse(Source, MaxNodes)}) end),
    receive
        {'DOWN', Ref, process, Pid, {parsed, Result}} ->
            Result;
        {'DOWN', Ref, process, Pid, _Crash} ->
            {error, {syntax_error, <<"invalid YAML">>, 0, 0}}
    after Timeout ->
        exit(Pid, kill),
        erlang:demonitor(Ref, [flush]),
        {error, {timed_out, Timeout}}
    end.

%% At most `MaxNodes` nodes are converted; yamerl shares aliased subtrees,
%% but the conversion would copy them, so the budget is what stops alias
%% expansion bombs.
parse(Source, MaxNodes) ->
    try
        Documents = yamerl_constr:string(Source, [{detailed_constr, true}]),
        {Nodes, _} = lists:mapfoldl(
            fun(#yamerl_doc{root = Root}, Budget) -> to_node(Root, Budget) end,
            MaxNodes,
            Documents
        ),
        {ok, Nodes}
    catch
        throw:#yamerl_exception{errors = [First | _]} ->
            {error, syntax_error(First)};
        throw:{unsupported_node, Kind} ->
            {error, {syntax_error, <<"unsupported YAML node: ", Kind/binary>>, 0, 0}};
        throw:budget_exhausted ->
            {error, {too_many_nodes, MaxNodes}};
        error:_ ->
            {error, {syntax_error, <<"invalid YAML">>, 0, 0}}
    end.

to_node(_, 0) ->
    throw(budget_exhausted);
to_node(#yamerl_null{}, Budget) ->
    {null, Budget - 1};
to_node(#yamerl_str{text = Text}, Budget) ->
    {{string, unicode:characters_to_binary(Text)}, Budget - 1};
to_node(#yamerl_bool{value = Value}, Budget) ->
    {{bool, Value}, Budget - 1};
to_node(#yamerl_int{value = Value}, Budget) ->
    {{int, Value}, Budget - 1};
to_node(#yamerl_float{value = Value}, Budget) ->
    {{float, Value}, Budget - 1};
to_node(#yamerl_seq{entries = Entries}, Budget) ->
    {Nodes, Rest} = lists:mapfoldl(fun to_node/2, Budget - 1, Entries),
    {{sequence, Nodes}, Rest};
to_node(#yamerl_map{pairs = Pairs}, Budget) ->
    {Nodes, Rest} = lists:mapfoldl(
        fun({Key, Value}, B0) ->
            {K, B1} = to_node(Key, B0),
            {V, B2} = to_node(Value, B1),
            {{K, V}, B2}
        end,
        Budget - 1,
        Pairs
    ),
    {{map, Nodes}, Rest};
to_node(Other, _) ->
    throw({unsupported_node, atom_to_binary(element(1, Other))}).

syntax_error(#yamerl_parsing_error{text = Text, line = Line, column = Column}) ->
    {syntax_error, message(Text), location(Line), location(Column)};
syntax_error(#yamerl_invalid_option{text = Text}) ->
    {syntax_error, message(Text), 0, 0}.

message(undefined) -> <<"invalid YAML">>;
message(Text) -> unicode:characters_to_binary(Text).

location(undefined) -> 0;
location(N) -> N.
