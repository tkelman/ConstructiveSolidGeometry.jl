module ConstructiveSolidGeometry

export Coord
export Ray
export Surface
export Plane
export Sphere
export InfCylinder
export Box
export Region
export Cell
export Geometry
export +,-,*,^,|,~
export reflect
export generate_random_ray
export raytrace
export find_intersection
export halfspace
export is_in_cell
export find_cell_id
export plot_geometry_2D
export plot_cell_2D
export dot
export magnitude
export unitize
export cross

using Plots

"An {x,y,z} coordinate type."
type Coord
    x::Float64
    y::Float64
    z::Float64
end

"A ray is defined by its origin (Coord) and a unitized direction vector (Coord)"
type Ray
    origin::Coord
    direction::Coord
end

abstract Surface

"A plane is defined by a point Coord on the surface of the plane, its unit normal vector Coord, and a boundary condition.
Boundary conditions are transmission (default), reflective, and vacuum"
type Plane <: Surface
    point::Coord
    normal::Coord
    reflective::Bool
	vacuum::Bool
	Plane(point::Coord, normal::Coord, ref::Bool, vac::Bool) = new(point, normal, ref, vac)
	function Plane(point::Coord, normal::Coord, boundary::String)
		if boundary == "reflective"
			new(point, normal, true, false)
		elseif boundary == "vacuum"
			new(point, normal, false, true)
		else
			new(point, normal, false, false)
		end
	end
	Plane(point::Coord, normal::Coord) = new(point, normal, false, false)
end

"A sphere is defined by its center Coord, its radius, and a boundary condition (transmission or vacuum)"
type Sphere <: Surface
    center::Coord
    radius::Float64
    reflective::Bool
	vacuum::Bool
	Sphere(c::Coord, r::Float64, ref::Bool, vac::Bool) = new(c, r, ref, vac)
	function Sphere(c::Coord, r::Float64, boundary::String)
		if boundary == "reflective"
			new(c, r, true, false)
		elseif boundary == "vacuum"
			new(c, r, false, true)
		else
			new(c, r, false, false)
		end
	end
	Sphere(c::Coord, r::Float64) = new(c, r, false, false)
end

"An Infinite Cylinder is defined by a Coord on its central axis, a unit direction vector Coord along its axis, its radius, and a boundary condition (transmission or vacuum)"
type InfCylinder <: Surface
    center::Coord
    normal::Coord
    radius::Float64
    reflective::Bool
	vacuum::Bool
	InfCylinder(c::Coord, n::Coord, r::Float64, ref::Bool, vac::Bool) = new(c, n, r, ref, vac)
	function InfCylinder(c::Coord, n::Coord, r::Float64, boundary::String)
		if boundary == "reflective"
			new(c, n, r, true, false)
		elseif boundary == "vacuum"
			new(c, n, r, false, true)
		else
			new(c, n, r, false, false)
		end
	end
	InfCylinder(c::Coord, n::Coord, r::Float64) = new(c, n, r, false, false)
end

"A box is axis aligned and is defined by the minimum Coord and maximum Coord of the box"
type Box <: Surface
    lower_left::Coord
    upper_right::Coord
end

"Defined by a surface and a halfspace (+1 or -1)"
type Region
    surface::Surface
    halfspace::Int64
end

"Defined by an array of Regions and a Julia expression indicating the logical combination of regions that define the cell"
type Cell
    regions::Array{Region}
    definition::Expr
end

"The top level object that holds all the cells in the problem. This is used as input for the ray tracer"
type Geometry
    cells::Array{Cell}
    bounding_box::Box
end

_p = Coord(0,0,0)

import Base: +, -, *, ^, |, ~
+(a::Coord, b::Coord)     = Coord(a.x+b.x, a.y+b.y, a.z+b.z)
-(a::Coord, b::Coord)     = Coord(a.x-b.x, a.y-b.y, a.z-b.z)
*(a::Float64, b::Coord)   = Coord(a*b.x, a*b.y, a*b.z)
*(b::Coord, a::Float64,)  = Coord(a*b.x, a*b.y, a*b.z)
*(a::Int, b::Coord)       = Coord(a*b.x, a*b.y, a*b.z)
*(b::Coord, a::Int)       = Coord(a*b.x, a*b.y, a*b.z)
dot(a::Coord, b::Coord)   = (a.x*b.x + a.y*b.y + a.z*b.z)
"A utility function to determine the magnitude of a Coord object. Typical use case is to subtract two Coord objects and check the resulting Coord object's magnitude to determine the distance between the two Coords."
magnitude(a::Coord)       = sqrt(dot(a,a))
"A utility function to unitize a Coord object"
unitize(a::Coord)         = (1. / magnitude(a) * a)
cross(a::Coord, b::Coord) = Coord(a.y*b.z - a.z*b.y, a.z*b.x - a.x*b.z, a.x*b.y - a.y*b.x)


# Ray - 3D Plane Intersection
# Returns: hit, distance
# hit: a boolean indicating if an intersection occurred
# distance: the distance to intersection
# Edge case policies:
#    1. Ray is inside the plane: Returns (true, NaN)
#    2. Ray is parallel to the plan, but not inside: Returns (false, NaN)
#    3. Ray never hits plane: Returns (false, NaN)
"Returns a tuple representing if an intersection occurs (Bool) between a Ray and a Surface, and the distance (Float64) the intersection occurs at."
function raytrace(ray::Ray, plane::Plane)
    dist::Float64 = dot( plane.point - ray.origin, plane.normal) / dot( ray.direction, plane.normal)    
    # Check if parallel
    if dist < 0 || dist == Inf
        return false, NaN
    end
    return true, dist
end

# Ray - 3D Sphere Intersection
# Returns hit, distance
# hit: a boolean indicating if an intersection occurred (false if parallel or negative)
# dist: distance to closest intersection point
function raytrace(ray::Ray, sphere::Sphere)
    d::Coord = ray.origin - sphere.center 
    t::Float64 = -dot(ray.direction, d)
    discriminant::Float64 = t^2
    discriminant -= magnitude(d)^2
    discriminant += sphere.radius^2
    
    # If the discriminant is less than zero, they don't hit
    if discriminant < 0
        return false, Inf
    end
    sqrt_val::Float64 = sqrt(discriminant)
    pos::Float64 = t - sqrt_val
    neg::Float64 = t + sqrt_val
    
    if pos < 0  && neg < 0
        return false, NaN
    end
    if pos < 0 && neg > 0
        return true, neg
    end
    if pos < neg && pos > 0
        return true, pos
    end
    
    return true, neg
end

# Ray - 3D Infinite Cylinder Intersection (works for cylinder direction)
# Returns hit, distance
# hit: a boolean indicating if an intersection occurred (false if parallel or negative)
# dist: distance to closest intersection point
function raytrace(ray::Ray, infcylinder::InfCylinder)
    A = infcylinder.center
    # Generate point new point in cylinder for math
    B = infcylinder.center + infcylinder.normal
    O = ray.origin
    r = infcylinder.radius
    AB = B - A
    AO = O - A
    AOxAB = cross(AO, AB)
    VxAB = cross(ray.direction, AB)
    ab2::Float64 = dot(AB, AB)
    a::Float64 = dot(VxAB, VxAB)
    b::Float64 = 2.0 * dot(VxAB, AOxAB)
    c::Float64 = dot(AOxAB, AOxAB) - (r*r * ab2)
    
    # Check Determininant
    det::Float64 = b^2 - 4.0 * a * c
    if det < 0
        return false, Inf
    end
    
    pos::Float64 = (-b + sqrt(det)) / (2.0 * a)
    neg::Float64 = (-b - sqrt(det)) / (2.0 * a)
    
    if pos < 0
        if neg < 0
            return false, NaN
        end
        return true, neg
    end
    if neg < 0
        return true, pos
    end
    if pos < neg
        return true, pos
    else
        return true, neg
    end
end

"Reflects a ray off a plane and returns a new ray with the same origin but different direction."
function reflect(ray::Ray, plane::Plane)
    a = dot(ray.direction, plane.normal)
    b = plane.normal * (2.0 * a)
    c = ray.direction - b
    reflected_ray::Ray = Ray(ray.origin, c)
    return reflected_ray
end

"Returns a randomly sampled ray from within an axis aligned bounding box"
function generate_random_ray(box::Box)
    ray = Ray(Coord(0.0, 0.0, 0.0), Coord(0.0, 0.0, 0.0))
    
    # Sample Origin
    width = Coord(box.upper_right.x - box.lower_left.x, box.upper_right.y - box.lower_left.y, box.upper_right.z - box.lower_left.z)
    ray.origin.x = box.lower_left.x + rand(Float64)*width.x
    ray.origin.y = box.lower_left.y + rand(Float64)*width.y
    ray.origin.z = box.lower_left.z + rand(Float64)*width.z
    
    # Sample Direction From Sphere
    theta::Float64 = rand(Float64) * 2.0 * pi
    z::Float64 = -1.0 + 2.0 * rand(Float64)
    zo::Float64 = sqrt(1.0 - z*z)
    ray.direction.x = zo * cos(theta);
    ray.direction.y = zo * sin(theta);
    ray.direction.z = z;
    
    # Normalize Direction
    ray.direction = unitize(ray.direction)
    
    return ray
end

# Core ray tracing function. Takes a ray and an array of surfaces to test.
# Moves ray forward and reflects its direction if needed
# returns ray and shape index
"This version of the function takes a Ray and an array of Regions and performs ray tracing. It returns a new Ray that has been moved just accross the point of intersection, the surface id that was hit, and the boundary condition of the surface that was hit"
function find_intersection(ray::Ray, regions::Array{Region})
    BUMP::Float64 = 1.0e-9
    min::Float64 = 1e30
    id::Int64 = -1
    for i = 1:length(regions)
        hit, dist = raytrace(ray, regions[i].surface)
        if hit == true
            if dist < min
                min = dist
                id = i
            end
        end
    end
    
    new_ray::Ray = Ray(ray.origin + ray.direction * (min + BUMP), ray.direction)
    
    if regions[id].surface.reflective == true
        new_ray = reflect(new_ray, regions[id].surface)
        new_ray.origin = new_ray.origin + new_ray.direction * (2.0 * BUMP)
		return new_ray, id, "reflective"
    end
    
	if regions[id].surface.vacuum == true
		return new_ray, id, "vacuum"
    end
    
    return new_ray, id, "transmission"

end

"This version of the function takes a Ray and a Geometry and performs ray tracing. It returns a new Ray that has been moved just accross the point of intersection, the surface id that was hit, and the boundary condition of the surface that was hit"
# Overloaded form that works with full geometry rather than a specific cell
# I.e., finds the cell that the ray is starting in then performs ray trace
function find_intersection(ray::Ray, geometry::Geometry)
	cell_id = find_cell_id(ray.origin, geometry)
	regions::Array{Region} = geometry.cells[cell_id].regions	
	return find_intersection(ray, regions)
end

# Plane halfspace determination
function halfspace(c::Coord, plane::Plane)
    d::Float64 = -dot(plane.normal, plane.point)
    half::Float64 = dot(plane.normal, c) + d
    if half <= 0
        return -1
    else
        return 1
    end
end

# Sphere halfspace determination
function halfspace(c::Coord, sphere::Sphere)
    half::Float64 = (c.x - sphere.center.x)^2 + (c.y - sphere.center.y)^2 + (c.z - sphere.center.z)^2 - sphere.radius^2
    if half <= 0
        return -1
    else
        return 1
    end
end

# Infinite cylinder halfspace
function halfspace(c::Coord, cyl::InfCylinder)
    tmp::Coord = cross((c-cyl.center), cyl.normal)
    half::Float64 = dot(tmp, tmp) - cyl.radius^2
    if half <= 0
        return -1
    else
        return 1
    end
end


function ^(a::Region, b::Region)
    if halfspace(_p, a.surface) == a.halfspace 
        if halfspace(_p, b.surface) == b.halfspace
            return true
        end
    end
    return false
end

function ^(a::Region, b::Bool)
    if halfspace(_p, a.surface) == a.halfspace
        if b == true
            return true
        end
    end
    return false
end

function ^(b::Bool, a::Region)
    if halfspace(_p, a.surface) == a.halfspace
        if b == true
            return true
        end
    end
    return false
end

function |(a::Region, b::Region)
    if halfspace(_p, a.surface) == a.halfspace
        return true
    end
    if halfspace(_p, b.surface) == b.halfspace
        return true
    end
    return false
end

function |(a::Region, b::Bool)
    if halfspace(_p, a.surface) == a.halfspace
        return true
    end
    if b == true
        return true
    end
    return false
end

function |(b::Bool, a::Region)
    if halfspace(_p, a.surface) == a.halfspace
        return true
    end
    if b == true
        return true
    end
    return false
end

function ~(a::Region)
    b::Region = Region(a.surface, a.halfspace)
    if a.halfspace == -1
        b.halfspace = 1
    else
        b.halfspace = -1
    end
    return b
end

"Determines if a Coord (such as a Ray origin) is inside a given Cell"
function is_in_cell(p::Coord, cell::Cell)
    result = navigate_tree(p, cell.regions, cell.definition)
    return result
end

function navigate_tree(p::Coord, r::Array{Region}, ex::Expr)
    global _p = Coord(p.x, p.y, p.z)

	# Check if Complement
	if ex.args[1] == :~
		if typeof(ex.args[2]) == typeof(1)
			return ~ r[ex.args[2]]
		else
			return ~ navigate_tree(p, r, ex.args[2])
		end
	end
	
	if typeof(ex.args[2]) == typeof(1)
		# Case 1 - Both operands are leaves
		if typeof(ex.args[3]) == typeof(1)
			if ex.args[1] == :^
            	return r[ex.args[2]] ^ r[ex.args[3]]
			end
			if ex.args[1] == :|
            	return r[ex.args[2]] | r[ex.args[3]]
			end
		end
		# Case 2 - Left operand is leaf, right is not
		if typeof(ex.args[3]) != typeof(1)
			if ex.args[1] == :^
            	return r[ex.args[2]] ^ navigate_tree(p, r, ex.args[3])
			end
			if ex.args[1] == :|
            	return r[ex.args[2]] | navigate_tree(p, r, ex.args[3])
			end
		end
	end
	
	if typeof(ex.args[2]) != typeof(1)
		# Case 3 - left operand is not leaf, but right is
		if typeof(ex.args[3]) == typeof(1)
			if ex.args[1] == :^
            	return navigate_tree(p, r, ex.args[2]) ^ r[ex.args[3]]
			end
			if ex.args[1] == :|
            	return navigate_tree(p, r, ex.args[2]) | r[ex.args[3]]
			end
		end
		# Case 4 - Neither operand is a leaf
		if typeof(ex.args[3]) != typeof(1)
			if ex.args[1] == :^
            	return navigate_tree(p, r, ex.args[2]) ^ navigate_tree(p, r, ex.args[3])
			end
			if ex.args[1] == :|
            	return navigate_tree(p, r, ex.args[2]) | navigate_tree(p, r, ex.args[3])
			end
		end
	end
end

"Finds the cell id given a Coord and a Geometry object"
function find_cell_id(p::Coord, geometry::Geometry)
    for i = 1:length(geometry.cells)
        if is_in_cell(p, geometry.cells[i]) == true
            return i
        end
    end
    return -1
end


# Plots a 2D slice of a given geometry. Takes the geometry object and a view.
# The view is a 2D box (in x and y) that defines what will be plotted
# The z dimension should be the same for lower_left and upper_right, and
# represents where the slice is taken at
"Plots a 2D slice given a Geometry, a view box, and a dimension. The view box is an axis aligned box that defines where the picture will be taken, with both z dimensions indicating the single z elevation the slice is taken at. The dimension is the number of pixels along the x and y axis to use, which determines the resolution of the picture"
function plot_geometry_2D(geometry::Geometry, view::Box, dim::Int64)
    delta_x = (view.upper_right.x - view.lower_left.x) / (dim)
    delta_y = (view.upper_right.y - view.lower_left.y) / (dim)
    
    x_coords = collect(view.lower_left.x + delta_x/2.0:delta_x:view.upper_right.x - delta_x/2.0)
    y_coords = collect(view.lower_left.y + delta_y/2.0:delta_y:view.upper_right.y - delta_y/2.0)

    pixels = Array{Int64, 2}(dim, dim)
    
    for i=1:dim
        for j=1:dim
            pixels[i,j] = find_cell_id(Coord(x_coords[i], y_coords[j], view.lower_left.z), geometry)
        end
    end
    pixels = rotl90(pixels)
    colors = Array{RGBA}(0)
    for i=1:length(geometry.cells)
        if (i-1)%4 == 0
            push!(colors, RGBA(1.0, 0.0, 0.0, 1.0))
        elseif (i-1)%4 == 1
            push!(colors, RGBA(0, 1.0, 0, 1.0))
        elseif (i-1)%4 == 2
            push!(colors, RGBA(1.0, 0.0, 1.0, 1.0))
        elseif (i-1)%4 == 3
            push!(colors, RGBA(0, 0, 1.0, 1.0))
        end
        #push!(colors, RGBA(rand(),rand(),rand(),1.0) )
    end
    gradient = ColorGradient(colors)
    heatmap(x_coords,y_coords,pixels,aspect_ratio=1, color=gradient, leg=false)  
end

# Plots a 2D slice of a given cell. Takes the cell and a view.
# The view is a 2D box (in x and y) that defines what will be plotted
# The z dimension should be the same for lower_left and upper_right, and
# represents where the slice is taken at
"Plots a 2D slice highlighting a single Cell, given a Geometry, a view box, a dimension, and the cell id. The view box is an axis aligned box that defines where the picture will be taken, with both z dimensions indicating the single z elevation the slice is taken at. The dimension is the number of pixels along the x and y axis to use, which determines the resolution of the picture"
function plot_cell_2D(geometry::Geometry, view::Box, dim::Int64, cell_id::Int64)
    delta_x = (view.upper_right.x - view.lower_left.x) / (dim)
    delta_y = (view.upper_right.y - view.lower_left.y) / (dim)
    
    x_coords = collect(view.lower_left.x + delta_x/2.0:delta_x:view.upper_right.x - delta_x/2.0)
    y_coords = collect(view.lower_left.y + delta_y/2.0:delta_y:view.upper_right.y - delta_y/2.0)

    pixels = Array{Int64, 2}(dim, dim)
    
    for i=1:dim
        for j=1:dim
            pixels[i,j] = find_cell_id(Coord(x_coords[i], y_coords[j], view.lower_left.z), geometry)
            if pixels[i, j] == cell_id
                pixels[i, j] = 0
            else
                pixels[i, j] = 1
            end
        end
    end
    pixels = rotl90(pixels)
    colors = Array{RGBA}(0)
    push!(colors, RGBA(0.0, 0.0, 0.0, 1.0))
    push!(colors, RGBA(1.0, 1.0, 1.0, 1.0))
    gradient = ColorGradient(colors)
    heatmap(x_coords,y_coords,pixels,aspect_ratio=1, color=gradient, leg=false)  
end

end # module
