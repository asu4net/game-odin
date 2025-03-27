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
    GLOBAL_ENABLED,
    VISIBLE,
    CIRCLE,
    
    // Gameplay stuff
    PLAYER,
    ENEMY,
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
    parent         : Entity_Handle,
    children       : [dynamic] Entity_Handle,
}

DEFAULT_ENTITY_COMMON : EntityCommon : {
    flags  = { .VALID, .GLOBAL_ENABLED, .ENABLED, .VISIBLE },
    id     = NIL_ENTITY_ID,
    tint   = color.WHITE,
    parent = { NIL_ENTITY_ID },
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
    homing_missile     : HomingMissile,
    pointer_line       : PointerLine,
}

NIL_ENTITY_ID :: sparse_set.INVALID_VALUE

Entity_Handle :: struct {
    id : ENTITY_ID    
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//:Entity Registry
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Entity_Registry :: struct {
    entities             : [] Entity,
    entity_used_ids      : sparse_set.Sparse_Set,
    entity_ids           : queue.Queue(u32),
    entity_count         : u32,
    initialized          : bool,
    pending_destroy      : map[Entity_Handle]struct{},
    frames_since_cleaned : u32
}

@(private = "file")
state : ^Entity_Registry = nil

entity_count :: proc() -> u32 {
    assert(entity_registry_initialized());
    return state.entity_count;
}

entity_at_index :: proc(index : u32) -> ^Entity  {
    assert(entity_registry_initialized());
    assert(index < state.entity_count);
    return &state.entities[index];
}

entity_registry_initialized :: proc() -> bool {
    using state
    return state != nil && initialized
}

entity_registry_init :: proc(instance : ^Entity_Registry) {
    assert(!entity_registry_initialized())
    assert(instance != nil)
    state = instance
    using state
    
    entities = make([]Entity, MAX_ENTITIES)
    sparse_set.init(&entity_used_ids, MAX_ENTITIES)
    queue.init(&entity_ids, MAX_ENTITIES)
    for i in 0..<MAX_ENTITIES {
        queue.push_back(&entity_ids, u32(i))
    }
    initialized = true
}

entity_registry_finish :: proc() {
    using state
    assert(entity_registry_initialized())
    for entity in entities {
        if(entity_exists({entity.id})) {
            delete(entity.children)
        }
    }
    delete(entities)
    delete_map(pending_destroy)
    sparse_set.finish(&entity_used_ids)
    queue.destroy(&entity_ids)
    state^ = {}
}

entity_exists :: proc(entity : Entity_Handle) -> bool {
    using state
    assert(entity_registry_initialized())
    return sparse_set.test(&entity_used_ids, entity.id)
}

entity_valid :: proc(entity : Entity_Handle) -> bool {
    using state
    assert(entity_exists(entity))
    return .VALID in entity_data(entity).flags 
}

entity_enabled :: proc(entity : Entity_Handle) -> bool {
    using state;
    return entity_valid(entity) && .ENABLED in entity_data(entity).flags && .GLOBAL_ENABLED in entity_data(entity).flags;  
}

// Alex chequea este truco
entity_global_enabled :: proc(entity : Entity_Handle) -> bool {
    using state
    return entity_enabled(entity) && .GLOBAL_ENABLED in entity_data(entity).flags 
}

entity_create :: proc(name : string = "", flags : Entity_Flag_Set = {}) -> (handle : Entity_Handle, entity : ^Entity) {
    using state
    assert(entity_registry_initialized() && entity_count <= MAX_ENTITIES)
    handle = { queue.front(&entity_ids) }
    queue.pop_front(&entity_ids)
    index := sparse_set.insert(&entity_used_ids, handle.id)
    entity = &entities[index]
    entity.common = DEFAULT_ENTITY_COMMON;
    entity.transform = DEFAULT_TRANSFORM;
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
    /*
    if .KAMIKAZE in entity.flags {
        saw_handle, saw_entity := entity_clone(entity.kamikaze.saw)    
        saw_entity.position = entity.position
        entity.kamikaze.saw = saw_handle
        saw_entity.kamikaze_saw.kamikaze_skull = handle
    }
    */
    // I have a better idea watch this
    entity.children = nil;
    for child in template_entity.children {
        cloned_child, child_entity := entity_clone(child);
        entity_set_parent(cloned_child, handle);
    }

    return
}

entity_data :: proc(entity : Entity_Handle) -> ^Entity {
    using state
    assert(entity_registry_initialized())
    assert(entity_exists(entity), "Trying to access unexisting entity")
    index := sparse_set.search(&entity_used_ids, entity.id)
    return &entities[index]
}

entity_add_flags :: proc(entity : Entity_Handle, flags : Entity_Flag_Set) -> (data : ^Entity) {
    using state
    assert(entity_registry_initialized())
    assert(entity_exists(entity))
    data = entity_data(entity)
    prev_flags := data.flags;
    data.flags += flags
    
    if .ENABLED in data.flags != .ENABLED in prev_flags {
        compute_enabled_iterative(entity);
    }

    return
}

entity_remove_flags :: proc(entity : Entity_Handle, flags : Entity_Flag_Set) -> (data : ^Entity) {
    using state
    assert(entity_registry_initialized())
    assert(entity_exists(entity))
    data = entity_data(entity)
    prev_flags := data.flags;
    data.flags -= flags

    if .ENABLED in data.flags != .ENABLED in prev_flags {
        compute_enabled_iterative(entity);
    }
    return
}

entity_destroy :: proc(entity : Entity_Handle) {
    using state

    assert(entity_registry_initialized() && entity_count > 0)
    assert(entity_exists(entity))

    data := entity_data(entity)
    entity_remove_flags(entity, { .VALID })

    if(emitter_exists(data.particle_emitter)) {
        emitter := emitter_data(data.particle_emitter)
        emitter.active = false;
    }

    for child in data.children {
        entity_destroy(child);
    }

    pending_destroy[entity] = {}
}

clean_destroyed_entities :: proc() {

    assert(entity_registry_initialized());
    using state;

    if frames_since_cleaned < ENTITY_CLEANUP_INTERVAL {
        frames_since_cleaned += 1;
        return; 
    }
    
    frames_since_cleaned = 0;

    for handle, _ in pending_destroy {

        data := entity_data(handle);
        
        delete(data.children);

        if(emitter_exists(data.particle_emitter)) {
            emitter_destroy(data.particle_emitter);
        }
        
        when ODIN_DEBUG {
            if (DEBUG_PRINT_DESTROYED_ENTITIES) {
                fmt.printf("Destroyed entity. Name[%v], Id[%v] \n", data.name, data.id);
            }
        }
        
        queue.push(&entity_ids, data.id);
        deleted, last := sparse_set.remove(&entity_used_ids, data.id);
        
        entity_count -= 1;
        
        if deleted != last {
            entities[deleted] = entities[last];
            entities[last] = {};
        } else {
            entities[deleted] = {};
        }
        
    }

    clear(&pending_destroy)
}

entity_add_child :: proc(entity : Entity_Handle, child : Entity_Handle) {
    using state;
    assert(entity_registry_initialized());
    data := entity_data(entity);
    for handle in data.children {
        if handle == child { return; }
    }

    append_elem(&data.children, child);
    compute_enabled_iterative(child);
}

entity_get_children :: proc(entity : Entity_Handle) -> ([dynamic]Entity_Handle) {
    using state;
    assert(entity_registry_initialized());
    data := entity_data(entity);
    return data.children;
}

entity_remove_child :: proc(entity : Entity_Handle, child : Entity_Handle) {
    using state;
    assert(entity_registry_initialized());
    data := entity_data(entity);
    i := -1;
    found := false;
    for current_child in data.children { 
        if child == current_child { 
            found = true;
            break; 
        }
        i += 1;
    }
    if(found) { unordered_remove(&data.children, i); }
    compute_enabled_iterative(child);
}

entity_set_parent :: proc(entity : Entity_Handle, parent : Entity_Handle) {
    using state;
    assert(entity_registry_initialized());
    data := entity_data(entity);
    if entity_exists(data.parent) && entity_valid(data.parent) {
        entity_remove_child(data.parent, entity);
    }
    data.parent = parent;
    entity_add_child(parent, entity);
}

entity_get_parent :: proc(entity : Entity_Handle) -> (Entity_Handle) {
    using state;
    assert(entity_registry_initialized());
    data := entity_data(entity);
    return data.parent;
}

compute_enabled_iterative :: proc(entity : Entity_Handle) { 
    stack : [dynamic]Entity_Handle;
    append_elem(&stack, entity);

    for len(&stack) > 0 {
        current := pop(&stack);
        data := entity_data(current);
        parent := data.parent;

        parent_enabled := entity_exists(parent) && entity_valid(parent) ? entity_global_enabled(parent) : true;
        new_global_enabled := .ENABLED in data.flags && parent_enabled;
        
        if(.GLOBAL_ENABLED in data.flags != new_global_enabled) {

            for child in data.children {
                append_elem(&stack, child);
            } 
        
        }

        if new_global_enabled && !(.GLOBAL_ENABLED in data.flags) { entity_add_flags(current, { .GLOBAL_ENABLED }); } 
        else if !new_global_enabled && .GLOBAL_ENABLED in data.flags { entity_remove_flags(current, { .GLOBAL_ENABLED }); }
    
    }
    delete(stack);
}