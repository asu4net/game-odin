package game
import "core:strings"
import "core:fmt"
import "core:container/queue"
import "engine:global/color"
import "engine:global/sparse_set"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//:Entity flags
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Entity_Flag :: enum {
    // Engine stuff
    VALID,
    ENABLED,
    VISIBLE,
    SPRITE,
    FLIPBOOK,
    CIRCLE,
    COLLIDER_2D,
    BLINK,
    MOVEMENT_2D,
    DAMAGE_SOURCE,
    DAMAGE_TARGET,

    // Gameplay stuff
    PROJECTILE,
    PLAYER,
    ENEMY,
    KAMIKAZE,
    KAMIKAZE_SAW,
    HOMING_MISSILE,
}

GROUP_FLAGS_SPRITE : Entity_Flag_Set : {
    .VALID,
    .ENABLED,
    .VISIBLE,
    .SPRITE,
}

GROUP_FLAGS_CIRCLE : Entity_Flag_Set : {
    .VALID,
    .ENABLED,
    .VISIBLE,
    .CIRCLE,
}

GROUP_FLAGS_COLLIDER_2D : Entity_Flag_Set : {
    .VALID,
    .ENABLED,
    .VISIBLE,
    .COLLIDER_2D,
}

GROUP_FLAGS_KAMIKAZE : Entity_Flag_Set : {
    .VALID,
    .ENABLED,
    .SPRITE,
    .COLLIDER_2D,
    .KAMIKAZE,
    .MOVEMENT_2D,
    .DAMAGE_TARGET,
    .DAMAGE_SOURCE,
}

GROUP_FLAGS_HOMING_MISSILE : Entity_Flag_Set : {
    .VALID,
    .ENABLED,
    .SPRITE,
    .COLLIDER_2D,
    .HOMING_MISSILE,
    .MOVEMENT_2D,
    .DAMAGE_TARGET,
    .DAMAGE_SOURCE,
}

GROUP_FLAGS_MOVEMENT_2D : Entity_Flag_Set : {
    .VALID,
    .ENABLED,
    .MOVEMENT_2D,
}

GROUP_FLAGS_KAMIKAZE_SAW : Entity_Flag_Set : {
    .VALID,
    .ENABLED,
    .SPRITE,
    .KAMIKAZE_SAW,
}

GROUP_FLAGS_PROJECTILE : Entity_Flag_Set : {
    .VALID,
    .ENABLED,
    .COLLIDER_2D,
    .PROJECTILE,
    .DAMAGE_SOURCE,
    .DAMAGE_TARGET
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//:Entity
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

ENTITY_ID    :: u32

Entity_Flag_Set :: bit_set[Entity_Flag]

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
    tint  = color.WHITE
}

Entity :: struct {
    using common       : EntityCommon,
    using transform    : Transform,
    using sprite       : Sprite_Atlas_Item,
    using circle       : Circle,
    using collider     : Collider2D,
    blink              : Blink,
    flipbook           : FlipBook,
    movement_2d        : Movement2D,
    particle_emitter   : Emitter_Handle,
    damage_source      : DamageSource,
    damage_target      : DamageTarget,

    // Game specific
    projectile         : Projectile,
    kamikaze           : KamikazeSkull,
    kamikaze_saw       : KamikazeSaw,
    homing_missile     : HomingMissile,
}

NIL_ENTITY_ID :: sparse_set.INVALID_VALUE

DEFAULT_ENTITY : Entity : {
    common           = DEFAULT_ENTITY_COMMON,
    transform        = DEFAULT_TRANSFORM,
    sprite           = DEFAULT_SPRITE_ATLAS_ITEM,
    circle           = DEFAULT_CIRCLE,
    collider         = DEFAULT_COLLIDER_2D,
    blink            = DEFAULT_BLINK,
    movement_2d      = DEFAULT_MOVEMENT_2D,
    particle_emitter = {NIL_EMITTER_ID},
    projectile       = DEFAULT_PROJECTILE,
    kamikaze         = DEFAULT_KAMIKAZE_SKULL,
    homing_missile   = DEFAULT_HOMING_MISSILE,
    damage_source    = DEFAULT_DAMAGE_SOURCE,
    damage_target    = DEFAULT_DAMAGE_TARGET
}

Entity_Handle :: struct {
    id : ENTITY_ID    
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//:Entity Registry
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Entity_Group :: [dynamic]Entity_Handle
Entity_Group_Map :: map[Entity_Flag_Set] Entity_Group

Entity_Registry :: struct {
    entities             : [] Entity,
    entity_used_ids      : sparse_set.Sparse_Set,
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
    sparse_set.init(&entity_used_ids, MAX_ENTITIES)
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
    sparse_set.finish(&entity_used_ids)
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
    return sparse_set.test(&entity_used_ids, entity.id)
}

entity_create :: proc(name : string = "", flags : Entity_Flag_Set = {}) -> (handle : Entity_Handle, entity : ^Entity) {
    using entity_registry_instance
    assert(entity_registry_initialized() && entity_count <= MAX_ENTITIES)
    handle = { queue.front(&entity_ids) }
    queue.pop_front(&entity_ids)
    index := sparse_set.insert(&entity_used_ids, handle.id)
    entity = &entities[index]
    entity^ = DEFAULT_ENTITY
    entity.id = handle.id
    entity.name = len(name) == 0 ? "Entity" : name

    /*if len(data.name) == 0 {
        builder : strings.Builder
        strings.builder_init(&builder)
        defer strings.builder_destroy(&builder)
        strings.write_string(&builder, "Entity ")
        strings.write_uint(&builder, uint(entity.id))
        data.name = strings.clone(strings.to_string(builder)) // this makes an allocation    
    }*/

    entity_add_flags(handle, flags)
    entity_count += 1
    
    when ODIN_DEBUG { 
        if (DEBUG_PRINT_CREATED_ENTITIES) {
            fmt.printf("Created entity. Name[%v], Id[%v] \n", entity.name, entity.id)
        }
    }

    return    
}

entity_clone :: proc(template : Entity_Handle) -> (handle : Entity_Handle, entity : ^Entity) {
    assert(entity_valid(template))
    
    template_entity := entity_data(template)
    handle, entity = entity_create(template_entity.name, template_entity.flags)
    entity^ = template_entity^
    entity.id = handle.id
    
    if(emitter_exists(entity.particle_emitter))
    {
        emitter_handle, emitter := emitter_clone(entity.particle_emitter);
        emitter.position = entity.position;
        entity.particle_emitter = emitter_handle;
    }

    //We need to clone the saw too
    if .KAMIKAZE in entity.flags {
        saw_handle, saw_entity := entity_clone(entity.kamikaze.saw)    
        saw_entity.position = entity.position
        entity.kamikaze.saw = saw_handle
        saw_entity.kamikaze_saw.kamikaze_skull = handle
    }

    return
}

entity_data :: proc(entity : Entity_Handle) -> ^Entity {
    using entity_registry_instance
    assert(entity_registry_initialized())
    assert(entity_exists(entity), "Trying to access unexisting entity")
    index := sparse_set.search(&entity_used_ids, entity.id)
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
        deleted, last := sparse_set.remove(&entity_used_ids, data.id)
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