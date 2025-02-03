package game
import "core:math"
import "core:math/linalg"

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