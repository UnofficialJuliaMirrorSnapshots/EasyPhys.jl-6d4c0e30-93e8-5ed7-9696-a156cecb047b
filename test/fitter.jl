
import DataFrames.DataFrame


@testset "fitter.jl" begin

@testset "fitter.jl exceptions" begin
    f_test(x, a, b) = a .* x .+ b
    g_test(x) = x.^2

    bad_data_test = DataFrame(Any[[1:10], [7:16]])

    fitter_test = Fitter(f_test; autoplot=false)

    @test_throws EasyPhys.CannotFitException  Fitter(g_test)

    @test_throws EasyPhys.NoResultsException  fitter_test |> apply_f(5)
    @test_throws EasyPhys.NoResultsException  fitter_test[:a]

    @test_throws EasyPhys.BadDataException    fit!(fitter_test)
    @test_throws EasyPhys.BadDataException    set_data!(
                                                fitter_test, [1, 2, 3],
                                                [4, 5], [1, 2, 3])
    @test_throws EasyPhys.BadDataException    set_data!(
                                                fitter_test, [1, 2, 3],
                                                [4, 5, 6], [1, 2])
    @test_throws EasyPhys.BadDataException    set_data!(
                                                fitter_test, bad_data_test)

    @test_throws KeyError fitter_test[:notakey] = 7
    @test_throws KeyError something = fitter_test[:stillnotakey]

end

tolerance_test = 0.08
outlier_threshold_test = 2

model_test(x, a, b) = a .* exp.(-x .* b)

xdata_test = linspace(0, 10, 100)
eydata_test = 0.01

@testset "fitter.jl `fit!` and friends" begin
    fitter_test = Fitter(model_test) |> set!(autoplot=false)
    show(fitter_test)

    for a in 1:20:81, b in 1:2:11
        ydata_test = model_test(xdata_test, a, b) + 0.01*randn(length(xdata_test))

        set_data!(fitter_test, xdata_test, ydata_test, eydata_test) |> fit!
        χ²_init_test = reduced_χ²(fitter_test, [a, b])
        χ²_worse_test = reduced_χ²(fitter_test)

        @test all(abs.([fitter_test[:a][1], fitter_test[:b][1]] .- [a, b])
                    ./ [a, b]
                    .<= tolerance_test)

        ignore_outliers!(fitter_test, outlier_threshold_test) |> fit!
        χ²_better_test = reduced_χ²(fitter_test)

        @test χ²_init_test >= χ²_worse_test >= χ²_worse_test

        y_true_test = model_test(xdata_test, a, b)
        @test all(apply_f(fitter_test, xdata_test, [a, b]) == y_true_test)

        fix!(fitter_test; a=1.01a) |> fit! |> apply_f(5)
        free!(fitter_test, :a)
    end

    fitter_test[:xmax] = 90
    fit!(fitter_test)
    show(fitter_test)

    show(parameter_covariance(fitter_test))
    show("\n\n")
end

@testset "fitter.jl fixing and freeing parameters" begin
    fitter_test = Fitter(model_test) |> set!(autoplot=false)

    a = 1
    b = 2
    ydata_test = model_test(xdata_test, a, b) + 0.01*randn(length(xdata_test))
    set_data!(fitter_test, xdata_test, ydata_test, eydata_test)

    fitter_test |> fix!(a=1) |> guess!(b=2) |> fit!
    @test fitter_test[:a] == 1
    show(fitter_test)

    guess!(fitter_test; a=3)
    @test fitter_test[:a] == 1

    fitter_test[:a] = 1.1
    fitter_test[:b] = 3
    fitter_test |> fit!

    fix!(fitter_test; b=2)
    @test_throws EasyPhys.CannotFitException fit!(fitter_test)

    fitter_test |> free!(a=1) |> fit!
    fitter_test |> fix!(b=1) |> guess!([2.0]) |> fit!
    show(fitter_test)

    fitter_test |> free!(:b) |> guess!([2.0, 1.0]) |> fit!
    show(fitter_test)
end

end
