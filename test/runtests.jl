using Test

@testset "ParseUnparseJSON.jl" begin
    include("runtests_token_util.jl")
    include("runtests_parser_idents.jl")
    include("runtests_aqua.jl")
end
