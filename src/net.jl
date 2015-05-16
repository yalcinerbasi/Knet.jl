# Each Layer implements some common functions, here are the stubs:
# forw takes input x and returns output y, possibly setting some state
# back takes dy, the loss gradient wrt y, and returns dx, the loss gradient wrt x
# Some layers overwrite their inputs

abstract Layer
forw(l::Layer, x; o...)=nothing
back(l::Layer, dy; o...)=nothing
update(l::Layer)=nothing
setparam!(l::Layer,k,v)=nothing

# LossLayer is slightly different:
# forw only records the outgoing y.
# back takes z, the desired output, and overwrites it with the loss gradient wrt y
# loss takes z, the desired output, and returns a loss value

abstract LossLayer <: Layer
loss(l::LossLayer, z)=nothing

# Net: Convenience type for an array of layers

typealias Net Array{Layer,1}
forw(n::Net, x; fx=true)=(for l in n; x=forw(l, x; fx=fx) end; x)
back(n::Net, dy)=(for i=length(n):-1:1 dy=back(n[i],dy; dx=(i>1)) end)
update(n::Net)=(for l in n; update(l); end)
setparam!(n::Net,k,v)=(for l in n; setparam!(l,k,v); end)

# The backprop algorithm

function backprop(net::Net, x, dy)
    y = forw(net, x) 	# y: network output
    back(net, dy)       # calculate derivatives given desired output dy
end

# Predict implements forw with minibatches.

function predict(net::Net, x, y=nothing; batch=0)
    ninst = size(x, ndims(x))
    (batch == 0 || batch > ninst) && (batch = ninst)
    xx = yy = y = nothing
    for b = 1:batch:ninst
        e  = min(ninst, b + batch - 1)
        xx = x2b(xx, x, b:e)
        yy = forw(net, xx; fx=false)
        y  = b2y(y, yy, b:e, x)
    end
    free(xx)
    return y
end

# Train implements backprop with updates and minibatches.
# It runs for one epoch by default, iters can be specified to stop earlier.

function train(net::Net, x, y; batch=128, iters=0)
    # shuffle && shufflexy!(x,y) # did not debug this with N-D
    ninst = size(x, ndims(x))
    (batch == 0 || batch > ninst) && (batch = ninst)
    xx = yy = nothing
    for b = 1:batch:ninst
        e = min(ninst, b + batch - 1)
        xx = x2b(xx, x, b:e)
        yy = x2b(yy, y, b:e)
        backprop(net, xx, yy)
        update(net)
        (iters > 0) && (e/batch >= iters) && break
    end
    free(xx); free(yy)
end

function x2b(b, x, r)
    bs = tuple(size(x)[1:end-1]..., length(r))
    if ((b == nothing) || (size(b) != bs))
        b == nothing || free(b)
        b = Atype(Ftype, bs)
    end
    xi = 1 + (first(r) - 1) * stride(x, ndims(x))
    copy!(b, 1, x, xi, length(b))
end

function b2y(y, b, r, x)
    n = size(x, ndims(x))
    ys = tuple(size(b)[1:end-1]..., n)
    (y == nothing) && (y = similar(x, ys))
    @assert size(y) == ys
    yi = 1 + (first(r) - 1) * stride(y, ndims(y))
    copy!(y, yi, b, 1, length(b))
end

