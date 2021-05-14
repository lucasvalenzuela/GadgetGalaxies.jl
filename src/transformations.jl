@doc raw"""
    rotate(p::Particles, rotmat::AbstractMatrix{<:Real})
    rotate!(p::Particles, rotmat::AbstractMatrix{<:Real})

Rotates the particles `p` by the ``3 \times 3`` rotation matrix `rotmat`.

The non-in-place version `rotate` creates a copy of the particles with only new pointers to the
rotated properties (generally "POS" and "VEL").
"""
function rotate(p::Particles, rotmat::AbstractMatrix{<:Real})
    @assert size(rotmat) == (3, 3)

    pc = copy(p)

    # only rotate existing quantities (currently only pos and vel)
    for prop in intersect(keys(pc), [:pos, :vel])
        pc[prop] = rotate(pc[prop], rotmat)
    end

    return pc
end

function LinearAlgebra.rotate!(p::Particles, rotmat::AbstractMatrix{<:Real})
    @assert size(rotmat) == (3, 3)

    # only rotate existing quantities (currently only pos and vel)
    for prop in intersect(keys(p), [:pos, :vel])
        rotate!(p[prop], rotmat)
    end

    return p
end

@doc raw"""
    rotate(g::AbstractGalaxy, rotmat::AbstractMatrix{<:Real})
    rotate!(g::AbstractGalaxy, rotmat::AbstractMatrix{<:Real})

Rotates the galaxy `g` by the ``3 \times 3`` rotation matrix `rotmat`.

The non-in-place version `rotate` creates a copy of the galaxy with only new pointers to the
rotated quantites (generally "POS" and "VEL") and copies of the particle Dicts.
"""
function rotate(g::AbstractGalaxy, rotmat::AbstractMatrix{<:Real})
    @assert size(rotmat) == (3, 3)

    gc = copy(g)

    # do for stars, dm, etc.
    for p in values(gc)
        # only rotate existing quantities (currently only pos and vel)
        for prop in intersect(keys(p), [:pos, :vel])
            p[prop] = rotate(p[prop], rotmat)
        end
    end

    return gc
end

function LinearAlgebra.rotate!(g::AbstractGalaxy, rotmat::AbstractMatrix{<:Real})
    @assert size(rotmat) == (3, 3)
    # do for stars, dm, etc.
    for p in values(g)
        rotate!(p, rotmat)
    end

    return g
end


"""
    rotate(vals::AbstractMatrix{<:Number}, rotmat::AbstractMatrix{<:Real})
    rotate!(vals::AbstractMatrix{<:Number}, rotmat::AbstractMatrix{<:Real})

Returns `vals` rotated by the rotation matrix `rotmat`. Works for any dimensions.
"""
rotate(vals::AbstractMatrix{<:Number}, rotmat::AbstractMatrix{<:Real}) = rotmat * vals

function LinearAlgebra.rotate!(vals::AbstractMatrix{<:Number}, rotmat::AbstractMatrix{<:Real})
    vals .= rotate(vals, rotmat)
    return vals
end


"""
    rotate_edgeon(p::Particles; axis_ratios::Bool=false, kwargs...)
    rotate_edgeon!(p::Particles; axis_ratios::Bool=false, kwargs...)

Rotates the particles edge-on using the given shape determination algorithm and `radius` (see [`rotation_matrix_edgeon`](@ref) for all keyword parameters).

Keyword parameters
- `axis_ratios::Bool`: `true` to return tuple `(p, q, s)` with particles and axis ratios
"""
function rotate_edgeon(p::Particles; axis_ratios::Bool=false, kwargs...)
    Q⁻¹, q, s = rotation_matrix_edgeon(p; kwargs...)

    pc = rotate(p, Q⁻¹)

    if axis_ratios
        return pc, q, s
    end

    return pc
end

function rotate_edgeon!(p::Particles; axis_ratios::Bool=false, kwargs...)
    Q⁻¹, q, s = rotation_matrix_edgeon(p; kwargs...)

    rotate!(p, Q⁻¹)

    if axis_ratios
        return p, q, s
    end

    return p
end


"""
    rotate_edgeon(g::AbstractGalaxy, ptype::Symbol=:stars; axis_ratios::Bool=false, kwargs...)
    rotate_edgeon!(g::AbstractGalaxy, ptype::Symbol=:stars; axis_ratios::Bool=false, kwargs...)

Rotates the galaxy's particles edge-on for the given particle type `ptype` (`:stars`, `:dm`, `:gas`, etc.)
using the given shape determination algorithm and `radius`
(see [`rotation_matrix_edgeon`](@ref) for all keyword parameters).

Keyword parameters
- `axis_ratios::Bool`: `true` to return tuple `(g, q, s)` with galaxy and axis ratios
"""
function rotate_edgeon(g::AbstractGalaxy, ptype::Symbol=:stars; axis_ratios::Bool=false, kwargs...)
    Q⁻¹, q, s = rotation_matrix_edgeon(g[ptype]; kwargs...)

    gc = rotate(g, Q⁻¹)

    if axis_ratios
        return gc, q, s
    end

    return gc
end

function rotate_edgeon!(g::AbstractGalaxy, ptype::Symbol=:stars; axis_ratios::Bool=false, kwargs...)
    Q⁻¹, q, s = rotation_matrix_edgeon(g[ptype]; kwargs...)

    rotate!(g, Q⁻¹)

    if axis_ratios
        return g, q, s
    end

    return g
end


@doc raw"""
    translate(p::Particles, x⃗::AbstractVector{<:Number})
    translate!(p::Particles, x⃗::AbstractVector{<:Number})

Translates the particles `p` by the vector `x⃗`.

The non-in-place version `translate` creates a copy of the particles with only new pointers to the
positions ("POS").
"""
function translate(p::Particles, x⃗::AbstractVector{<:Number})
    @assert length(x⃗) == 3

    pc = copy(p)

    if haskey(p, :pos)
        pc.pos = pc.pos .+ x⃗
    end

    return pc
end

function translate!(p::Particles, x⃗::AbstractVector{<:Number})
    @assert length(x⃗) == 3

    if haskey(p, :pos)
        p.pos .+= x⃗
    end

    return p
end



@doc raw"""
    translate(g::AbstractGalaxy, x⃗::AbstractVector{<:Number})
    translate!(g::AbstractGalaxy, x⃗::AbstractVector{<:Number})

Translates the galaxy `g` by the vector `x⃗`.

The non-in-place version `translate` creates a copy of the galaxy with only new pointers to the
positions ("POS") and copies of the particle Dicts.
"""
function translate(g::AbstractGalaxy, x⃗::AbstractVector{<:Number})
    @assert length(x⃗) == 3

    gc = copy(g)

    # do for stars, dm, etc.
    for p in values(gc)
        if haskey(p, :pos)
            p.pos = p.pos .+ x⃗
        end
    end

    return gc
end

function translate!(g::AbstractGalaxy, x⃗::AbstractVector{<:Number})
    @assert length(x⃗) == 3

    # do for stars, dm, etc.
    for p in values(g)
        translate!(p, x⃗)
    end

    return g
end




@doc raw"""
    center_of_mass_iterative(
        pos::AbstractMatrix{<:Number},
        mass::AbstractVector{<:Number},
        r_start::Number;
        shrinking_factor::Real=0.025,
        limit_fraction::Real=0.01,
        limit_number::Integer=1000,
    )

Returns the center of mass by applying the shrinking sphere method
([Power et al. 2003](https://arxiv.org/abs/astro-ph/0201544)).

The sphere starts centered at the coordinate system's origin with a radius of `r_start` and
shrinks by `shrinking_factor` every iteration. The iteration is stopped when the sphere
contains fewer than `limit_number` and fewer than `limit_fraction` times the number of particles in the
starting sphere, whichever is smaller.

The radius of the sphere in iteration step ``i`` is ``r_0 (1 - f_\mathrm{shrink})^i``.
"""
function center_of_mass_iterative(
    pos::AbstractMatrix{<:Number},
    mass::AbstractVector{<:Number},
    r_start::Number;
    shrinking_factor::Real=0.025,
    limit_fraction::Real=0.01,
    limit_number::Integer=1000,
)
    r₀ = zeros(eltype(pos), 3)
    r²_max = r_start^2

    # mask particles in initial sphere
    r² = r²_sphere(pos .- r₀)
    mask = r² .≤ r²_max
    n = count(mask)

    # get number limit for when the algorithm should stop
    nlimit = min(limit_number, ceil(Int, limit_fraction * n))
    while n ≥ nlimit
        r₀ .= @views dropdims(sum(pos[:, mask] .* mass[mask]'; dims=2); dims=2) ./ sum(mass[mask])
        r²_max *= (one(typeof(shrinking_factor)) - shrinking_factor)^2

        r² .= r²_sphere(pos .- r₀)
        mask .= r² .≤ r²_max
        n = count(mask)
    end

    return r₀
end


@doc raw"""
    center_of_mass_iterative(p::Particles, r_start::Number; kwargs...)

Returns the center of mass of the particles.
"""
function center_of_mass_iterative(p::Particles, r_start::Number; kwargs...)
    center_of_mass_iterative(p.pos, p.mass, r_start; kwargs...)
end

@doc raw"""
    center_of_mass_iterative(g::AbstractGalaxy, r_start::Number, ptype::Symbol=:stars; kwargs...)

Returns the center of mass of the galaxy's particles of type `ptype` (`:stars`, `:dm`, `:gas`, etc.).
"""
function center_of_mass_iterative(g::AbstractGalaxy, r_start::Number, ptype::Symbol=:stars; kwargs...)
    center_of_mass_iterative(g[ptype], r_start; kwargs...)
end

@doc raw"""
    translate_to_center_of_mass_iterative(p::Particles, r_start::Number; kwargs...)
    translate_to_center_of_mass_iterative!(p::Particles, r_start::Number; kwargs...)

Translates the particles to their center of mass of the particles (see [`center_of_mass_iterative`](@ref)).
"""
function translate_to_center_of_mass_iterative(p::Particles, r_start::Number; kwargs...)
    x⃗ = center_of_mass_iterative(p.pos, p.mass, r_start; kwargs...)

    return translate(p, -x⃗)
end

function translate_to_center_of_mass_iterative!(p::Particles, r_start::Number; kwargs...)
    x⃗ = center_of_mass_iterative(p.pos, p.mass, r_start; kwargs...)

    return translate!(p, -x⃗)
end

@doc raw"""
    translate_to_center_of_mass_iterative(g::AbstractGalaxy, r_start::Number, ptype::Symbol=:stars; kwargs...)
    translate_to_center_of_mass_iterative!(g::AbstractGalaxy, r_start::Number, ptype::Symbol=:stars; kwargs...)

Translates the particles to their center of mass of the particles (see [`center_of_mass_iterative`](@ref)).
"""
function translate_to_center_of_mass_iterative(
    g::AbstractGalaxy,
    r_start::Number,
    ptype::Symbol=:stars;
    kwargs...,
)
    x⃗ = center_of_mass_iterative(g[ptype], r_start; kwargs...)

    return translate(g, -x⃗)
end

function translate_to_center_of_mass_iterative!(
    g::AbstractGalaxy,
    r_start::Number,
    ptype::Symbol=:stars;
    kwargs...,
)
    x⃗ = center_of_mass_iterative(g[ptype], r_start; kwargs...)

    return translate!(g, -x⃗)
end
