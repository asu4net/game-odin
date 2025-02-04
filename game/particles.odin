package game
import "core:fmt"
import "core:math/rand"
import "core:math/linalg"
import "core:math"
import "core:strings"
import "core:container/queue"

PARTICLE_ID    :: u32

/////////////////////////////
//:Particle
/////////////////////////////

NIL_PARTICLE_ID :: SPARSE_SET_INVALID


Particle_Handle :: struct {
    id : PARTICLE_ID    
}

Particle :: struct {
    id            : PARTICLE_ID,
    using transform     : Transform,
    using sprite       : Sprite_Atlas_Item,
    velocity           : v3,
    color              : v4,
    life               : f32,
    total_life         : f32
}

DEFAULT_PARTICLE : Particle : {
    id          = NIL_PARTICLE_ID,
    transform    = DEFAULT_TRANSFORM,
    sprite      = DEFAULT_SPRITE_ATLAS_ITEM,
    velocity    = PARTICLE_VELOCITY,
    color       = PARTICLE_COLOR,    
    life        = PARTICLE_LIFETIME,
    total_life  = PARTICLE_LIFETIME
}

/////////////////////////////
//:Particle Emitter 
/////////////////////////////

EMITTER_ID    :: u32

NIL_EMITTER_ID :: SPARSE_SET_INVALID

Emitter_Handle :: struct {
    id : EMITTER_ID    
}

ParticleEmitter :: struct {
    id               : EMITTER_ID,
    using transform  : Transform,
    pos_amplitude    : v3,
    num_textures     : u8,
    texture_names    : [MAX_SPRITES_PER_EMITTER]Texture_Name,
    velocity         : v3,
    vel_amplitude    : v3,
    color            : v4,
    color_amplitude  : v4,
    starting_life    : f32,        
    cooldown         : f32,
    current_cooldown : f32,
    active           : bool,
}

DEFAULT_EMITTER : ParticleEmitter : {
    id               = NIL_EMITTER_ID,
    transform        = DEFAULT_TRANSFORM,
    pos_amplitude    = v3{0.1, 0.1, 0},
    num_textures     = 0,
    texture_names    = DEFAULT_PARTICLE_SPRITE,
    velocity         = PARTICLE_VELOCITY,
    vel_amplitude    = V3_ONE,
    color            = PARTICLE_COLOR,
    color_amplitude  = v4{0.5, 0.5, 0.5, 0.0},
    starting_life    = PARTICLE_LIFETIME,        
    cooldown         = PARTICLE_SPAWN_TIME,
    current_cooldown = PARTICLE_SPAWN_TIME,
}

/////////////////////////////
//:Particle Registry
/////////////////////////////

Particle_Group :: [dynamic]Particle_Handle
Emitter_Group :: [dynamic]Emitter_Handle

Particle_Registry :: struct {
    particles            : [] Particle,
    particle_group       : Particle_Group,
    particle_sparse_set  : Sparse_Set,
    particle_ids         : queue.Queue(u32),
    particle_count       : u32,
    emitters             : [] ParticleEmitter,
    emitter_group        : Emitter_Group,
    emitter_sparse_set   : Sparse_Set,
    emitter_ids          : queue.Queue(u32),
    emitter_count        : u32,
    initialized          : bool,
}

@(private = "file")
particle_registry_instance : ^Particle_Registry = nil

particle_registry_initialized :: proc() -> bool {
    using particle_registry_instance
    return particle_registry_instance != nil && initialized
}

particle_registry_init :: proc(instance : ^Particle_Registry) {
    assert(!particle_registry_initialized())
    assert(instance != nil)
    particle_registry_instance = instance
    using particle_registry_instance
    
    particles = make([]Particle, MAX_PARTICLES)
    sparse_init(&particle_sparse_set, MAX_PARTICLES)
    queue.init(&particle_ids, MAX_PARTICLES)
    for i in 0..<MAX_PARTICLES {
        queue.push_back(&particle_ids, u32(i))
    }
    
    emitters = make([]ParticleEmitter, MAX_EMITTERS)
    sparse_init(&emitter_sparse_set, MAX_EMITTERS)
    queue.init(&emitter_ids, MAX_EMITTERS)
    for i in 0..<MAX_EMITTERS {
        queue.push_back(&emitter_ids, u32(i))
    }

    initialized = true
}

particle_registry_finish :: proc() {
    using particle_registry_instance
    assert(particle_registry_initialized())
    
    when ODIN_DEBUG { 
        fmt.printf("Size of particles: %i \n", len(particle_group))
    }
    delete(particles)
    delete(particle_group)
    sparse_finish(&particle_sparse_set)
    queue.destroy(&particle_ids)
    
    delete(emitters)
    delete(emitter_group)
    sparse_finish(&emitter_sparse_set)
    queue.destroy(&emitter_ids)

    particle_registry_instance^ = {}
}

particle_exists :: proc(particle : Particle_Handle) -> bool {
    using particle_registry_instance
    assert(particle_registry_initialized())
    return sparse_test(&particle_sparse_set, particle.id)
}

particle_add_to_groups :: proc(data : ^Particle) {
    using particle_registry_instance
    assert(particle_registry_initialized() && data != nil)    
    
    particle : Particle_Handle = { data.id }
    append_elem(&particle_group, particle)
}

particle_create :: proc() -> (particle : Particle_Handle, data : ^Particle) {
    using particle_registry_instance
    assert(particle_registry_initialized() && particle_count <= MAX_PARTICLES)
    particle = { queue.front(&particle_ids) }
    queue.pop_front(&particle_ids)
    index := sparse_insert(&particle_sparse_set, particle.id)
    data = &particles[index]
    data^ = DEFAULT_PARTICLE
    data.id = particle.id
    particle_add_to_groups(data)

    particle_count += 1
    
    when ODIN_DEBUG { 
        if (DEBUG_PRINT_CREATED_ENTITIES) {
            fmt.printf("Created particle. Id[%v] \n", data.id)
        }
    }

    return
}

particle_data :: proc(particle : Particle_Handle) -> ^Particle {
    using particle_registry_instance
    assert(particle_registry_initialized())
    assert(particle_exists(particle), "Trying to access unexisting particle")
    index := sparse_search(&particle_sparse_set, particle.id)
    return &particles[index]
}

particle_destroy :: proc(particle : Particle_Handle) {
    using particle_registry_instance

    assert(particle_registry_initialized() && particle_count > 0)
    assert(particle_exists(particle))

    data := particle_data(particle)

    rm_idx := -1
    // find the particle and remove it from the group
    for i in 0..<len(particle_group) {
        handle := particle_group[i]
        if handle.id == data.id {
            rm_idx = i
            break
        }
    }
    if rm_idx >= 0 {
        unordered_remove(&particle_group, rm_idx)
    }

    queue.push(&particle_ids, data.id)
    when ODIN_DEBUG {
        if (DEBUG_PRINT_DESTROYED_ENTITIES) {
            fmt.printf("Destroyed particle. Id[%v] \n", data.id)
        }
    }
    deleted, last := sparse_remove(&particle_sparse_set, data.id)
    particle_count -= 1

    if deleted != last {
        particles[deleted] = particles[last]
    }
}

particle_get_group :: proc() -> Particle_Group {

    using particle_registry_instance
    assert(particle_registry_initialized())
    return particle_group;
}

emitter_exists :: proc(emitter : Emitter_Handle) -> bool {
    using particle_registry_instance
    assert(particle_registry_initialized())
    return sparse_test(&emitter_sparse_set, emitter.id)
}

emitter_add_to_groups :: proc(data : ^ParticleEmitter) {
    using particle_registry_instance
    assert(particle_registry_initialized() && data != nil)    
    
    emitter : Emitter_Handle = { data.id }
    append_elem(&emitter_group, emitter)
}

emitter_create :: proc() -> (emitter : Emitter_Handle, data : ^ParticleEmitter) {
    using particle_registry_instance
    assert(particle_registry_initialized() && emitter_count <= MAX_EMITTERS)
    emitter = { queue.front(&emitter_ids) }
    queue.pop_front(&emitter_ids)
    index := sparse_insert(&emitter_sparse_set, emitter.id)
    data = &emitters[index]
    data^ = DEFAULT_EMITTER
    data.id = emitter.id
    emitter_add_to_groups(data)

    emitter_count += 1
    
    when ODIN_DEBUG { 
        if (DEBUG_PRINT_CREATED_ENTITIES) {
            fmt.printf("Created particle emitter. Id[%v] \n", data.id)
        }
    }

    return
}

emitter_data :: proc(emitter : Emitter_Handle) -> ^ParticleEmitter {
    using particle_registry_instance
    assert(particle_registry_initialized())
    assert(emitter_exists(emitter), "Trying to access unexisting emitter")
    index := sparse_search(&emitter_sparse_set, emitter.id)
    return &emitters[index]
}

emitter_destroy :: proc(emitter : Emitter_Handle) {
    using particle_registry_instance

    assert(particle_registry_initialized() && emitter_count > 0)
    assert(emitter_exists(emitter))

    data := emitter_data(emitter)

    rm_idx := -1
    // find the emitter and remove it from the group
    for i in 0..<len(emitter_group) {
        handle := emitter_group[i]
        if handle.id == data.id {
            rm_idx = i
            break
        }
    }
    if rm_idx >= 0 {
        unordered_remove(&emitter_group, rm_idx)
    }

    queue.push(&emitter_ids, data.id)
    when ODIN_DEBUG {
        if (DEBUG_PRINT_DESTROYED_ENTITIES) {
            fmt.printf("Destroyed emitter. Id[%v] \n", data.id)
        }
    }
    deleted, last := sparse_remove(&emitter_sparse_set, data.id)
    emitter_count -= 1

    if deleted != last {
        emitters[deleted] = emitters[last]
    }
}

emitter_get_group :: proc() -> Emitter_Group {

    using particle_registry_instance
    assert(particle_registry_initialized())
    return emitter_group;
}

emitter_add_texture :: proc(emitter : Emitter_Handle, texture_name : Texture_Name) {
    
    using particle_registry_instance

    assert(particle_registry_initialized() && emitter_count > 0)
    assert(emitter_exists(emitter))

    data := emitter_data(emitter)

    assert(data.num_textures < MAX_SPRITES_PER_EMITTER, "Emitter texture_names array overflow. Increase MAX_SPRITES_PER_EMITTER if needed")

    data.texture_names[data.num_textures] = texture_name
    data.num_textures += 1

}

emitter_remove_last_texture :: proc(emitter : Emitter_Handle) {

    using particle_registry_instance

    assert(particle_registry_initialized() && emitter_count > 0)
    assert(emitter_exists(emitter))

    data := emitter_data(emitter)
    if(data.num_textures > 1) { 
        // haha
        data.num_textures -= 1
    }
}

spawn_particle :: proc(emitter : ^ParticleEmitter) {

    particle : Particle_Handle
    {
        // Generate numbers between -1.0 and 1.0
        random := v3{ (rand.float32() - 0.5) * 2, (rand.float32() - 0.5) * 2, 0 }  
        random_color := v4{ (rand.float32() - 0.5) * 2, (rand.float32() - 0.5) * 2, (rand.float32() - 0.5) * 2, 0 }  
        random_sprite := rand.uint32()
        
        handle, data := particle_create()
        particle = handle
        data.sprite.item = emitter.num_textures > 1 ? rand.choice(emitter.texture_names[0:emitter.num_textures]) : emitter.texture_names[0];
        data.position = emitter.position + random * emitter.pos_amplitude;
        data.velocity = emitter.velocity + random * emitter.vel_amplitude;
        data.color = emitter.color + random_color * emitter.color_amplitude;
        data.life = emitter.starting_life;
        data.total_life = emitter.starting_life;
    }
}

particle_update :: proc() {
    
    assert(particle_registry_instance != nil)
    using particle_registry_instance

    for emitter in emitter_group {
        
        if !emitter_exists(emitter)  {
            continue
        }
        data := emitter_data(emitter)
        if(!data.active) { 
            continue
        }
        
        data.current_cooldown -= delta_seconds();
        if(data.current_cooldown <= 0){
            data.current_cooldown = data.cooldown;
            spawn_particle(data);
        }
    }
    
    for particle in particle_group {
        
        if !particle_exists(particle) {
            continue
        }
        data := particle_data(particle)
        
        data.life = data.life - delta_seconds();
        if(data.life >= 0) {
            data.position = data.position + data.velocity * delta_seconds();
            alpha := data.life / data.total_life;
            data.color.w = alpha;
        } else { 
            particle_destroy(particle)
            
        }
    }
}
