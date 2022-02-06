using JuMP, LinearAlgebra, GLPK, SparseArrays
import JuMP.MathOptInterface.OPTIMAL
function solve_aux_prob(
    dual_variables,
    total_length,
    lengths,
    demand,
    c,
)
    n = length(dual_variables)
    # The current pricing model.
    AP = Model(GLPK.Optimizer)
    set_silent(AP) #doesn't show the log
    @variable(AP, x[1:n] >= 0, Int)
    @constraint(AP, sum(x .* lengths) <= total_length)
    @objective(AP, Max, sum(x .* dual_variables))
    print(AP)
    optimize!(AP)
    println("value x[i]")
    for i = 1:5
        println("x[",i,"]=",value(x[i])) 
    end  
    new_pattern = value.(x)
    println("new patterns")
    for i=1:n
        println(new_pattern[i])
    end
    reduced_cost = 1 - objective_value(AP)
    println("reduced-cost ", reduced_cost)
    if  reduced_cost >= 0  
        return nothing
    else 
        return new_pattern
    end
    end

function ex_cutting_stock()
    max_gen_cols= 2
    total_length = 100.0
        c = [
        1.0,
        1.0,
        1.0,
        1.0,
        1.0,
        ]
        lengths = [
        22,
        42,
        52,
        53,
        78,
    ]
    demand = [
        45,
        38,
        25,
        11,
        12,        
    ]
    nwidths = length(c)
    n = length(lengths)
    ncols = length(lengths)
    # Initial set of patterns (stored in a sparse matrix: a pattern won't
    # include many different cuts).
    patterns = SparseArrays.spzeros(UInt16, n, ncols)
    for i in 1:n
        patterns[i, i] =
            min(floor(Int, total_length / lengths[i]), round(Int, demand[i]))
    end
    RMP = Model(GLPK.Optimizer)
    set_silent(RMP) 
    @variable(RMP, λ[1:ncols] >= 0)
    @objective(
        RMP,
        Min,
        sum( c[p] * λ[p] for p in 1:ncols)       
    )
    @constraint(
        RMP,
        demand_satisfaction[j = 1:n],
        sum(patterns[j, p] * λ[p] for p in 1:ncols) >= demand[j]
    )
    print(RMP)
    # First solve of the master problem.
    optimize!(RMP)
    println("objective function value= ",objective_value(RMP))
    for i=1:ncols
        println("λ[",i,"]= ",value(λ[i]))
    end
    println("---------")
    #value.(λ)
    for i=1:n
        println("pi[",i,"]= ",dual(demand_satisfaction[i]))
    end
    if termination_status(RMP) != OPTIMAL
       @warn("Master not optimal ($ncols patterns so far)")
    end
    # Then, generate new patterns, based on the dual information.
    while ncols - n <= max_gen_cols ## Generate at most max_gen_cols columns.
        if !has_duals(RMP)
            break
        end
        new_pattern = solve_aux_prob(
            dual.(demand_satisfaction),
            total_length,
            lengths,
            demand,
            c,
        )
        # No new pattern to add to the formulation: done!
        if new_pattern === nothing
            break
        end
        # Otherwise, add the new pattern to the master problem, recompute the
        # duals, and go on waltzing one more time with the pricing problem.
        ncols += 1
        patterns = hcat(patterns, new_pattern) #add to patterns one new pattern
        # One new variable.
        push!(λ, @variable(RMP, base_name = "λ[$(ncols)]", lower_bound = 0))
        # Update the objective function.
        set_objective_coefficient(
            RMP,
            λ[ncols],
            1,
        )
        # Update the constraint number j if the new pattern impacts this production.
        for j in 1:n
            if new_pattern[j] > 0
                set_normalized_coefficient(
                    demand_satisfaction[j],
                    λ[ncols],
                    new_pattern[j],
                )
            end
        end
        print(RMP)
        # Solve the new master problem to update the dual variables.
        optimize!(RMP)
        println("objective function value= ",objective_value(RMP))
        for i=1:ncols
            println("λ[",i,"]= ",value(λ[i]))
        end
        println("---------")
        #value.(λ)
        for i=1:n
            println("pi[",i,"]= ",dual(demand_satisfaction[i]))
        end
        if termination_status(RMP) != OPTIMAL
            @warn("Master not optimal ($ncols patterns so far)")
        end
    end
     #if termination_status(RMP) != OPTIMAL
     #   @warn("Final master not optimal ($ncols patterns)")
     #   return
    #end
    
end

ex_cutting_stock()


