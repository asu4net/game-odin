package game

import "engine"

/////////////////////////////
//:EntityRegistry
/////////////////////////////

ENTITY_ID    :: u32
MAX_ENTITIES :: 3000

Entity_Flag :: enum {
    ENABLED,
    VISIBLE,
    SPRITE
}

Entity_Flag_Set :: bit_set[Entity_Flag]

Transform :: struct {
    position : engine.v3,
    rotation : engine.v3,
    scale    : engine.v3
}

DEFAULT_TRANSFORM : Transform : {
    engine.V3_ZERO, engine.V3_ZERO, engine.V3_ONE
}

Entity :: struct {
    //TODO: some uuid
    flags          : Entity_Flag_Set,
    id             : ENTITY_ID,
    name           : string,
    using tranform : Transform
}

NIL_ENTITY_ID :: engine.SPARSE_SET_INVALID

DEFAULT_ENTITY : Entity : {
    flags     = { .ENABLED, .VISIBLE },
    id        = NIL_ENTITY_ID,
    tranform  = DEFAULT_TRANSFORM
}

Entity_Handle :: struct {
    id : ENTITY_ID    
}

Entity_Registry :: struct {
    entities     : [] Entity,
    sparse_set   : engine.Sparse_Set,
    entity_ids   : engine.Queue,
    entity_count : u32
}

@(private = "file")
entity_registry : ^Entity_Registry = nil

entity_registry_set_instance :: proc(instance : ^Entity_Registry) {
    if (entity_registry != nil) {
        assert(false)
        return
    }
    entity_registry = instance
}

entity_registry_get_instance :: proc() -> ^Entity_Registry {
    return entity_registry
}

entity_registry_initialized :: proc() -> bool {
    using entity_registry
    assert(entity_registry != nil)
    return entities != nil
}

entity_registry_init :: proc() {
    using entity_registry, engine
    assert(!entity_registry_initialized())
    entities = make([]Entity, MAX_ENTITIES)
    sparse_init(&sparse_set, MAX_ENTITIES)
    queue_init(&entity_ids, MAX_ENTITIES)
    for i in 0..<MAX_ENTITIES {
        queue_push(&entity_ids, u32(i)) 
    }
}

entity_registry_finish :: proc() {
    using entity_registry, engine
    assert(entity_registry_initialized())
    delete(entities)
    sparse_finish(&sparse_set)
    queue_finish(&entity_ids)
    entity_registry^ = {}
}

entity_valid :: proc(entity : Entity_Handle) -> bool {
    using entity_registry, engine
    assert(entity_registry_initialized())
    return sparse_test(&sparse_set, entity.id)
}

entity_create :: proc() -> (entity : Entity_Handle) {
    using entity_registry, engine
    assert(entity_registry_initialized() && entity_count <= MAX_ENTITIES)
    entity = { queue_front(&entity_ids) }
    queue_pop(&entity_ids)
    index := sparse_insert(&sparse_set, entity.id)
    entities[index] = DEFAULT_ENTITY
    entity_count += 1
    return    
}

entity_data :: proc(entity : Entity_Handle) -> ^Entity {
    using entity_registry, engine
    assert(entity_registry_initialized() && entity_valid(entity))
    index := sparse_search(&sparse_set, entity.id)
    return &entities[index]
}

entity_destroy :: proc(entity : Entity_Handle) {
    using entity_registry, engine
    assert(entity_registry_initialized() && entity_count > 0 && entity_valid(entity))
    deleted, last := sparse_remove(&sparse_set, entity.id)
    entities[deleted] = entities[last]
    queue_push(&entity_ids, entity.id)
    entity_count -= 1
}