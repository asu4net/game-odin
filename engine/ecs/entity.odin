package ecs

import "base:intrinsics"
import "engine:global/sparse_set"
import "engine:global/transform"
import "engine:global/vector"
import "core:container/queue"
import "core:fmt"

// TODO: Add transform and name to global. Then add to the entity info.
// TODO: Encapsulate entity info
// TODO: Use slices to return component groups

Entity           :: u32
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

init_name :: proc(name : ^Name, s : string) {
    name.len = u32(len(s))
    assert(name.len <= MAX_NAME_LENGTH)
    copy(name.data[:], s)
}

Signature :: bit_set[0..=MAX_DATA_TYPES]

Entity_Info :: struct {
    id        : Entity,
    signature : Signature,
    name      : Name,
    valid     : bool,
    enabled   : bool,
    transform : transform.Transform,
    tint      : vector.v4
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
}

Entity_Registry :: struct {
    avaliable_ids        : queue.Queue(Entity),
    last_id              : Entity,
    pending_destroy      : map[Entity] struct{}, 
    cycles_since_cleaned : u32,  
    typeid_to_index_map  : map[typeid] u32,
    component_arrays     : [dynamic] ^Raw_Component_Array,
    last_type_index      : u32,
    info_array           : Entity_Info_Array, 
    groups               : map[Signature] [dynamic] Entity
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
    pending_destroy = make(map[Entity] struct{});
    queue.init(&avaliable_ids)
    info_array.infos = make([dynamic] Entity_Info)
    sparse_set.init(&info_array.occupied_ids, MAX_ENTITIES)
    groups = make(map[Signature] [dynamic] Entity)
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
    for _, group in groups do delete(group)
    delete(groups)
    registry^ = {}
}

create :: proc{ create_add, create_empty }

create_add :: proc(name := "", components: ..typeid) -> (entity : Entity) {
    assert(registry_initialized())
    using registry
    
    entity = create_empty(name)

    for component in components {
        //add(component, entity)
    }

    return
}
create_empty :: proc(name := "") -> (entity : Entity) {
    assert(registry_initialized())
    using registry
    
    if queue.len(avaliable_ids) == 0 {
        entity = last_id
        last_id += 1
    } else {
        entity = queue.front(&avaliable_ids)
        queue.pop_front(&avaliable_ids)
    }

    register_info(entity, name)
    return
}

exists :: proc(entity : Entity) -> bool {
    assert(registry_initialized())
    using registry
    return sparse_set.test(&registry.info_array.occupied_ids, entity)
}

is_valid :: proc(entity : Entity) -> bool {
    assert(registry_initialized())
    assert(exists(entity))
    using registry
    return get_info(entity).valid
}

is_enabled :: proc(entity : Entity) -> bool {
    assert(registry_initialized())
    assert(exists(entity))
    using registry
    return get_info(entity).enabled
}

set_enabled :: proc { set_enabled_short, set_enabled_default }

set_enabled_short :: proc(entity : Entity) {
    set_enabled_default(true, entity)
}

set_enabled_default :: proc(enabled : bool, entity : Entity) {
    assert(registry_initialized())
    assert(exists(entity))
    using registry
    info := get_info(entity)
    if info.enabled == enabled do return
    info.enabled = enabled
    if enabled do add_to_groups(entity)
    else do remove_from_groups(entity)
}

get_transform :: proc(entity : Entity) -> ^transform.Transform {
    assert(registry_initialized())
    assert(exists(entity))
    using registry
    return &get_info(entity).transform
}

set_position :: proc(position : vector.v3, entity : Entity) {
    get_transform(entity).position = position
}

get_position :: proc(entity : Entity) -> vector.v3 {
    return get_transform(entity).position
}

set_rotation :: proc(rotation : vector.v3, entity : Entity) {
    get_transform(entity).rotation = rotation
}

get_rotation :: proc(entity : Entity) -> vector.v3 {
    return get_transform(entity).rotation
}

set_scale :: proc(scale : vector.v3, entity : Entity) {
    get_transform(entity).scale = scale
}

get_scale :: proc(entity : Entity) -> vector.v3 {
    return get_transform(entity).scale
}

set_tint :: proc(tint : vector.v4, entity : Entity) {
    get_info(entity).tint = tint
}

get_tint :: proc(entity : Entity) -> vector.v4 {
    return get_info(entity).tint
}

get_name :: proc(entity : Entity) -> ^Name {
    assert(registry_initialized())
    assert(exists(entity))
    using registry
    return &get_info(entity).name
}

set_name :: proc(name : string, entity : Entity) {
    assert(registry_initialized())
    assert(exists(entity))
    using registry
    info := get_info(entity)
    init_name(&info.name, name)
}

destroy :: proc(entity : Entity) {
    assert(registry_initialized())
    assert(is_valid(entity))
    using registry
    assert(entity not_in pending_destroy)
    get_info(entity).valid = false
    pending_destroy[entity] = {}
    remove_from_groups(entity)
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

has :: proc(type : typeid, entity : Entity) -> bool {
    assert(registry_initialized())
    assert(exists(entity))
    using registry
    type_index := get_component_type_index(type)
    info := get_info(entity)
    return type_index in info.signature
}

add :: proc{ add_component_with_data, add_component_default }

add_component_default :: proc($T : typeid, entity : Entity) -> ^T {
    return add_component_with_data(T{}, entity)
}

add_component_with_data :: proc(data : $T, entity : Entity) -> ^T {
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
    info := get_info(entity)
    info.signature += { type_index }
    if !info.enabled do return data_ptr
    add_to_groups(entity)
    return data_ptr
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

remove_all_component_data :: proc(entity : Entity) {
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

remove_component :: proc(entity : Entity, $T : typeid) {
    assert(registry_initialized())
    assert(exists(entity))
    using registry
    assert(is_component_type_registered(T))
    component_array := get_component_array(T)
    assert(sparse_set.test(&component_array.occupied_ids, entity)) // assert has component
    deleted, last := sparse_set.remove(&component_array.occupied_ids, entity)
    if deleted != last do component_array.elements[deleted] = component_array.elements[last]
    info := get_info(entity)
    info.signature -= { component_array.type_index }
    if !info.enabled do return
    remove_from_groups(entity)
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

get :: proc($T : typeid, entity : Entity) -> ^T {
    assert(registry_initialized())
    assert(exists(entity))
    using registry
    assert(is_component_type_registered(T))
    component_array := get_component_array(T)
    assert(sparse_set.test(&component_array.occupied_ids, entity)) // assert has component
    dense_index := sparse_set.search(&component_array.occupied_ids, entity)
    return &component_array.elements[dense_index]
}

register_info :: proc(entity : Entity, name : string) {
    assert(registry_initialized())
    using registry
    info : Entity_Info
    init_name(&info.name, name)
    info.id = entity
    info.valid = true
    info.enabled = true
    info.transform = transform.DEFAULT_TRANSFORM
    info.tint = { 1, 1, 1, 1 }

    dense_index := sparse_set.insert(&info_array.occupied_ids, entity)
    if len(info_array.infos) <= cast(int) dense_index {
        append_elem(&info_array.infos, info)
    } else {
        info_array.infos[dense_index] = info
    }
}

unregister_info :: proc(entity : Entity) {
    assert(registry_initialized())
    using registry
    deleted, last := sparse_set.remove(&info_array.occupied_ids, entity)
    if deleted != last {
        info_array.infos[deleted] = info_array.infos[last]
    }
}

get_info :: proc(id : Entity) -> ^Entity_Info {
    assert(registry_initialized())
    using registry
    assert(sparse_set.test(&info_array.occupied_ids, id)) // entity exists
    dense_index := sparse_set.search(&info_array.occupied_ids, id)
    return &info_array.infos[dense_index]
}

get_group :: proc { get_group_by_types, get_group_by_signature }

get_group_by_types :: proc(types: ..typeid) -> [dynamic] Entity {
    signature := get_group_signature(..types)
    assert(registry_initialized())
    return get_group_by_signature(signature)
}

get_group_by_signature :: proc(signature : Signature) -> [dynamic] Entity {
    assert(registry_initialized())
    using registry
    if signature in groups do return groups[signature]
    return create_group(signature)
}

create_group :: proc(signature : Signature) -> (group : [dynamic] Entity) {
  assert(registry_initialized())
  using registry
  shorter_array_count := max(int)
  shorter_array_index := -1 
  for index in signature {
    assert(index <= u32(len(component_arrays)))
    array := component_arrays[index]
    count := int(array.occupied_ids.count) 
    if count < shorter_array_count {
        shorter_array_index = int(index)
        shorter_array_count = count
    }
  }
  assert(shorter_array_index >= 0)
  shorter_array := component_arrays[shorter_array_index]
  dense := shorter_array.occupied_ids.dense
  count := shorter_array.occupied_ids.count
  assert(signature not_in groups)
  group = make([dynamic] Entity)
  map_insert(&groups, signature, group)
  for i in 0..<count {
    entity_info := get_info(dense[i])
    if entity_info.valid && signature - entity_info.signature == nil {
        append_elem(&group,entity_info.id)
    }
  }
  return
}

remove_from_groups :: proc(entity : Entity) {
    assert(registry_initialized())
    using registry
    info := get_info(entity)
    for signature, &group in groups {
        if signature - info.signature == nil {
            in_group := false
            for e in group {
                if e == entity {
                    in_group = true
                    break
                }
            }
            if in_group do unordered_remove(&group, entity)
        }
    }
}

add_to_groups :: proc(entity : Entity) {
    assert(registry_initialized())
    using registry
    info := get_info(entity)
    for signature, &group in groups {
        if signature - info.signature == nil {
            in_group := false
            for e in group {
                if e == entity {
                    in_group = true
                    break
                }
            }
            if !in_group do append_elem(&group, entity)
        }
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