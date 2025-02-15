package game

import "core:math"
import "core:math/linalg"
import "core:mem"
import "engine:global/matrix4"

/////////////////////////////
//:Rect
/////////////////////////////

Rect :: struct {
    x, y : f32, width, height : int
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
    ZERO_3D, ZERO_3D, ONE_3D
}

transform_to_m4 :: proc(transform : Transform) -> m4 {
    return matrix4.transform(transform.position, transform.rotation, transform.scale)
}