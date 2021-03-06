"""
    Ellipsoid(radius::Number, q::U, s::U, constant::Symbol) where U<:Real

Represents an ellipsoid with axis ratios `q` and `s`, formed by deforming a sphere
of a certain `radius` at constant `:volume` or major `:axis`.
"""
struct Ellipsoid{T<:Number,U<:Real}
    radius::T
    q::U
    s::U
    constant::Symbol
end


"""
    Sphere(radius::Number)

Returns a spherical `Ellipsoid` with the specified `radius`.
"""
Sphere(radius::Number) = Ellipsoid(radius, 1, 1, :axis)


"""
    rotation_matrix_edgeon(
        p::Particles;
        radius::Union{Number,Nothing}=nothing,
        mass_weighted::Bool=true,
        inertia_matrix_type=:unweighted,
        iterative::Bool=false,
        ellipsoidal_distance::Bool=false,
        constant_volume::Bool=true,
        algorithm::Union{Symbol,Nothing}=nothing,
        return_axes::Bool=false,
    )

Returns a tuple of the 3D rotation matrix for transforming the particles edge-on using the given shape
determination algorithm, and the axis ratios `q` and `s`.
If `return_axes` is `true`, returns the same tuple with an additional element: an array of
the ellipsoid axis vectors.

See [`inertia_matrix`](@ref) and [`inertia_matrix_iterative`](@ref) for the algorithms used for
computing the inertia matrix.

# Keyword Arguments
- `radius::Union{Number,Nothing}`: radius of the initial sphere for determining the inertia matrix (`nothing` to include all particles)
- `mass_weighted::Bool`: `true` if positions should be weighted by mass
- `inertia_matrix_type`: set to `:unweighted` or `:reduced`
- `iterative::Bool`: `true` to use [`inertia_matrix_iterative`](@ref), `false` for [`intertia_matrix`](@ref)
- `ellipsoidal_distance::Bool`: `true` only considered together with inertia matrix type `:reduced`
- `constant_volume::Bool`: `true` if the sphere should be deformed into an ellipsoid with constant volue, `false` for constant major axis
- `algorithm::Union{Symbol,Nothing}`: one of `:unw`, `:red`, `:unw_i_vol`, `:unw_i_ax`, `:red_i_vol`, `:red_i_ax`, `:red_ell_i_vol`, `:red_ell_i_ax`
- `return_axes::Bool`: `true` to return tuple `(rotmat, q, s)`, `false` to return only `rotmat`
"""
function rotation_matrix_edgeon(
    p::Particles;
    radius::Union{Number,Nothing}=nothing,
    mass_weighted::Bool=true,
    inertia_matrix_type=:unweighted,
    iterative::Bool=false,
    ellipsoidal_distance::Bool=false,
    constant_volume::Bool=true,
    algorithm::Union{Symbol,Nothing}=nothing,
    return_axes::Bool=false,
)
    # set algorithm options based on algorithm
    if !isnothing(algorithm)
        inertia_matrix_type, iterative, ellipsoidal_distance, constant_volume =
            get_algorithm_variables(algorithm)
    end

    mass = mass_weighted && haskey(p, "MASS") ? p.mass : nothing

    # select particles within radius if given
    if isnothing(radius)
        ???? = inertia_matrix(p.pos, mass; mass_weighted, inertia_matrix_type)
    else
        if iterative
            ???? = inertia_matrix_iterative(
                p.pos,
                mass,
                inertia_matrix_type;
                radius,
                mass_weighted,
                constant_volume,
                ellipsoidal_distance,
            )
        else
            mask_in_radius = dropdims(sum(abs2, p.pos; dims=1) .??? radius^2; dims=1)
            ???? = inertia_matrix(
                p.pos[:, mask_in_radius],
                isnothing(mass) ? mass : mass[mask_in_radius];
                mass_weighted,
                inertia_matrix_type,
            )
        end
    end

    return rotation_matrix_axis_ratios(????; return_axes)
end


"""
    rotation_matrix_2D(
        p::Particles;
        radius::Union{Number,Nothing}=nothing,
        mass_weighted::Bool=true,
        inertia_matrix_type=:unweighted,
        iterative::Bool=true,
        elliptical_distance::Bool=false,
        constant_area::Bool=true,
        algorithm::Union{Symbol,Nothing}=nothing,
        perspective::Symbol=:edgeon,
        matrix_2d::Bool=false,
    )

Returns a tuple of the 3D or 2D rotation matrix for rotating the particles in 2D, so that the fitted ellipse is
aligned with the axes, and the axis ratio `q`. If `matrix_2d` is `true`, will return the 2D rotation matrix,
otherwise the 3D rotation matrix.

See [`inertia_matrix`](@ref) and [`inertia_matrix_iterative`](@ref) for the algorithms used for
computing the inertia matrix (here only used in 2D, note that terminology is different than in 3D, i.e. elliptical instead of ellipsoidal and constant area instead of volume).

# Keyword Arguments
- `radius::Union{Number,Nothing}`: radius of the initial circle for determining the inertia matrix (`nothing` to include all particles)
- `mass_weighted::Bool`: `true` if positions should be weighted by mass
- `inertia_matrix_type`: set to `:unweighted` or `:reduced`
- `iterative::Bool`: `true` to use [`inertia_matrix_iterative`](@ref), `false` for [`intertia_matrix`](@ref)
- `elliptical_distance::Bool`: `true` only considered together with inertia matrix type `:reduced`
- `constant_area::Bool`: `true` if the circle should be deformed into an ellipse with constant area, `false` for constant major axis
- `algorithm::Union{Symbol,Nothing}`: one of `:unw`, `:red`, `:unw_i_vol`, `:unw_i_ax`, `:red_i_vol`, `:red_i_ax`, `:red_ell_i_vol`, `:red_ell_i_ax` (note the same use of `vol` like in the 3D case instead of `area`)
- `perspective::Symbol`: one of `:edgeon`, `:sideon`, `:faceon`
- `matrix_2d::Bool`: `true` to return 2D rotation matrix, `false` to return only 3D rotation matrix
"""
function rotation_matrix_2D(
    p::Particles;
    radius::Union{Number,Nothing}=nothing,
    mass_weighted::Bool=true,
    inertia_matrix_type=:unweighted,
    iterative::Bool=true,
    elliptical_distance::Bool=false,
    constant_area::Bool=true,
    algorithm::Union{Symbol,Nothing}=nothing,
    perspective::Symbol=:edgeon,
    matrix_2d::Bool=false,
)

    # set algorithm options based on algorithm
    if !isnothing(algorithm)
        inertia_matrix_type, iterative, elliptical_distance, constant_area =
            get_algorithm_variables(algorithm)
    end

    dims = get_dims(perspective)

    # select stars within radius if given
    mass = haskey(p, "MASS") ? p.mass : nothing
    if isnothing(radius)
        ???? = @views inertia_matrix(
            p.pos[dims, :],
            mass;
            mass_weighted,
            inertia_matrix_type,
        )
    else
        if iterative
            ???? = @views inertia_matrix_iterative(
                p.pos[dims, :],
                mass,
                inertia_matrix_type;
                radius,
                mass_weighted,
                constant_volume=constant_area,
                ellipsoidal_distance=elliptical_distance,
            )
        else
            mask_in_radius =
                @views dropdims(sum(abs2, p.pos[dims, :]; dims=1) .??? radius^2; dims=1)
            ???? = inertia_matrix(
                p.pos[dims, mask_in_radius],
                isnothing(mass) ? mass : mass[mask_in_radius];
                mass_weighted,
                inertia_matrix_type,
            )
        end
    end

    Q?????, q, s = rotation_matrix_axis_ratios(????)

    # convert 2d rotation matrix to 3d
    if !matrix_2d
        Q????? = rotation_matrix_to_3d(Q?????, dims)
    end
    return Q?????, q
end


"""
    inertia_matrix(
        pos::AbstractMatrix{<:Number},
        mass::Union{AbstractVector{<:Number},Nothing};
        mass_weighted::Bool=true,
        inertia_matrix_type::Symbol=:unweighted,
    )


Create inertia matrix of different types.

# Keyword Arguments
- `mass_weighted::Bool`: `true` if positions should be weighted by mass
- `inertia_matrix_type::Symbol`: set to `:unweighted` or `:reduced`

## Inertia matrix types
- Unweighted:               Eq. 1 in [Joachimi et al. 2013](https://arxiv.org/abs/1203.6833),
- Mass-weighted unweighted: Eq. 2 in [Tenneti et al. 2015](https://arxiv.org/abs/1409.7297),
- Reduced:                  Eq. 3 in [Tenneti et al. 2015](https://arxiv.org/abs/1409.7297),
                            but without the mass weighting,
- Mass-weighted reduced:    Eq. 3 in [Tenneti et al. 2015](https://arxiv.org/abs/1409.7297).

Note that in the mass-weighted cases, it is not normalized to the total mass,
i.e. different than in Eq2/Eq3 of T2015.
"""
function inertia_matrix(
    pos::AbstractMatrix{<:Number},
    mass::Union{AbstractVector{<:Number},Nothing};
    mass_weighted::Bool=true,
    inertia_matrix_type::Symbol=:unweighted,
)
    # check dimensions
    @assert 2 ??? size(pos, 1) ??? 3
    if mass_weighted
        @assert !isnothing(mass)
        @assert length(mass) == size(pos, 2)
    end

    dim = size(pos, 1)

    # create empty matrix of correct float type (strips units)
    T = mass_weighted ? promote_type(typeof(ustrip(pos[1])), typeof(ustrip(mass[1]))) : typeof(ustrip(pos[1]))
    ????_up = zeros(T, dim, dim)

    fill_????_up!(????_up, pos, mass, mass_weighted, inertia_matrix_type)

    # produce symmetric matrix from upper triangle
    return Symmetric(????_up, :U)
end


"""
    inertia_matrix_iterative(
        pos::AbstractMatrix{<:Number},
        mass::Union{AbstractVector{<:Number},Nothing},
        inertia_matrix_type::Symbol;
        radius::Union{Number,Nothing}=nothing,
        mass_weighted::Bool=true,
        ellipsoidal_distance::Bool=false,
        constant_volume::Bool=true,
        ??::Real=1e-4,
    )

Create inertia matrix of different types iteratively (generally more stable than [`inertia_matrix`](@ref)).

# Keyword Arguments
- `radius::Union{Number,Nothing}`: radius of the sphere to start the iteration with
- `mass_weighted::Bool`: `true` if positions should be weighted by mass
- `ellipsoidal_distance::Bool`: only in combination with `reduced` inertia matrix type; `true` to use distances corrected by ellipsoidal axes
- `constant_volume::Bool`: `true` if the sphere should be deformed into an ellipsoid with constant volume, `false` for constant major axis
- `??::Real`: iterate until a relative change of the shape axis ratios less than `??` is encountered

## Inertia matrix types
- Unweighted:               Eq. 1 in [Joachimi et al. 2013](https://arxiv.org/abs/1203.6833),
- Mass-weighted unweighted: Eq. 2 in [Tenneti et al. 2015](https://arxiv.org/abs/1409.7297),
- Reduced:                  Eq. 3 in [Tenneti et al. 2015](https://arxiv.org/abs/1409.7297),
                            but without the mass weighting,
- Mass-weighted reduced:    Eq. 3 in [Tenneti et al. 2015](https://arxiv.org/abs/1409.7297).
- Reduced with ellipsoidal distances:               TODO
- Mass-weighted reduced with ellipsoidal distances: TODO

Note that in the mass-weighted cases, it is not normalized to the total mass,
i.e. different than in Eq2/Eq3 of T2015.
"""
function inertia_matrix_iterative(
    pos::AbstractMatrix{<:Number},
    mass::Union{AbstractVector{<:Number},Nothing},
    inertia_matrix_type::Symbol;
    radius::Union{Number,Nothing}=nothing,
    mass_weighted::Bool=true,
    ellipsoidal_distance::Bool=false,
    constant_volume::Bool=true,
    ??::Real=1e-4,
)
    # check dimensions
    @assert 2 ??? size(pos, 1) ??? 3
    if mass_weighted
        @assert !isnothing(mass)
        @assert length(mass) == size(pos, 2)
    end

    dim = size(pos, 1)

    # create empty matrix of correct float type (strips units)
    T = mass_weighted ? promote_type(typeof(ustrip(pos[1])), typeof(ustrip(mass[1]))) : typeof(ustrip(pos[1]))
    ????_up = zeros(T, dim, dim)

    # initialize with spherical reduced inertia matrix
    q_old = s_old = one(T)
    if isnothing(radius)
        fill_????_up!(????_up, pos, mass, mass_weighted, inertia_matrix_type)
    else
        mask = dropdims(sum(abs2, pos; dims=1) .??? radius^2; dims=1)
        fill_????_up!(
            ????_up,
            pos[:, mask],
            isnothing(mass) ? mass : mass[mask],
            mass_weighted,
            inertia_matrix_type,
        )
    end
    ???? = Symmetric(????_up, :U)
    Q?????, q, s = rotation_matrix_axis_ratios(????)

    # recompute inertia matrix by adapting ellipsoidal shape until convergence
    i = 0
    while (!isapprox(q_old, q; rtol=??) || !(isnothing(s) || isapprox(s_old, s; rtol=??))) && i < 50
        # ellipsoidal distance for masking
        r??_ell = r??_ellipsoid(rotate(pos, Q?????), q, s)

        # ellipsoidal vs regular distance for inertia matrix
        if ellipsoidal_distance
            r?? = r??_ell
        else
            r?? = dropdims(sum(abs2, pos; dims=1); dims=1)
        end
        if isnothing(radius)
            fill_????_up!(????_up, pos, mass, mass_weighted, inertia_matrix_type, r??=r??)
        else
            factor = dim == 2 ? sqrt(q) : cbrt(q * s)
            r??_max = constant_volume ? (radius / factor)^2 : radius^2
            mask = reshape(r??_ell .??? r??_max, :)
            fill_????_up!(
                ????_up,
                pos[:, mask],
                isnothing(mass) ? mass : mass[mask],
                mass_weighted,
                inertia_matrix_type;
                r??=r??[mask],
            )
        end
        ???? = Symmetric(????_up, :U)

        q_old, s_old = q, s
        Q?????, q, s = rotation_matrix_axis_ratios(????)

        i += 1
    end

    return ????
end


"""
    r??_circle(pos::AbstractMatrix{<:Number})

Squared distances in 2D from origin.
"""
r??_circle(pos::AbstractMatrix{<:Number}) = @views @. pos[1, :]^2 + pos[2, :]^2


"""
    r??_sphere(pos::AbstractMatrix{<:Number})

Squared distances from origin in 2D (calls [`r??_circle`](@ref) in those cases) and 3D.
"""
function r??_sphere(pos::AbstractMatrix{<:Number})
    if size(pos, 1) == 2
        return r??_circle(pos)
    else
        return @views @. pos[1, :]^2 + pos[2, :]^2 + pos[3, :]^2
    end
end


"""
    r??_ellipsoid(pos::AbstractMatrix{<:Number}, q::Real, s::Nothing)

Squared ellipsoidal distances in 2D from origin with axis ratio `q`.

For 3D version, see Eq. 6 in Allgood et al. 2006, https://arxiv.org/abs/astro-ph/0508497
"""
function r??_ellipsoid(pos::AbstractMatrix{<:Number}, q::Real, s::Nothing)
    return @views @. pos[1, :]^2 + pos[2, :]^2 / q^2
end


"""
    r??_ellipsoid(pos::AbstractMatrix{<:Number}, q::Real, s::Real)

Squared ellipsoidal distances from origin with axis ratios `q` and `s`.

See Eq. 6 in Allgood et al. 2006, https://arxiv.org/abs/astro-ph/0508497
"""
function r??_ellipsoid(pos::AbstractMatrix{<:Number}, q::Real, s::Real)
    return @views @. pos[1, :]^2 + pos[2, :]^2 / q^2 + pos[3, :]^2 / s^2
end


"""
    ellipsoidal_mask(
        pos::AbstractMatrix{<:Number},
        ellipsoid::Ellipsoid;
        return_r??_ellipsoid::Bool=false,
    )

Create a `BitArray` for masking the particles within an `ellipsoid`.

The ellipsoid is centered around the origin of the coordinate system with its axes placed
on the x, y, and z axes, from smallest to largest.
If `return_r??_ellipsoid` is `true`, returns a tuple of the mask and the vector r?? for all particles.
"""
function ellipsoidal_mask(
    pos::AbstractMatrix{<:Number},
    ellipsoid::Ellipsoid;
    return_r??_ellipsoid::Bool=false,
)
    r?? = r??_ellipsoid(pos, ellipsoid.q, ellipsoid.s)
    r??_max = if ellipsoid.constant === :volume
        (ellipsoid.radius / cbrt(ellipsoid.q * ellipsoid.s))^2
    else
        ellipsoid.radius^2
    end

    mask = reshape(r?? .??? r??_max, :)

    return return_r??_ellipsoid ? (mask, r??) : mask
end


"""
    fill_????_up!(
        ????_up::AbstractMatrix{<:Real},
        pos::AbstractMatrix{<:Number},
        mass::Union{AbstractVector{<:Number},Nothing},
        mass_weighted::Bool,
        inertia_matrix_type::Symbol;
        r??::Union{AbstractVector{<:Number},Nothing}=nothing,
    )


Fill upper triangle of the inertia matrix for [`inertia_matrix`](@ref) and [`inertia_matrix_iterative`](@ref)

# Arguments
- `mass_weighted::Bool`: `true` if positions should be weighted by mass
- `inertia_matrix_type::Symbol`: set to `:unweighted` or `:reduced`

# Keyword Arguments
- `r??::Union{AbstractVector{<:Number},Nothing}`: if precomputed, the absolute squared distances from the coordinate system's origin; only used when `:reduced` is used

Note that in the mass-weighted cases, it is not normalized to the total mass,
i.e. different than in Eq2/Eq3 of T2015.
"""
function fill_????_up!(
    ????_up::AbstractMatrix{<:Real},
    pos::AbstractMatrix{<:Number},
    mass::Union{AbstractVector{<:Number},Nothing},
    mass_weighted::Bool,
    inertia_matrix_type::Symbol;
    r??::Union{AbstractVector{<:Number},Nothing}=nothing,
)
    # fill upper triangle
    for i in 1:size(????_up, 1), j in i:size(????_up, 1)
        if inertia_matrix_type === :unweighted
            if mass_weighted
                ????_up[i, j] = @views sum(mass .* pos[i, :] .* pos[j, :]) |> ustrip
            else
                ????_up[i, j] = @views sum(pos[i, :] .* pos[j, :]) |> ustrip
            end
        elseif inertia_matrix_type === :reduced
            r?? = isnothing(r??) ? dropdims(sum(abs2, pos; dims=1); dims=1) : r??
            if mass_weighted
                ????_up[i, j] = @views sum(skipnan(mass .* pos[i, :] .* pos[j, :] ./ r??)) |> ustrip
            else
                ????_up[i, j] = @views sum(skipnan(pos[i, :] .* pos[j, :] ./ r??)) |> ustrip
            end
        end
    end

    return ????_up
end


"""
    rotation_matrix_axis_ratios(????::AbstractMatrix{<:Real})

Returns rotation matrix `Q?????` and axis ratios `q` and `s` for an inertia matrix `????`.
`s` is `nothing` if `????` is a 2D matrix.
If `return_axes` is `true`, returns the same tuple with an additional element: an array of
the ellipsoid axis vectors.
"""
function rotation_matrix_axis_ratios(????::AbstractMatrix{<:Real}; return_axes::Bool=false)
    # compute normalized and sorted (in descending order) eigenvalues and eigenvectors
    ??, Q = eigen(????, sortby=?? -> -??) # ??[k] -> Q[:,k]
    Q????? = inv(Q)

    # make rotation matrix always rotate to the same symmetry
    Q????? .*= replace(sign.(Q?????[:, 1]), 0 => one(eltype(Q?????)), -0.0 => one(eltype(Q?????)))

    # determine axis ratios
    q = sqrt(??[2] / ??[1])
    s = size(Q, 1) == 3 ? sqrt(??[3] / ??[1]) : nothing

    if return_axes
        T = eltype(Q)

        # make vectors always point in same general direction
        Q .*= replace(sign.(Q[1, :]'), zero(T) => one(T), -zero(T) => one(T))

        return Q?????, q, s, collect(eachcol(Q))
    end

    return Q?????, q, s
end


"""
    triaxiality(q::Real, s::Real)

Triaxiality from the axis ratios `q` and `s`.

-   ``0 < T < 1/3``: oblate
- ``1/3 < T < 2/3``: triaxial
- ``2/3 < T < 1``:   prolate
"""
triaxiality(q::Real, s::Real) = (1 - q^2) / (1 - s^2)

@doc raw"""
    ellipticity(q::Real)

Ellipticity from axis ratio `q`: ``?? = 1 - q``
"""
ellipticity(q::Real) = 1 - q

@doc raw"""
    eccentricity(q::Real)

Eccentricity from axis ratio `q`: ``e = \sqrt{1 - q^2}``
"""
eccentricity(q::Real) = sqrt(1 - q^2)


"""
    rotation_matrix_to_3d(R::AbstractMatrix{T}, dims::AbstractVector{<:Integer}) where T<:Real

Converts a 2D rotation matrix `R` in the plane given by dimensions `dims` (e.g. `[1, 2]` or `[3, 1]`)
to a 3D rotation matrix.
"""
function rotation_matrix_to_3d(R::AbstractMatrix{T}, dims::AbstractVector{<:Integer}) where {T<:Real}
    @assert size(R) == (2, 2)
    @assert length(dims) == 2

    R3d = zeros(T, 3, 3)

    for i in 1:2, j in 1:2
        R3d[dims[i], dims[j]] = R[i, j]
    end

    R3d[(6 - sum(dims)), (6 - sum(dims))] = one(T)

    return R3d
end

function get_algorithm_variables(algorithm::Symbol)
    if algorithm === :unw
        :unweighted, false, false, false
    elseif algorithm === :red
        :reduced, false, false, false
    elseif algorithm === :unw_i_vol
        :unweighted, true, false, true
    elseif algorithm === :unw_i_ax
        :unweighted, true, false, false
    elseif algorithm === :red_i_vol
        :reduced, true, false, true
    elseif algorithm === :red_i_ax
        :reduced, true, false, false
    elseif algorithm === :red_ell_i_vol
        :reduced, true, true, true
    elseif algorithm === :red_ell_i_ax
        :reduced, true, true, false
    else
        error("""algorithm is none of the allowed values:
                  :unw, :red, :unw_i_vol, :unw_i_ax :red_i_vol, :red_i_ax,
                  :red_ell_i_vol, :red_ell_i_ax.""")
    end
end

