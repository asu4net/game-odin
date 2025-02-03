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
    using tranform     : Transform,
    using sprite       : Sprite_Atlas_Item,
    velocity           : v3,
    color              : v4,
    life               : f32
}

DEFAULT_PARTICLE : Particle : {
    tranform    = DEFAULT_TRANSFORM,
    sprite      = DEFAULT_SPRITE_ATLAS_ITEM,
    velocity    = PARTICLE_VELOCITY,
    color       = PARTICLE_COLOR,    
    life        = PARTICLE_LIFETIME
}

/////////////////////////////
//:Particle Manager 
/////////////////////////////


ParticleManager :: struct {
    cooldown      : f32,
}

/////////////////////////////
//:Particle Registry
/////////////////////////////

Particle_Group :: [dynamic]Particle_Handle

Particle_Registry :: struct {
    particles            : [] Particle,
    particle_group       : Particle_Group,
    sparse_set           : Sparse_Set,
    particle_ids         : queue.Queue(u32),
    particle_count       : u32,
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
    sparse_init(&sparse_set, MAX_PARTICLES)
    queue.init(&particle_ids, MAX_PARTICLES)
    for i in 0..<MAX_PARTICLES {
        queue.push_back(&particle_ids, u32(i))
    }
    initialized = true
}

particle_registry_finish :: proc() {
    using particle_registry_instance
    assert(particle_registry_initialized())
    
    fmt.printf("Size of particles: %i \n", len(particle_group))
    delete(particles)
    delete(particle_group)
    sparse_finish(&sparse_set)
    queue.destroy(&particle_ids)
    particle_registry_instance^ = {}
}

particle_exists :: proc(particle : Particle_Handle) -> bool {
    using particle_registry_instance
    assert(particle_registry_initialized())
    return sparse_test(&sparse_set, particle.id)
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
    index := sparse_insert(&sparse_set, particle.id)
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
    index := sparse_search(&sparse_set, particle.id)
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
    deleted, last := sparse_remove(&sparse_set, data.id)
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

@(private = "file")
particle_manager_instance : ^ParticleManager = nil

spawn_particle :: proc(pos := V3_ZERO, velocity : v3 = { 1, 1, 0 }) {

    using particle_manager_instance

    particle : Particle_Handle
    {
        handle, data := particle_create()
        particle = handle
        data.sprite.item = .Kamikaze_Skull
        data.position = pos
        data.velocity = velocity
    }
}

particle_manager_init :: proc(instance : ^ParticleManager) {
    assert(particle_manager_instance == nil)
    particle_manager_instance = instance
    using particle_manager_instance
    
    // uuuuuuuuuuuuuuh
    cooldown = PARTICLE_SPAWN_TIME;
}

particle_manager_update :: proc() {
    
    assert(particle_registry_instance != nil)
    using particle_registry_instance
    assert(particle_manager_instance != nil)
    using particle_manager_instance

    cooldown = cooldown - delta_seconds();
    if(cooldown <= 0){
        cooldown = PARTICLE_SPAWN_TIME;
        random_x := (rand.float32() - 0.5) / 10;
        random_y := (rand.float32() - 0.5) / 10;
        rColor := 0.5 + ((rand.float32() * 100) / 100.0);
        player_pos := entity_data(game.player.entity).position
        spawn_particle(player_pos + v3{random_x, random_y, 0}, v3{random_x * 10, -(random_y + 0.05) * 30, 0.0});
    }
    
    for particle in particle_group {
        
        if !particle_exists(particle) {
            continue
        }
        data := particle_data(particle)
        
        data.life = data.life - delta_seconds();
        if(data.life >= 0) {
            data.position = data.position + data.velocity * delta_seconds();
            data.color.w = data.color.w - delta_seconds();
        } else { 
            particle_destroy(particle)
            
        }
    }
}
