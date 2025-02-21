package ecs

import "base:intrinsics"
import "engine:global/sparse_set"
import "core:container/queue"
import "core:fmt"

// TODO: Add transform and name to global. Then add to the entity info.
// TODO: Encapsulate entity info
// TODO: Use slices to return component groups

Entity_ID           :: u32
NIL_ENTITY_ID       :: sparse_set.INVALID_VALUE 
CLEANUP_INTERVAL    :: 2 // Zero means each frame
MAX_ENTITIES        :: 10000 //TODO: Hacer el sparse set resizeable
MAX_NAME_LENGTH     :: 10
MAX_DATA_TYPES      :: u32(100) 
Raw_Component_Array :: Component_Array(struct{})

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

Component_Array :: struct($T : typeid) {
    type_index    : u32,
    elements      : [dynamic] T,
    occupied_ids  : sparse_set.Sparse_Set,
    groups        : map[Signature]u32 
}

Entity_Registry :: struct {
    avaliable_ids        : queue.Queue(Entity_ID),
    last_id              : Entity_ID,
    pending_destroy      : map[Entity_ID] struct{}, 
    cycles_since_cleaned : u32,  
    typeid_to_index_map  : map[typeid] u32,
    component_arrays     : [dynamic] ^Raw_Component_Array,
    last_type_index      : u32,
    info_array           : Entity_Info_Array, 
}

@(private)
registry : ^Entity_Registry

registry_initialized :: proc() -> bool {
    return registry != nil
}

init :: proc(instance : ^Entity_Registry) {
    assert(!registry_initialized())
    assert(instance != nil)
    registry = instance
    using registry
    pending_destroy = make(map[Entity_ID] struct{});
    queue.init(&avaliable_ids)
    info_array.infos = make([dynamic] Entity_Info)
    sparse_set.init(&info_array.occupied_ids, MAX_ENTITIES)
}

finish :: proc() {
    assert(registry_initialized())
    using registry
    queue.destroy(&avaliable_ids)
    for &array in component_arrays {
        delete(array.elements)
        sparse_set.finish(&array.occupied_ids)
        free(array)
    }
    delete(component_arrays)
    delete(info_array.infos)
    sparse_set.finish(&info_array.occupied_ids)
    registry^ = {}
}

create :: proc(name := "") -> (id : Entity_ID) {
    assert(registry_initialized())
    using registry
    
    if queue.len(avaliable_ids) == 0 {
        id = last_id
        last_id += 1
    } else {
        id = queue.front(&avaliable_ids)
        queue.pop_front(&avaliable_ids)
    }

    register_info(id, name)
    return
}

exists :: proc(id : Entity_ID) -> bool {
    assert(registry_initialized())
    using registry
    return sparse_set.test(&registry.info_array.occupied_ids, id)
}

is_valid :: proc(id : Entity_ID) -> bool {
    assert(registry_initialized())
    assert(exists(id))
    using registry
    return get_info(id).valid
}

get_name :: proc(id : Entity_ID) -> ^Name {
    assert(registry_initialized())
    assert(exists(id))
    using registry
    return &get_info(id).name
}

destroy :: proc(id : Entity_ID) {
    assert(registry_initialized())
    assert(is_valid(id))
    using registry
    assert(id not_in pending_destroy)
    get_info(id).valid = false
    pending_destroy[id] = {}
    //TODO: Para cuando los grupos hay que ver cómo hacer que no se ordene
}

clean_destroyed :: proc() {
    assert(registry_initialized())
    using registry
    
    if cycles_since_cleaned < CLEANUP_INTERVAL {
        cycles_since_cleaned += 1
        return 
    }

    cycles_since_cleaned = 0

    for entity, _  in pending_destroy {
        remove_all_component_data(entity)
        unregister_info(entity)
    }

    clear(&pending_destroy)
}

has_component :: proc(entity : Entity_ID, type : typeid) -> bool {
    assert(registry_initialized())
    assert(exists(entity))
    using registry
    type_index := get_component_type_index(type)
    info := get_info(entity)
    return type_index in info.signature
}

add_component :: proc{ add_component_with_data, add_component_default }

add_component_default :: proc(entity : Entity_ID, $T : typeid) -> ^T {
    return add_component_with_data(entity, T{})
}

is_component_type_registered :: proc(type : typeid) -> bool {
    assert(registry_initialized())
    using registry
    return type in typeid_to_index_map
}

get_component_type_index :: proc(type : typeid) -> u32 {
    assert(registry_initialized())
    using registry
    assert(is_component_type_registered(type))
    return component_arrays[typeid_to_index_map[type]].type_index
}

register_component_type :: proc($T : typeid) -> (component_array : ^Component_Array(T)) {
    assert(registry_initialized())
    using registry
    assert(last_type_index + 1 <= MAX_DATA_TYPES)
    data_type := typeid_of(T)
    assert(!is_component_type_registered(T))
    component_array = new(Component_Array(T))
    append_elem(&component_arrays, cast(^Raw_Component_Array) component_array)
    map_insert(&typeid_to_index_map, data_type, cast(u32) last_type_index)
    component_array.elements = make([dynamic]T)
    component_array.type_index = last_type_index
    sparse_set.init(&component_array.occupied_ids, MAX_ENTITIES)
    last_type_index += 1
    return
}

remove_all_component_data :: proc(entity : Entity_ID) {
    assert(registry_initialized())
    using registry
    for &component_array in component_arrays {
        if sparse_set.test(&component_array.occupied_ids, entity) {
            deleted, last := sparse_set.remove(&component_array.occupied_ids, entity)
            //TODO: does this actually work? Since the arrays are generic
            if deleted != last do component_array.elements[deleted] = component_array.elements[last]
        }
    }
}

add_component_with_data :: proc(entity : Entity_ID, data : $T) -> ^T {
    #assert(intrinsics.type_is_struct(T))
    assert(registry_initialized())
    assert(exists(entity))
    using registry
    component_array := get_component_array(T) if is_component_type_registered(T) else register_component_type(T)
    assert(!sparse_set.test(&component_array.occupied_ids, entity)) // assert not has component
    dense_index := sparse_set.insert(&component_array.occupied_ids, entity)
    if len(component_array.elements) <= cast(int) dense_index {
        append_elem(&component_array.elements, data)
    } else {
        component_array.elements[dense_index] = data
    }
    data_ptr   := &component_array.elements[dense_index]
    type_index := component_array.type_index
    get_info(entity).signature += { type_index } 
    return data_ptr
}

remove_component :: proc(entity : Entity_ID, $T : typeid) {
    assert(registry_initialized())
    assert(exists(entity))
    using registry
    assert(is_component_type_registered(T))
    component_array := get_component_array(T)
    assert(sparse_set.test(&component_array.occupied_ids, entity)) // assert has component
    deleted, last := sparse_set.remove(&component_array.occupied_ids, entity)
    if deleted != last do component_array.elements[deleted] = component_array.elements[last]
    get_info(entity).signature -= { component_array.type_index }
}

get_component_array :: proc($T : typeid) -> ^Component_Array(T) {
    assert(registry_initialized())
    using registry
    type := typeid_of(T)
    assert(is_component_type_registered(type))
    index := typeid_to_index_map[type]
    assert(index < cast(u32) len(component_arrays))
    component_array := component_arrays[index];
    return cast(^Component_Array(T)) component_array
}

get_component :: proc(entity : Entity_ID, $T : typeid) -> ^T {
    assert(registry_initialized())
    assert(exists(entity))
    using registry
    assert(is_component_type_registered(T))
    component_array := get_component_array(T)
    assert(sparse_set.test(&component_array.occupied_ids, entity)) // assert has component
    dense_index := sparse_set.search(&component_array.occupied_ids, entity)
    return &component_array.elements[dense_index]
}

register_info :: proc(entity : Entity_ID, name : string) {
    assert(registry_initialized())
    using registry
    info : Entity_Info
    name_init(&info.name, name)
    info.id = entity
    info.valid = true

    dense_index := sparse_set.insert(&info_array.occupied_ids, entity)
    if len(info_array.infos) <= cast(int) dense_index {
        append_elem(&info_array.infos, info)
    } else {
        info_array.infos[dense_index] = info
    }
}

unregister_info :: proc(entity : Entity_ID) {
    assert(registry_initialized())
    using registry
    deleted, last := sparse_set.remove(&info_array.occupied_ids, entity)
    if deleted != last {
        info_array.infos[deleted] = info_array.infos[last]
    }
}

get_info :: proc(id : Entity_ID) -> ^Entity_Info {
    assert(registry_initialized())
    using registry
    assert(sparse_set.test(&info_array.occupied_ids, id)) // entity exists
    dense_index := sparse_set.search(&info_array.occupied_ids, id)
    return &info_array.infos[dense_index]
}

/*
Position :: struct { /* ... */ }
Velocity :: struct { /* ... */ }
Rigidbody :: struct { /* ... */ }
get_entity_group :: proc (types: ..typeid) {
  // types is a []typeid
}

get_entity_group(Position, Velocity, Rigidbody)
*/

GroupRange :: struct { 

}

get_group :: proc { get_group_by_types, get_group_by_signature }

get_group_by_types :: proc(types: ..typeid) {
    signature := get_group_signature(..types)
    assert(registry_initialized())
    get_group_by_signature(signature)
}

get_group_by_signature :: proc(signature : Signature) {
    assert(registry_initialized())
    using registry
    for array in component_arrays  {
        if signature in array.groups {
            // TODO: save the group info
            continue
        }
        // group does not exist
        create_group(signature)
        //get_group_by_signature(signature)
        break
    }  
}

create_group :: proc(signature : Signature) {
  assert(registry_initialized())
  using registry
  for index in signature {
    fmt.print(index)
    //TODO: insert group info in the maps
    //TODO: re-arrange the components
  }
}

get_group_signature :: proc{ get_group_signature_by_type, get_group_signature_by_index }

get_group_signature_by_type :: proc(types: ..typeid) -> (signature : Signature) {
    assert(registry_initialized())
    using registry
    for type in types {
      assert(is_component_type_registered(type))
      signature += { get_component_type_index(type) }
    }
    return
}

get_group_signature_by_index :: proc(types: ..u32) -> (signature : Signature) {
  assert(registry_initialized())
  using registry
  for type in types {
    assert(type < cast(u32) len(component_arrays))
    signature += { type }
  }
  return
}