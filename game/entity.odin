package game
import "core:strings"
import "core:fmt"

ENTITY_ID    :: u32

Entity_Flag :: enum {
    // Engine stuff
    ENABLED,
    VISIBLE,
    SPRITE,
    CIRCLE,
    COLLIDER,

    // Gameplay stuff
    PROJECTILE,
    PLAYER,
    ENEMY,
    SAW,
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
    using common     : EntityCommon,
    using tranform   : Transform,
    using sprite     : Sprite,
    using circle     : Circle,
    using collider   : Collider,
    using projectile : Projectile,
}

NIL_ENTITY_ID :: SPARSE_SET_INVALID

DEFAULT_ENTITY : Entity : {
    common      = DEFAULT_ENTITY_COMMON,
    tranform    = DEFAULT_TRANSFORM,
    sprite      = DEFAULT_SPRITE,
    circle      = DEFAULT_CIRCLE,
    collider    = DEFAULT_COLLIDER,
    projectile  = DEFAULT_PROJECTILE,
}

Entity_Handle :: struct {
    id : ENTITY_ID    
}

/////////////////////////////
//:Entity Registry
/////////////////////////////

Entity_Group :: [dynamic]Entity_Handle
Entity_Group_Map :: map[Entity_Flag_Set] Entity_Group

Entity_Registry :: struct {
    entities      : [] Entity,
    sparse_set    : Sparse_Set,
    entity_ids    : Queue,
    entity_count  : u32,
    entity_groups : Entity_Group_Map, 
    initialized   : bool,
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
    return initialized
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
    initialized = true
}

entity_registry_finish :: proc() {
    using entity_registry
    assert(entity_registry_initialized())
    delete(entities)
    for _, group in entity_groups {
        delete(group)
    }
    delete(entity_groups)
    sparse_finish(&sparse_set)
    queue_finish(&entity_ids)
    entity_registry^ = {}
}

entity_valid :: proc(entity : Entity_Handle) -> bool {
    using entity_registry
    assert(entity_registry_initialized())
    return sparse_test(&sparse_set, entity.id)
}

entity_create :: proc(name : string = "", flags : Entity_Flag_Set = {}) -> (entity : Entity_Handle, data : ^Entity) {
    using entity_registry
    assert(entity_registry_initialized() && entity_count <= MAX_ENTITIES)
    entity = { queue_front(&entity_ids) }
    queue_pop(&entity_ids)
    index := sparse_insert(&sparse_set, entity.id)
    data = &entities[index]
    data^ = DEFAULT_ENTITY
    data.id = entity.id
    data.name = "Entity"
    /*if len(data.name) == 0 {
        builder : strings.Builder
        strings.builder_init(&builder)
        defer strings.builder_destroy(&builder)
        strings.write_string(&builder, "Entity ")
        strings.write_uint(&builder, uint(entity.id))
        data.name = strings.clone(strings.to_string(builder)) // this makes an allocation    
    }*/

    entity_add_flags(entity, flags)
    entity_count += 1

    if (DEBUG_PRINT_CREATED_ENTITIES) {
        fmt.printf("Created entity. Name[%v], Id[%v] \n", data.name, data.id)
    }

    return    
}

entity_data :: proc(entity : Entity_Handle) -> ^Entity {
    using entity_registry
    
    assert(entity_registry_initialized())

    if (!entity_valid(entity)) {
        fmt.printf("Trying to access invalid entity id[%v] \n", entity)
        for elem in entity_groups[{.CIRCLE}] {
            fmt.printf("%v \n", elem)    
        }
        assert(false)
    }

    index := sparse_search(&sparse_set, entity.id)
    return &entities[index]
}

@(private = "file")
Entity_Group_Op :: enum { ADD, REMOVE }

@(private = "file")
entity_group_op :: proc(data : ^Entity, op : Entity_Group_Op) {
    using entity_registry
    assert(entity_registry_initialized() && data != nil)    
    for group_flags, &group in entity_groups {
        if data.flags & group_flags != nil {
            if op == .ADD {
                // add the element to the group
                entity : Entity_Handle = { data.id }
                append_elem(&group, entity)
            } else {
                rm_idx := -1
                // find the entity and remove it from the group
                for i in 0..<len(group) {
                    entity := group[i]
                    if entity.id == data.id {
                        rm_idx = i
                        break
                    }
                }
                if (rm_idx < 0) {
                    fmt.println(entity_groups)    
                    assert(false)
                }
                unordered_remove(&group, rm_idx)
            }
        }
    }
}

entity_add_flags :: proc(entity : Entity_Handle, flags : Entity_Flag_Set) -> (data : ^Entity) {
    using entity_registry
    assert(entity_registry_initialized() && entity_valid(entity))
    data = entity_data(entity)
    data.flags += flags
    entity_group_op(data, .ADD)
    return
}

entity_remove_flags :: proc(entity : Entity_Handle, flags : Entity_Flag_Set) -> (data : ^Entity) {
    using entity_registry
    assert(entity_registry_initialized() && entity_valid(entity))
    data = entity_data(entity)
    entity_group_op(data, .REMOVE)
    data.flags -= flags
    return
}

entity_destroy :: proc(entity : Entity_Handle) {
    using entity_registry
    assert(entity_registry_initialized() && entity_count > 0 && entity_valid(entity))
    data := entity_data(entity)
    queue_push(&entity_ids, entity.id)

    if (DEBUG_PRINT_DESTROYED_ENTITIES) {
        fmt.printf("Destroyed entity. Name[%v], Id[%v] \n", data.name, data.id)
    }
    
    entity_group_op(data, .REMOVE)
    deleted, last := sparse_remove(&sparse_set, entity.id)
    entities[deleted] = entities[last]
    entity_count -= 1
}

entity_get_group :: proc(flags : Entity_Flag_Set) -> Entity_Group {
    using entity_registry
    assert(entity_registry_initialized() && flags in entity_groups)
    return entity_groups[flags];
}

entity_create_group :: proc(flags : Entity_Flag_Set) -> (group : Entity_Group) {
    using entity_registry
    assert(entity_registry_initialized() && entity_count == 0)
    if flags in entity_groups {
        return entity_get_group(flags)
    }
    group = make(Entity_Group)
    entity_registry.entity_groups[flags] = group
    return
}