module TestTokenUtil
    using ParseUnparseJSON.TokenUtil, Test
    @testset "`TokenUtil`" begin
        @test "z" == (@inferred sprint(decode_string, """ "z" """))::AbstractString
        @test '"'^2 == (@inferred sprint(encode_string, ""))::AbstractString
        @test string('"', '\\', '"'^2) == (@inferred sprint(encode_string, "\""))::AbstractString
        @test "\ufedc" == (@inferred sprint(decode_string, """ "\\ufedc" """))::AbstractString
        @test "\ucdef" == (@inferred sprint(decode_string, """ "\\uCDEF" """))::AbstractString
        @test "\b" == (@inferred sprint(decode_string, """ "\\b" """))::AbstractString
        @test "\f" == (@inferred sprint(decode_string, """ "\\f" """))::AbstractString
        @test "\n" == (@inferred sprint(decode_string, """ "\\n" """))::AbstractString
        @test "\r" == (@inferred sprint(decode_string, """ "\\r" """))::AbstractString
        @test "\t" == (@inferred sprint(decode_string, """ "\\t" """))::AbstractString
        for s ∈ ("", " ", "z", " z", "z ", " z ", "\"", "\"\"", "\"z\"", "\0", "\uffff")
            @test s == sprint(decode_string, sprint(encode_string, s))
        end
    end
end
