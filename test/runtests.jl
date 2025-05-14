using ParseUnparseJSON
using Test
using Aqua

@testset "ParseUnparseJSON.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(ParseUnparseJSON)
    end
    # Write your tests here.
end
