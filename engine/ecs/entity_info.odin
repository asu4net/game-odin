#+private 
package ecs
import "engine:global/sparse_set"

MAX_NAME_LENGTH :: 10
MAX_DATA_TYPES :u32: 100 

//name_to_string -> string(data[:len])
Name :: struct {
    data : [MAX_NAME_LENGTH] u8,
    len  : u32
}

name_init :: proc(name : ^Name, s : string) {
    name.len = u32(len(s))
    assert(name.len <= MAX_NAME_LENGTH)
    copy(name.data[:], s)
}

Signature :: bit_set[0..=MAX_DATA_TYPES]

Entity_Info :: struct {
    id        : Entity_ID,
    signature : Signature,
    name      : Name,
    valid     : bool,
    //TODO: children list
}

Entity_Info_Array :: struct {
    infos        : [dynamic] Entity_Info,
    occupied_ids : sparse_set.Sparse_Set,
}

init_info_array :: proc(arr : ^Entity_Info_Array) {
    assert(arr != nil)
    using arr
    infos = make([dynamic] Entity_Info)
    sparse_set.init(&occupied_ids, MAX_ENTITIES)
}

finish_info_array :: proc(arr : ^Entity_Info_Array) {
    assert(arr != nil)
    using arr
    delete(infos)
    sparse_set.finish(&occupied_ids)
}

register_info :: proc(arr : ^Entity_Info_Array, entity : Entity_ID, name : string) {
    assert(arr != nil)
    using arr
    info : Entity_Info
    name_init(&info.name, name)
    info.id = entity
    info.valid = true

    dense_index := sparse_set.insert(&occupied_ids, entity)
    if len(infos) <= cast(int) dense_index {
        append_elem(&infos, info)
    } else {
        infos[dense_index] = info
    }
}

unregister_info :: proc(arr : ^Entity_Info_Array, entity : Entity_ID) {
    assert(arr != nil)
    using arr
    deleted, last := sparse_set.remove(&occupied_ids, entity)
    if deleted != last {
        infos[deleted] = infos[last]
    }
}

get_info :: proc(arr : ^Entity_Info_Array, id : Entity_ID) -> ^Entity_Info {
    assert(arr != nil)
    using arr
    assert(sparse_set.test(&occupied_ids, id)) // entity exists
    dense_index := sparse_set.search(&occupied_ids, id)
    return &infos[dense_index]
}