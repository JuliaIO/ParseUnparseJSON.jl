module TestParserIdents
    using
        ParseUnparse.SymbolGraphs,
        ParseUnparse.AbstractParserIdents,
        ParseUnparseJSON.GrammarSymbolKinds,
        ParseUnparseJSON.ParserIdents,
        Test
    const parsers = (get_parser(ParserIdent()), get_parser(ParserIdent{Nothing}()), get_parser(ParserIdent{Union{}}()))
    struct Acc
        s::String
        # tokenization::Vector{XXX}
        # leaves::Vector{GrammarSymbolKind}
        # preorder_dfs::Vector{GrammarSymbolKind}
        # postorder_dfs::Vector{GrammarSymbolKind}
    end
    struct Rej
        s::String
        # err::Tuple{SymbolGraphNodeIdentity, Vector{Tuple{Tuple{UnitRange{Int64}, String}, GrammarSymbolKind}}}
    end
    const data_accept = Acc[
        Acc("false"),
        Acc("true"),
        Acc("null"),
        Acc(" null"),
        Acc(" null "),
        Acc("null "),
        Acc("\"\""),
        Acc("\"7\""),
        Acc("\"\\\"\""),
        Acc("\"\\u4444\""),
        Acc("0"),
        Acc("1"),
        Acc("11"),
        Acc("0.1"),
        Acc("-1"),
        Acc("0E0"),
        Acc("0e0"),
        Acc("1e1"),
        Acc("0e+0"),
        Acc("1e+1"),
        Acc("0e-0"),
        Acc("1e-1"),
        Acc("1.01E-10"),
        Acc("[]"),
        Acc("{}"),
        Acc("""
        [{"1": 3e-7, "2": 0.1, "3": [{}], "4": {"1": []}}, ["7"]]
        """)
    ]
    const data_reject = Rej[
        Rej(""),
        Rej("f"),
        Rej("falses"),
        Rej("truw"),
        Rej("\""),
        Rej("\"\\"),
        Rej("\"\\z\""),
        Rej("\"\"\""),
        Rej("\"\\u444"),
        Rej("\"\\u444\""),
        Rej("01"),
        Rej(".1"),
        Rej("1."),
        Rej("1.a"),
        Rej("0e"),
        Rej("0E"),
        Rej("0ez"),
        Rej("0e-"),
        Rej("0e+"),
        Rej("0e-z"),
        Rej("-"),
        Rej("+1"),
        Rej("0z"),
        Rej("1z"),
        Rej("-z"),
        Rej(","),
        Rej(":"),
        Rej("["),
        Rej("]"),
        Rej("{"),
        Rej("}"),
    ]
    @testset "parser idents" begin
        @testset "accept" begin
            for data ∈ data_accept
                for parser ∈ parsers
                    @test isempty((@inferred parser(data.s))[2])
                end
            end
        end
        @testset "reject" begin
            for data ∈ data_reject
                for parser ∈ parsers
                    @test !isempty((@inferred parser(data.s))[2])
                end
            end
        end
    end
end
