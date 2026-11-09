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
            {error, syntax_error(First, Source)};
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

%% yamerl reports a broken list at the first token that cannot continue it,
%% often the line after the actual slip (such as a stray second "-"). Point
%% at the list item instead when it can be found, and name both lines.
syntax_error(#yamerl_parsing_error{name = not_a_sequence, line = Line, column = Column}, Source)
        when is_integer(Line), is_integer(Column) ->
    Lines = string:split(unicode:characters_to_list(Source), "\n", all),
    Number = integer_to_binary(Line),
    case list_item(lists:reverse(lists:sublist(Lines, Line - 1)), Line - 1, Column) of
        {found, Item} ->
            {syntax_error,
                <<"Line ", Number/binary,
                    " does not fit the list item here; check the indentation and the \"-\" marks">>,
                Item, Column};
        not_found ->
            {syntax_error,
                <<"Line ", Number/binary,
                    " does not fit the list above it; check the indentation and the \"-\" marks">>,
                Line, Column}
    end;
%% A key indented less than the content after its item's "-", as after a
%% stray extra space in "-  label:", closes the item, and yamerl stumbles
%% over the key. Point at the item's content instead when it can be found.
syntax_error(
    #yamerl_parsing_error{
        name = unexpected_token, token = Token, text = Text, line = Line, column = Column
    } = Error,
    Source
) when is_tuple(Token), element(1, Token) =:= yamerl_collection_start, is_list(Text),
       is_integer(Line), is_integer(Column) ->
    Lines = string:split(unicode:characters_to_list(Source), "\n", all),
    Closed = string:find(Text, "following a \"yamerl_collection_end\"") =/= nomatch,
    case Closed andalso item_content(lists:reverse(lists:sublist(Lines, Line - 1)), Line - 1, Column) of
        {found, Item, Content} ->
            Number = integer_to_binary(Line),
            {syntax_error,
                <<"Line ", Number/binary,
                    " is indented less than the content after \"-\" here; check the spaces after \"-\"">>,
                Item, Content};
        _ ->
            syntax_error(Error)
    end;
syntax_error(Error, _Source) ->
    syntax_error(Error).

%% The nearest line above that starts left of `Column`, past blank lines,
%% comments and deeper lines, if it is a list item whose content starts
%% right of `Column`: `{found, LineNumber, ContentColumn}`.
item_content([], _, _) ->
    not_found;
item_content([Text | Above], Number, Column) ->
    Indent = length(Text) - length(string:trim(Text, leading, " ")),
    Rest = string:trim(Text, leading, " "),
    if
        Rest =:= [] orelse hd(Rest) =:= $# orelse Indent >= Column - 1 ->
            item_content(Above, Number - 1, Column);
        true ->
            AfterDash = string:trim(tl(Rest), leading, " "),
            Content = length(Text) - length(AfterDash) + 1,
            IsItem = hd(Rest) =:= $- andalso tl(Rest) =/= [] andalso hd(tl(Rest)) =:= $\s,
            case IsItem andalso AfterDash =/= [] andalso Content > Column of
                true -> {found, Number, Content};
                false -> not_found
            end
    end.

%% The nearest line above whose "-" at `Column` starts a list item, looking
%% past blank lines, comments and deeper content, but not past a line that
%% starts left of `Column`.
list_item([], _, _) ->
    not_found;
list_item([Text | Above], Number, Column) ->
    Indent = length(Text) - length(string:trim(Text, leading, " ")),
    Rest = string:trim(Text, leading, " "),
    IsItem =
        length(Text) >= Column andalso
            lists:nth(Column, Text) =:= $- andalso
            (length(Text) =:= Column orelse lists:nth(Column + 1, Text) =:= $\s) andalso
            lists:all(fun(C) -> C =:= $\s orelse C =:= $- end, lists:sublist(Text, Column - 1)),
    if
        IsItem -> {found, Number};
        Rest =:= [] orelse hd(Rest) =:= $# orelse Indent >= Column - 1 ->
            list_item(Above, Number - 1, Column);
        true -> not_found
    end.

syntax_error(#yamerl_parsing_error{
    name = unexpected_token, token = Token, text = Text, line = Line, column = Column
}) when is_tuple(Token), is_list(Text) ->
    {syntax_error, unexpected_token(element(1, Token), Text), location(Line), location(Column)};
syntax_error(#yamerl_parsing_error{text = Text, line = Line, column = Column}) ->
    {syntax_error, message(Text), location(Line), location(Column)};
syntax_error(#yamerl_invalid_option{text = Text}) ->
    {syntax_error, message(Text), 0, 0}.

%% yamerl names its internal token records in this message, e.g.
%% `Unexpected "yamerl_scalar" token following a "yamerl_scalar" token`.
%% The offending token is a scalar or a collection start; the preceding one,
%% only named in the text, is a scalar or a collection end.
unexpected_token(Kind, Text) ->
    Offending =
        case Kind of
            yamerl_scalar -> <<"value">>;
            yamerl_collection_start -> <<"list or mapping">>;
            _ -> <<"content">>
        end,
    Preceding =
        case string:find(Text, "following a \"yamerl_collection_end\"") of
            nomatch -> <<"a value">>;
            _ -> <<"the end of a list or mapping">>
        end,
    <<"Unexpected ", Offending/binary, " after ", Preceding/binary,
        "; check the indentation or a missing \":\"">>.

message(undefined) -> <<"invalid YAML">>;
message(Text) -> unicode:characters_to_binary(Text).

location(undefined) -> 0;
location(N) -> N.
