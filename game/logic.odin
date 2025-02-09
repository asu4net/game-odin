package game
import "core:math"
import "core:math/linalg"
import "core:fmt"

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

damage_collision :: proc(source, target : ^Entity) {
    using source.damage_source, target.damage_target
    life = clamp(life - damage, 0, max_life)
    if DEBUG_PRINT_DAMAGE do fmt.printf("%v did %v of damage to %v. %v life is %v \n", source.name, damage, target.name, target.name, life)
    if life == 0 {
        //TODO: this a placeholder, should send dead event
        if DEBUG_PRINT_DAMAGE do fmt.printf("%v killed %v\n", source.name, target.name)
        //entity_destroy({target.id})
    }
}