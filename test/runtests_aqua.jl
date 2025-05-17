module TestAqua
    using ParseUnparseJSON
    using Test
    using Aqua: Aqua
    @testset "Aqua.jl" begin
        Aqua.test_all(ParseUnparseJSON; persistent_tasks = false)
    end
end
