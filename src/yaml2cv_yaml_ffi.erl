-module(yaml2cv_yaml_ffi).

-include_lib("yamerl/include/yamerl_errors.hrl").
-include_lib("yamerl/include/yamerl_nodes.hrl").

-export([parse/1]).

%% Parses a binary into the root nodes of its documents, converted to the
%% `yaml2cv/yaml.Node` representation.
parse(Source) ->
    try yamerl_constr:string(Source, [{detailed_constr, true}]) of
        Documents ->
            {ok, [to_node(Root) || #yamerl_doc{root = Root} <- Documents]}
    catch
        throw:#yamerl_exception{errors = [First | _]} ->
            {error, syntax_error(First)};
        throw:{unsupported_node, Kind} ->
            {error, {syntax_error, <<"unsupported YAML node: ", Kind/binary>>, 0, 0}};
        error:_ ->
            {error, {syntax_error, <<"invalid YAML">>, 0, 0}}
    end.

to_node(#yamerl_null{}) -> null;
to_node(#yamerl_str{text = Text}) -> {string, unicode:characters_to_binary(Text)};
to_node(#yamerl_bool{value = Value}) -> {bool, Value};
to_node(#yamerl_int{value = Value}) -> {int, Value};
to_node(#yamerl_float{value = Value}) -> {float, Value};
to_node(#yamerl_seq{entries = Entries}) -> {sequence, [to_node(E) || E <- Entries]};
to_node(#yamerl_map{pairs = Pairs}) -> {map, [{to_node(K), to_node(V)} || {K, V} <- Pairs]};
to_node(Other) -> throw({unsupported_node, atom_to_binary(element(1, Other))}).

syntax_error(#yamerl_parsing_error{text = Text, line = Line, column = Column}) ->
    {syntax_error, message(Text), location(Line), location(Column)};
syntax_error(#yamerl_invalid_option{text = Text}) ->
    {syntax_error, message(Text), 0, 0}.

message(undefined) -> <<"invalid YAML">>;
message(Text) -> unicode:characters_to_binary(Text).

location(undefined) -> 0;
location(N) -> N.
