module Mux

export mux, stack, branch

using Base64: stringmime

# This might be the smallest core ever.

mux(fn) = fn
mux(prev, last) = x -> prev(last, x)  # prev is expected to call/return/operate on last(x)
mux(parts...) = foldr(mux, parts)

#= # Experiment 3: Generated function
@generated function mux(parts...)
    symb = gensym("request")
    ex = :($(symb))
    for fn in parts
        ex = :($fn($ex))
    end
    return :(($symb -> $ex)())
end
=#
function run_trampoline(func)
    while func isa Function
        func = func()
    end
    func
end

fact(n) = run_trampoline(fact(n, 1))
function fact(n, total)
    n == 0 && return total
    return ()-> fact(n - 1, n * total)
end

println(fact(5))

#= Experiment 1,2: rewrite mux to trampoline: this is hard because
- exceptions
- intermediate fns are invoked, we can't change existing code (can we?)

mux(parts...) = request -> begin
    current = request
    last = parts[end](current)
    for next in parts[end-1:-1:1]
        last = try
            next(last, current)
        catch e
            e
        end
    end
end
=#

stack(m) = m
stack(m, parts) = function stackhelper(next, x)
    m(mux(parts, next), x)
end
stack(parts...) = foldl(stack, parts)

branch(predicate, dofn) = function branchhelper(chain, req)
    if predicate(req)
        dofn(req)
    else
        chain(req)
    end
end
branch(predicate, parts...) = branch(predicate, mux(parts...))

# May as well provide a few conveniences, though.

using Hiccup

include("lazy.jl")
include("server.jl")
include("basics.jl")
include("routing.jl")

include("websockets_integration.jl")

include("examples/mimetypes.jl")
include("examples/basic.jl")
include("examples/files.jl")

defaults = stack(todict, basiccatch, splitquery, toresponse, assetserver, pkgfiles)
wdefaults = stack(todict, wcatch, splitquery)
prod_defaults = stack(todict, stderrcatch, splitquery, toresponse, assetserver, pkgfiles)

end
