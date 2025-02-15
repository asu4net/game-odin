package sparse_set

/////////////////////////////
//:Sparse_Set
/////////////////////////////

Sparse_Set :: struct {
    sparse   : []u32,
    dense    : []u32,
    count    : u32,
    capacity : u32,         
}

INVALID :: max(u32)

initialized :: proc(sparse_set : ^Sparse_Set) -> bool {
    using sparse_set
    return sparse != nil && dense != nil && capacity > 0
}

init :: proc(sparse_set : ^Sparse_Set, cap : u32) {
    using sparse_set
    assert(!initialized(sparse_set))
    capacity = cap
    sparse = make([]u32, capacity)
    dense  = make([]u32, capacity)
    for &n in dense {
        n = INVALID
    }
    for &n in sparse {
        n = INVALID
    }
}

sparse_finish :: proc(sparse_set : ^Sparse_Set) {
    assert(initialized(sparse_set))
    using sparse_set
    delete(sparse)
    delete(dense)
    sparse_set^ = {}
}

sparse_test :: proc(sparse_set : ^Sparse_Set, element : u32) -> bool {
    using sparse_set
    assert(initialized(sparse_set))
    return element < capacity && sparse[element] < count && sparse[element] != INVALID
}

sparse_search :: proc(sparse_set : ^Sparse_Set, element : u32) -> u32 {
    using sparse_set
    assert(initialized(sparse_set) && element != INVALID)
    assert(sparse_test(sparse_set, element))
    dense_index := sparse[element]
    return dense_index
}

sparse_is_full :: proc(sparse_set : ^Sparse_Set) -> bool {
    using sparse_set
    assert(initialized(sparse_set))
    assert(count <= capacity)
    return count == capacity
}

sparse_insert :: proc(sparse_set : ^Sparse_Set, element : u32) -> u32 {
    using sparse_set
    assert(initialized(sparse_set))
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
    assert(initialized(sparse_set))
    assert(element < capacity && sparse_test(sparse_set, element))
    
    deleted = sparse[element]
    last = count - 1

    sparse[element] = INVALID
    count -= 1

    if deleted != last {
        last_element := dense[last]
        dense[deleted] = last_element
        sparse[last_element] = deleted
    }
    
    return
}