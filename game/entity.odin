package game
import "core:strings"
import "core:fmt"
import "core:container/queue"

ENTITY_ID    :: u32

Entity_Flag :: enum {
    // Engine stuff
    VALID,
    ENABLED,
    VISIBLE,
    SPRITE,
    CIRCLE,
    COLLIDER_2D,
    BLINK,
    MOVEMENT_2D,

    // Gameplay stuff
    PROJECTILE,
    PLAYER,
    ENEMY,
    KAMIKAZE,
    KAMIKAZE_SAW,
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
    flags = { .VALID, .ENABLED, .VISIBLE },
    id    = NIL_ENTITY_ID,
    tint  = V4_COLOR_WHITE
}

Entity :: struct {
    using common       : EntityCommon,
    using tranform     : Transform,
    using sprite       : Sprite_Atlas_Item,
    using circle       : Circle,
    using collider     : Collider2D,
    blink              : Blink,
    movement_2d        : Movement2D,
    particle_emitter   : Emitter_Handle,
    
    // Game specific
    projectile         : Projectile,
    kamikaze           : KamikazeSkull,
    kamikaze_saw       : KamikazeSaw,
}

NIL_ENTITY_ID :: SPARSE_SET_INVALID

DEFAULT_ENTITY : Entity : {
    common           = DEFAULT_ENTITY_COMMON,
    tranform         = DEFAULT_TRANSFORM,
    sprite           = DEFAULT_SPRITE_ATLAS_ITEM,
    circle           = DEFAULT_CIRCLE,
    collider         = DEFAULT_COLLIDER_2D,
    blink            = DEFAULT_BLINK,
    movement_2d      = DEFAULT_MOVEMENT_2D,
    particle_emitter = {NIL_EMITTER_ID},
    projectile       = DEFAULT_PROJECTILE,
    kamikaze         = DEFAULT_KAMIKAZE_SKULL,
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
    entities             : [] Entity,
    sparse_set           : Sparse_Set,
    entity_ids           : queue.Queue(u32),
    entity_count         : u32,
    entity_groups        : Entity_Group_Map, 
    initialized          : bool,
    pending_destroy      : map[Entity_Handle]struct{},
    frames_since_cleaned : u32
}

@(private = "file")
entity_registry_instance : ^Entity_Registry = nil

entity_registry_initialized :: proc() -> bool {
    using entity_registry_instance
    return entity_registry_instance != nil && initialized
}

entity_registry_init :: proc(instance : ^Entity_Registry) {
    assert(!entity_registry_initialized())
    assert(instance != nil)
    entity_registry_instance = instance
    using entity_registry_instance
    
    entities = make([]Entity, MAX_ENTITIES)
    sparse_init(&sparse_set, MAX_ENTITIES)
    queue.init(&entity_ids, MAX_ENTITIES)
    for i in 0..<MAX_ENTITIES {
        queue.push_back(&entity_ids, u32(i))
    }
    initialized = true
}

entity_registry_finish :: proc() {
    using entity_registry_instance
    assert(entity_registry_initialized())
    delete(entities)
    for _, group in entity_groups {
        delete(group)
    }
    delete(entity_groups)
    delete_map(pending_destroy)
    sparse_finish(&sparse_set)
    queue.destroy(&entity_ids)
    entity_registry_instance^ = {}
}

entity_valid :: proc(entity : Entity_Handle) -> bool {
    using entity_registry_instance
    assert(entity_registry_initialized())
    assert(entity_exists(entity))
    return .VALID in entity_data(entity).flags 
}

entity_exists :: proc(entity : Entity_Handle) -> bool {
    using entity_registry_instance
    assert(entity_registry_initialized())
    return sparse_test(&sparse_set, entity.id)
}

entity_create :: proc(name : string = "", flags : Entity_Flag_Set = {}) -> (entity : Entity_Handle, data : ^Entity) {
    using entity_registry_instance
    assert(entity_registry_initialized() && entity_count <= MAX_ENTITIES)
    entity = { queue.front(&entity_ids) }
    queue.pop_front(&entity_ids)
    index := sparse_insert(&sparse_set, entity.id)
    data = &entities[index]
    data^ = DEFAULT_ENTITY
    data.id = entity.id
    data.name = len(name) == 0 ? "Entity" : name

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
    
    when ODIN_DEBUG { 
        if (DEBUG_PRINT_CREATED_ENTITIES) {
            fmt.printf("Created entity. Name[%v], Id[%v] \n", data.name, data.id)
        }
    }

    return    
}

entity_data :: proc(entity : Entity_Handle) -> ^Entity {
    using entity_registry_instance
    assert(entity_registry_initialized())
    assert(entity_exists(entity), "Trying to access unexisting entity")
    index := sparse_search(&sparse_set, entity.id)
    return &entities[index]
}

@(private = "file")
entity_remove_from_groups :: proc(data : ^Entity) {
    using entity_registry_instance
    assert(entity_registry_initialized() && data != nil)    
    for group_flags, &group in entity_groups {
        if group_flags - data.flags != nil {
            rm_idx := -1
            // find the entity and remove it from the group
            for i in 0..<len(group) {
                entity := group[i]
                if entity.id == data.id {
                    rm_idx = i
                    break
                }
            }
            if rm_idx >= 0 {
                unordered_remove(&group, rm_idx)
            }
        }
    }
}

@(private = "file")
entity_remove_from_all_groups :: proc(data : ^Entity) {
    using entity_registry_instance
    assert(entity_registry_initialized() && data != nil)    
    for group_flags, &group in entity_groups {
        rm_idx := -1
        // find the entity and remove it from the group
        for i in 0..<len(group) {
            entity := group[i]
            if entity.id == data.id {
                rm_idx = i
                break
            }
        }
        if rm_idx >= 0 {
            unordered_remove(&group, rm_idx)
        }
    }
}

@(private = "file")
entity_add_to_groups :: proc(data : ^Entity) {
    using entity_registry_instance
    assert(entity_registry_initialized() && data != nil)    
    for group_flags, &group in entity_groups {
        if group_flags - data.flags == nil {
            entity : Entity_Handle = { data.id }
            append_elem(&group, entity)
        }
    }
}

entity_add_flags :: proc(entity : Entity_Handle, flags : Entity_Flag_Set) -> (data : ^Entity) {
    using entity_registry_instance
    assert(entity_registry_initialized())
    assert(entity_exists(entity))
    data = entity_data(entity)
    data.flags += flags
    entity_add_to_groups(data)
    return
}

entity_remove_flags :: proc(entity : Entity_Handle, flags : Entity_Flag_Set) -> (data : ^Entity) {
    using entity_registry_instance
    assert(entity_registry_initialized())
    assert(entity_exists(entity))
    data = entity_data(entity)
    data.flags -= flags
    entity_remove_from_groups(data)
    return
}

entity_destroy :: proc(entity : Entity_Handle) {
    using entity_registry_instance

    assert(entity_registry_initialized() && entity_count > 0)
    assert(entity_exists(entity))

    data := entity_data(entity)
    entity_remove_flags(entity, { .VALID })

    if(emitter_exists(data.particle_emitter)) {
        emitter := emitter_data(data.particle_emitter)
        emitter.active = false;
    }

    pending_destroy[entity] = {}
}

clean_destroyed_entities :: proc() {

    assert(entity_registry_initialized());
    using entity_registry_instance

    if frames_since_cleaned < ENTITY_CLEANUP_INTERVAL {
        frames_since_cleaned += 1
        return 
    }

    frames_since_cleaned = 0

    for handle, _ in pending_destroy {

        data := entity_data(handle)
        
        if(emitter_exists(data.particle_emitter)) {
            emitter_destroy(data.particle_emitter)
        }
        
        queue.push(&entity_ids, data.id)

        when ODIN_DEBUG {
            if (DEBUG_PRINT_DESTROYED_ENTITIES) {
                fmt.printf("Destroyed entity. Name[%v], Id[%v] \n", data.name, data.id)
            }
        }

        entity_remove_from_all_groups(data)
        deleted, last := sparse_remove(&sparse_set, data.id)
        entity_count -= 1

        if deleted != last {
            entities[deleted] = entities[last]
        }
    }

    clear(&pending_destroy)
}

entity_get_group :: proc(flags : Entity_Flag_Set) -> Entity_Group {

    using entity_registry_instance
    assert(entity_registry_initialized() && flags in entity_groups)
    return entity_groups[flags];
}

entity_create_group :: proc(flags : Entity_Flag_Set) -> (group : Entity_Group) {
    using entity_registry_instance
    assert(entity_registry_initialized() && entity_count == 0)
    if flags in entity_groups {
        return entity_get_group(flags)
    }
    group = make(Entity_Group)
    entity_registry_instance.entity_groups[flags] = group
    return
}

entity_print_groups :: proc() {
    using entity_registry_instance
    assert(entity_registry_initialized())
    fmt.println(entity_groups)
}