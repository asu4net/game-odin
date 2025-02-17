package ecs

import "base:intrinsics"
import "engine:global/sparse_set"
import "core:container/queue"

Entity_ID           ::      u32
NIL_ENTITY_ID       ::      sparse_set.INVALID_VALUE 
CLEANUP_INTERVAL    ::      2 // Zero means each frame
MAX_ENTITIES        ::      10000 //TODO: Hacer el sparse set resizeable

Entity_Registry :: struct {
    avaliable_ids        : queue.Queue(Entity_ID),
    last_id              : Entity_ID,
    pending_destroy      : map[Entity_ID] struct{}, 
    cycles_since_cleaned : u32,
    
    component_registry   : Component_Registry,
    info_array           : Entity_Info_Array, 
}

registry_initialized :: proc() -> bool {
    return registry != nil
}

init_registry :: proc(instance : ^Entity_Registry) {
    assert(!registry_initialized())
    assert(instance != nil)
    registry = instance
    using registry
    pending_destroy = make(map[Entity_ID] struct{});
    queue.init(&avaliable_ids)
    init_component_registry(&component_registry)
    init_info_array(&info_array)
}

finish_registry :: proc() {
    assert(registry_initialized())
    using registry
    queue.destroy(&avaliable_ids)
    finish_component_registry(&component_registry)
    finish_info_array(&info_array)
    registry^ = {}
}

create_entity :: proc(name := "") -> (id : Entity_ID) {
    assert(registry_initialized())
    using registry
    
    if queue.len(avaliable_ids) == 0 {
        id = last_id
        last_id += 1
    } else {
        id = queue.front(&avaliable_ids)
        queue.pop_front(&avaliable_ids)
    }

    register_info(&info_array, id, name)
    return
}

entity_exists :: proc(id : Entity_ID) -> bool {
    assert(registry_initialized())
    using registry
    return sparse_set.test(&registry.info_array.occupied_ids, id)
}

entity_is_valid :: proc(id : Entity_ID) -> bool {
    assert(registry_initialized())
    assert(entity_exists(id))
    using registry
    return get_entity_info(&info_array, id).valid
}

entity_name :: proc(id : Entity_ID) -> ^Name {
    assert(registry_initialized())
    assert(entity_exists(id))
    using registry
    return &get_entity_info(&info_array, id).name
}

destroy_entity :: proc(id : Entity_ID) {
    assert(registry_initialized())
    assert(entity_is_valid(id))
    using registry
    assert(id not_in pending_destroy)
    get_entity_info(&info_array, id).valid = false
    pending_destroy[id] = {}
    //TODO: Para cuando los grupos hay que ver cómo hacer que no se ordene
}

clean_destroyed_entities :: proc() {
    assert(registry_initialized())
    using registry
    
    if cycles_since_cleaned < CLEANUP_INTERVAL {
        cycles_since_cleaned += 1
        return 
    }

    cycles_since_cleaned = 0

    for entity, _  in pending_destroy {
        remove_all_component_data(&component_registry, entity)
        unregister_info(&info_array, entity)
    }

    clear(&pending_destroy)
}

has_component :: proc(entity : Entity_ID, $T : typeid) -> bool {
    assert(registry_initialized())
    assert(entity_exists(entity))
    using registry
    type_index := get_component_type_index(&component_registry, T)
    info := get_entity_info(entity)
    return type_index in info.signature
}

add_component :: proc{ add_component_with_data, add_component_default }

add_component_with_data :: proc(entity : Entity_ID, data : $T) -> ^T {
    #assert(intrinsics.type_is_struct(T))
    assert(registry_initialized())
    assert(entity_exists(entity))
    using registry
    data_ptr, type_index := add_component_data(&component_registry, entity, data)
    get_entity_info(&info_array, entity).signature += { type_index } 
    return data_ptr
}

add_component_default :: proc(entity : Entity_ID, $T : typeid) -> ^T {
    return add_component_with_data(entity, T{})
}

remove_component :: proc(entity : Entity_ID, $T : typeid) {
    assert(registry_initialized())
    assert(entity_exists(entity))
    using registry
    type_index := remove_component_data(&component_registry, entity, T)
    get_entity_info(&info_array, entity).signature -= { type_index }
}

get_component :: proc(entity : Entity_ID, $T : typeid) -> ^T {
    assert(registry_initialized())
    assert(entity_exists(entity))
    return get_component_data(&registry.component_registry, entity, T)
}

//-------------- Internal --------------

@(private="file")
registry : ^Entity_Registry