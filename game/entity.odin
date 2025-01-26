package game
import "core:strings"

ENTITY_ID    :: u32
MAX_ENTITIES :: 3000

Entity_Flag :: enum {
    ENABLED,
    VISIBLE,
    SPRITE
}

Entity_Flag_Set :: bit_set[Entity_Flag]

/////////////////////////////
//:Entity
/////////////////////////////

EntityCommon :: struct {
    //TODO: some uuid
    flags          : Entity_Flag_Set,
    id             : ENTITY_ID,
    name           : string,
    tint           : v4,
}

DEFAULT_ENTITY_COMMON : EntityCommon : {
    flags = { .ENABLED, .VISIBLE },
    id    = NIL_ENTITY_ID,
    tint  = V4_COLOR_WHITE
}

Entity :: struct {
    using common   : EntityCommon,
    using tranform : Transform,
    using sprite   : Sprite
}

NIL_ENTITY_ID :: SPARSE_SET_INVALID

DEFAULT_ENTITY : Entity : {
    common    = DEFAULT_ENTITY_COMMON,
    tranform  = DEFAULT_TRANSFORM,
    sprite    = DEFAULT_SPRITE
}

Entity_Handle :: struct {
    id : ENTITY_ID    
}

/////////////////////////////
//:Entity Registry
/////////////////////////////

Entity_Registry :: struct {
    entities     : [] Entity,
    sparse_set   : Sparse_Set,
    entity_ids   : Queue,
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
    using entity_registry
    assert(!entity_registry_initialized())
    entities = make([]Entity, MAX_ENTITIES)
    sparse_init(&sparse_set, MAX_ENTITIES)
    queue_init(&entity_ids, MAX_ENTITIES)
    for i in 0..<MAX_ENTITIES {
        queue_push(&entity_ids, u32(i)) 
    }
}

entity_registry_finish :: proc() {
    using entity_registry
    assert(entity_registry_initialized())
    delete(entities)
    sparse_finish(&sparse_set)
    queue_finish(&entity_ids)
    entity_registry^ = {}
}

entity_valid :: proc(entity : Entity_Handle) -> bool {
    using entity_registry
    assert(entity_registry_initialized())
    return sparse_test(&sparse_set, entity.id)
}

entity_create :: proc(name : string = "", flags : Entity_Flag_Set = {}) -> (entity : Entity_Handle) {
    using entity_registry
    assert(entity_registry_initialized() && entity_count <= MAX_ENTITIES)
    entity = { queue_front(&entity_ids) }
    queue_pop(&entity_ids)
    index := sparse_insert(&sparse_set, entity.id)
    data := &entities[index]
    data^ = DEFAULT_ENTITY
    data.id = entity.id
    data.flags += flags
    data.name = name
    
    if len(data.name) == 0 {
        builder : ^strings.Builder
        strings.builder_init(builder)
        defer strings.builder_destroy(builder)
        strings.write_string(builder, "Entity ")
        strings.write_uint(builder, uint(entity.id))
        data.name = strings.to_string(builder^)    
    }

    entity_count += 1
    return    
}

entity_data :: proc(entity : Entity_Handle) -> ^Entity {
    using entity_registry
    assert(entity_registry_initialized() && entity_valid(entity))
    index := sparse_search(&sparse_set, entity.id)
    return &entities[index]
}

entity_add_flags :: proc(entity : Entity_Handle, flags : Entity_Flag_Set) -> ^Entity {
    using entity_registry
    assert(entity_registry_initialized() && entity_valid(entity))
    data := entity_data(entity)
    data.flags += flags
    return data
}

entity_remove_flags :: proc(entity : Entity_Handle, flags : Entity_Flag_Set) -> ^Entity {
    using entity_registry
    assert(entity_registry_initialized() && entity_valid(entity))
    data := entity_data(entity)
    data.flags -= flags
    return data
}

entity_destroy :: proc(entity : Entity_Handle) {
    using entity_registry
    assert(entity_registry_initialized() && entity_count > 0 && entity_valid(entity))
    deleted, last := sparse_remove(&sparse_set, entity.id)
    entities[deleted] = entities[last]
    queue_push(&entity_ids, entity.id)
    entity_count -= 1
}