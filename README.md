# ParseUnparseJSON

[![Build Status](https://github.com/JuliaIO/ParseUnparseJSON.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JuliaIO/ParseUnparseJSON.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JuliaIO/ParseUnparseJSON.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaIO/ParseUnparseJSON.jl)
[![Package version](https://juliahub.com/docs/General/ParseUnparseJSON/stable/version.svg)](https://juliahub.com/ui/Packages/General/ParseUnparseJSON)
[![Package dependencies](https://juliahub.com/docs/General/ParseUnparseJSON/stable/deps.svg)](https://juliahub.com/ui/Packages/General/ParseUnparseJSON?t=2)
[![PkgEval](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/P/ParseUnparseJSON.svg)](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/P/ParseUnparseJSON.html)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

Parse/unparse JSON. With perfect roundtripping. Type-stable. The drawback compared to other JSON parsing implementations is less convenient and lower-level interfaces.

## REPL example

```julia-repl
julia> using
           ParseUnparse.AbstractParserIdents,
           ParseUnparse.SymbolGraphs,
           ParseUnparseJSON.GrammarSymbolKinds,
           ParseUnparseJSON.ParserIdents

julia> parser = get_parser(ParserIdent());

julia> (tree, error_status) = parser("{}");

julia> isempty(error_status)  # the parser accepts the empty object
true

julia> (tree, error_status) = parser("{}}");

julia> isempty(error_status)  # the parser rejects malformed JSON
false

julia> using AbstractTrees: print_tree  # let's see a nontrivial parse tree!

julia> function print_tree_map(io::IO, tree)
           g = tree.graph
           kind = root_symbol_kind(g)
           if root_is_terminal(g)
               show(io, (kind, root_token(g)))  # a terminal symbol may have extra info (although it's just `nothing` in this example)
           else
               show(io, kind)  # a nonterminal symbol just has its symbol kind
           end
       end
print_tree_map (generic function with 1 method)

julia> str = """
       {
           "a": 10,
           "b": [2, "z"]
       }
       """
"{\n    \"a\": 10,\n    \"b\": [2, \"z\"]\n}\n"

julia> print_tree(print_tree_map, stdout, graph_as_tree(parser(str)[1]); maxdepth = 100)
value
└─ delimited_dictionary
   ├─ (dictionary_delimiter_left, (1:6, "{\n    "))
   ├─ dictionary
   │  ├─ pair
   │  │  ├─ (string, (7:9, "\"a\""))
   │  │  ├─ (pair_element_separator, (10:11, ": "))
   │  │  └─ value
   │  │     └─ (number, (12:13, "10"))
   │  └─ optional_incomplete_dictionary
   │     ├─ (list_element_separator, (14:19, ",\n    "))
   │     ├─ pair
   │     │  ├─ (string, (20:22, "\"b\""))
   │     │  ├─ (pair_element_separator, (23:24, ": "))
   │     │  └─ value
   │     │     └─ delimited_list
   │     │        ├─ (list_delimiter_left, (25:25, "["))
   │     │        ├─ list
   │     │        │  ├─ value
   │     │        │  │  └─ (number, (26:26, "2"))
   │     │        │  └─ optional_incomplete_list
   │     │        │     ├─ (list_element_separator, (27:28, ", "))
   │     │        │     ├─ value
   │     │        │     │  └─ (string, (29:31, "\"z\""))
   │     │        │     └─ optional_incomplete_list
   │     │        └─ (list_delimiter_right, (32:33, "]\n"))
   │     └─ optional_incomplete_dictionary
   └─ (dictionary_delimiter_right, (34:35, "}\n"))
```
