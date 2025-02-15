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

INVALID_VALUE :: max(u32)

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
        n = INVALID_VALUE
    }
    for &n in sparse {
        n = INVALID_VALUE
    }
}

finish :: proc(sparse_set : ^Sparse_Set) {
    assert(initialized(sparse_set))
    using sparse_set
    delete(sparse)
    delete(dense)
    sparse_set^ = {}
}

test :: proc(sparse_set : ^Sparse_Set, element : u32) -> bool {
    using sparse_set
    assert(initialized(sparse_set))
    return element < capacity && sparse[element] < count && sparse[element] != INVALID_VALUE
}

search :: proc(sparse_set : ^Sparse_Set, element : u32) -> u32 {
    using sparse_set
    assert(initialized(sparse_set) && element != INVALID_VALUE)
    assert(test(sparse_set, element))
    dense_index := sparse[element]
    return dense_index
}

is_full :: proc(sparse_set : ^Sparse_Set) -> bool {
    using sparse_set
    assert(initialized(sparse_set))
    assert(count <= capacity)
    return count == capacity
}

insert :: proc(sparse_set : ^Sparse_Set, element : u32) -> u32 {
    using sparse_set
    assert(initialized(sparse_set))
    assert(element < capacity && !test(sparse_set, element))
    assert(!is_full(sparse_set))
    next_slot := count
    sparse[element] = next_slot
    dense[next_slot] = element
    count+=1
    return next_slot
}

remove :: proc(sparse_set : ^Sparse_Set, element : u32) -> (deleted, last : u32) {
    using sparse_set
    assert(initialized(sparse_set))
    assert(element < capacity && test(sparse_set, element))
    
    deleted = sparse[element]
    last = count - 1

    sparse[element] = INVALID_VALUE
    count -= 1

    if deleted != last {
        last_element := dense[last]
        dense[deleted] = last_element
        sparse[last_element] = deleted
    }
    
    return
}