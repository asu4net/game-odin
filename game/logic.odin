package game
import "core:math"
import "core:math/linalg"
import "core:fmt"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//:Movement 2D
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Movement2D :: struct {
    start              : bool,
    speed_min          : f32,
    speed_max          : f32,
    time_to_max_speed  : f32,
    speed_progress     : f32,
    target             : v3, 
    //TODO: add function ptr to specify interp proc (probablemente esto te lo comas tú, Fer :3)
}

DEFAULT_MOVEMENT_2D : Movement2D : {
    speed_max = 8,
    time_to_max_speed = 0.7
}

update_entity_movement :: proc() {

    for handle in entity_get_group(GROUP_FLAGS_MOVEMENT_2D) {
        
        entity := entity_data(handle)
        using entity.movement_2d

        if !start {
            continue
        }

        speed_progress += delta_seconds()
        speed_progress = math.clamp(speed_progress, 0.0, time_to_max_speed)
        norm_speed_progress := speed_progress / time_to_max_speed
        speed :=  interp_ease_in_expo(norm_speed_progress, speed_min, speed_max)
        delta_traslation := speed * delta_seconds()
        distance := linalg.distance(target, entity.position)
        
        if delta_traslation >= distance {
            entity.position = target
        } else {
            dir := linalg.normalize(target - entity.position)
            entity.position += dir * delta_traslation
        }

        if entity.position == target {
            speed_progress = 0
            speed = 0
            start = false
        }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//:Spawn
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Un spawner crea una cantidad de entidades de un solo tipo en una localización dada
Spawner :: struct {
    template_handle   : Entity_Handle,
    position          : v3,
    amount            : u32,
    points_per_entity : f32, 
    entities          : [dynamic] Entity_Handle,
    // para saber si una entidad ha muerto iterar entities y comprobar su nivel de vida o si se han destruido
}

spawner_init :: proc(spawner : ^Spawner, template : Entity_Handle, position := UP_3D, amount : u32 = 1, points : f32 = 0) {
    assert(spawner != nil)
    assert(entity_valid(template))
    entity_remove_flags(template, { .ENABLED })
    assert(amount > 0)
    spawner.amount = amount
    spawner.template_handle = template
    spawner.entities = make([dynamic] Entity_Handle, 0, spawner.amount)
    spawner.position = position
}

spawner_finish :: proc(spawner : ^Spawner) {
    assert(spawner != nil)
    delete(spawner.entities)
}

spawn :: proc(spawner : ^Spawner) {
    assert(spawner != nil && spawner.amount > 0 && len(&spawner.entities) == 0)
    for i in 0..<spawner.amount {
        handle, entity := entity_clone(spawner.template_handle)
        entity.position = spawner.position
        entity_add_flags(handle, { .ENABLED })
        append_elem(&spawner.entities, handle)
    }
}

// Una ronda crea una cantidad x entidades de x tipos
Wave :: struct {
    spawners : [dynamic] Spawner
}

// Cuando pasa el tiempo o todas las entidades de la ronda son destruidas pasamos a la siguiente
// Cada entidad destruida en una ronda da puntuación
WaveManager :: struct {
    enabled            : bool,
    spawners           : [dynamic] Wave,
    points             : u32,
    current_wave       : u32,
    time_between_waves : f32
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//:Damage
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

DamageSource :: struct {
    damage  : f32    
}

DEFAULT_DAMAGE_SOURCE : DamageSource : {
    damage  = 10,
}

DamageTarget :: struct {
    max_life : f32,
    life     : f32,
}

DEFAULT_DAMAGE_TARGET : DamageTarget : {
    max_life = 100,
    life     = 100,
}


damage_collision :: proc(source, target : ^Entity) {
    using source.damage_source, target.damage_target
    life = clamp(life - damage, 0, max_life)
    if DEBUG_PRINT_DAMAGE do fmt.printf("%v did %v of damage to %v. %v life is %v \n", source.name, damage, target.name, target.name, life)
    if life == 0 {
        //TODO: this a placeholder, should send dead event
        if DEBUG_PRINT_DAMAGE do fmt.printf("%v killed %v\n", source.name, target.name)
        
        if target.id == game.player.entity.id {
            game_quit()
            return
        }

        entity_destroy({target.id})
    }
}