package game

import "core:math"
import "core:math/linalg"
import "core:mem"

/////////////////////////////
//:Vector2
/////////////////////////////

v2 :: [2] f32

V2_ONE   : v2 : { 1, 1 }
V2_UP    : v2 : { 0, 1 }
V2_RIGHT : v2 : { 1, 0 }
V2_ZERO  : v2 : { 0, 0 }

/////////////////////////////
//:Vector3
/////////////////////////////

v3 :: [3] f32

V3_ONE     : v3 : { 1, 1, 1 }
V3_ZERO    : v3 : { 0, 0, 0 }
V3_UP      : v3 : { 0, 1, 0 }
V3_RIGHT   : v3 : { 1, 0, 0 }
V3_FORWARD : v3 : { 0, 0, 1 }

/////////////////////////////
//:Vector4
/////////////////////////////

v4 :: [4] f32

V4_ZERO               : v4 : { 0, 0, 0, 0 }
V4_ONE                : v4 : { 1, 1, 1, 1 }
V4_COLOR_WHITE        : v4 : { 1, 1, 1, 1 }
V4_COLOR_WHITE_FADED  : v4 : { 1, 1, 1, 0 }
V4_COLOR_BLACK        : v4 : { 0, 0, 0, 1 }
V4_COLOR_BLUE         : v4 : { 0, 0, 1, 1 }
V4_COLOR_LIGHT_BLUE   : v4 : { 0.3, 0.3, 1, 1 }
V4_COLOR_CYAN         : v4 : { 0, 1, 1, 1 }
V4_COLOR_GRAY         : v4 : { 0.5, 0.5, 0.5, 1 }
V4_COLOR_DARK_GRAY    : v4 : { 0.2, 0.2, 0.2, 1 }
V4_COLOR_GREEN        : v4 : { 0, 1, 0, 1 }
V4_COLOR_LIGHT_GREEN  : v4 : { 0.3, 1, 0.3, 1 }
V4_COLOR_GREY         : v4 : { 0.5, 0.5, 0.5, 1 }
V4_COLOR_DARK_GREY    : v4 : { 0.2, 0.2, 0.2, 1 }
V4_COLOR_MAGENTA      : v4 : { 1, 0, 1, 1 }
V4_COLOR_RED          : v4 : { 1, 0, 0, 1 }
V4_COLOR_LIGHT_RED    : v4 : { 1, 0.3, 0.3, 1 }
V4_COLOR_YELLOW       : v4 : { 1, 0.92, 0.016, 1 }
V4_COLOR_ORANGE       : v4 : { 0.97, 0.6, 0.11, 1 }

/////////////////////////////
//:Matrix
/////////////////////////////

m4 :: matrix[4, 4] f32

M4_IDENTITY : m4 : {
    1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 1.0
}

m4_translate :: proc(mat: m4, pos : v3) -> m4 {
    op := M4_IDENTITY  
    op[3][0] = pos.x
	op[3][1] = pos.y
	op[3][2] = pos.z
    return op * mat
}

m4_rotate_x :: proc(mat: m4, angle_x: f32) -> m4 {
    c := math.cos(angle_x);
    s := math.sin(angle_x);
    op := M4_IDENTITY;
    op[1][1] =  c;
    op[1][2] = -s;
    op[2][1] =  s;
    op[2][2] =  c;
    return op * mat;
}

m4_rotate_y :: proc(mat: m4, angle_y: f32) -> m4 {
    c := math.cos(angle_y);
    s := math.sin(angle_y);
    op := M4_IDENTITY;
    op[0][0] =  c;
    op[0][2] =  s;
    op[2][0] = -s;
    op[2][2] =  c;
    return op * mat;
}

m4_rotate_z :: proc(mat: m4, angle_z: f32) -> m4 {
    c := math.cos(angle_z);
    s := math.sin(angle_z);
    op := M4_IDENTITY;
    op[0][0] =  c;
    op[0][1] = -s;
    op[1][0] =  s;
    op[1][1] =  c;
    return op * mat;
}

m4_scale :: proc(mat: m4, scale : v3) -> m4 {
    op := M4_IDENTITY
    op[0][0] = scale.x
    op[1][1] = scale.y
    op[2][2] = scale.z
    return op * mat
}

m4_rotate :: proc(mat: m4, rotation : v3) -> m4 {
    return m4_rotate_z(m4_rotate_y(m4_rotate_x(mat, rotation.x), rotation.y), rotation.z);
}

m4_transform :: proc(position, rotation, scale : v3) -> m4 {
    identity := M4_IDENTITY
    scale_matrix := m4_scale(identity, scale)
    rotation_matrix := rotation != V3_ZERO ? m4_rotate(scale_matrix, math.RAD_PER_DEG * rotation) : scale_matrix
    translation_matrix := m4_translate(rotation_matrix, position)
    return translation_matrix
}

/////////////////////////////
//:Sparse_Set
/////////////////////////////

Sparse_Set :: struct {
    sparse   : []u32,
    dense    : []u32,
    count    : u32,
    capacity : u32,         
}

SPARSE_SET_INVALID :: max(u32)

sparse_initialized :: proc(sparse_set : ^Sparse_Set) -> bool {
    using sparse_set
    return sparse != nil && dense != nil && capacity > 0
}

sparse_init :: proc(sparse_set : ^Sparse_Set, cap : u32) {
    using sparse_set
    assert(!sparse_initialized(sparse_set))
    capacity = cap
    sparse = make([]u32, capacity)
    dense  = make([]u32, capacity)
    for &n in dense {
        n = SPARSE_SET_INVALID
    }
    for &n in sparse {
        n = SPARSE_SET_INVALID
    }
}

sparse_finish :: proc(sparse_set : ^Sparse_Set) {
    assert(sparse_initialized(sparse_set))
    using sparse_set
    delete(sparse)
    delete(dense)
    sparse_set^ = {}
}

sparse_test :: proc(sparse_set : ^Sparse_Set, element : u32) -> bool {
    using sparse_set
    assert(sparse_initialized(sparse_set))
    return element < capacity && sparse[element] < count && sparse[element] != SPARSE_SET_INVALID
}

sparse_search :: proc(sparse_set : ^Sparse_Set, element : u32) -> u32 {
    using sparse_set
    assert(sparse_initialized(sparse_set) && element != SPARSE_SET_INVALID)
    assert(sparse_test(sparse_set, element))
    dense_index := sparse[element]
    return dense_index
}

sparse_is_full :: proc(sparse_set : ^Sparse_Set) -> bool {
    using sparse_set
    assert(sparse_initialized(sparse_set))
    assert(count <= capacity)
    return count == capacity
}

sparse_insert :: proc(sparse_set : ^Sparse_Set, element : u32) -> u32 {
    using sparse_set
    assert(sparse_initialized(sparse_set))
    assert(element < capacity && !sparse_test(sparse_set, element))
    assert(!sparse_is_full(sparse_set))
    next_slot := count
    sparse[element] = next_slot
    dense[next_slot] = element
    count+=1
    return next_slot
}

sparse_remove :: proc(sparse_set : ^Sparse_Set, element : u32) -> (deleted, last : u32) {
    using sparse_set
    assert(sparse_initialized(sparse_set))
    assert(element < capacity && sparse_test(sparse_set, element))
    
    deleted = sparse[element]
    last = count - 1

    sparse[element] = SPARSE_SET_INVALID
    count -= 1

    if deleted != last {
        last_element := dense[last]
        dense[deleted] = last_element
        sparse[last_element] = deleted
    }
    
    return
}

/////////////////////////////
//:Easings
/////////////////////////////

ease_out_expo :: proc(x: f32) -> f32 {
    return x == 1 ? 1 : math.pow(2.0, -10.0 * x)
}

interp_ease_in_expo :: proc(x, min, max: f32) -> f32 {
    factor := ease_in_expo(x)
    return min + (max - min) * factor
}

interp_linear_f32 :: proc(x, min, max: f32) -> f32 {
    return min + (max - min) * x
}

interp_linear_v4 :: proc(x : f32, min, max: v4) -> (v : v4) {
    v.r = interp_linear_f32(x, min.r, max.r)
    v.g = interp_linear_f32(x, min.g, max.g)
    v.b = interp_linear_f32(x, min.b, max.b)
    v.a = interp_linear_f32(x, min.a, max.a)
    return 
}

ease_in_expo :: proc(x: f32) -> f32 {
    return x == 0.0 ? 0.0 : math.pow(2, 10 * (x - 1))
}

/////////////////////////////
//:Transform
/////////////////////////////

Transform :: struct {
    position : v3,
    rotation : v3,
    scale    : v3
}

DEFAULT_TRANSFORM : Transform : {
    V3_ZERO, V3_ZERO, V3_ONE
}

transform_to_m4 :: proc(transform : Transform) -> m4 {
    return m4_transform(transform.position, transform.rotation, transform.scale)
}