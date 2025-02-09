package game
import "core:math/linalg"
import "core:mem"

CollisionFlag :: enum {
    nil,
    player,
    player_bullet,
    enemy,
    enemy_bullet,
}

CollisionFlagSet :: bit_set[CollisionFlag]

CollisionEventEnter :: struct {
    source : Entity_Handle,
    target : Entity_Handle,
}

CollisionEventExit :: struct {
    source : Entity_Handle,
    target : Entity_Handle,
}

Collisions2D :: struct {
    collisions_in_last_frame : [dynamic]CollisionEventEnter,
    collision_enter_events   : [dynamic]CollisionEventEnter,
    collision_exit_events    : [dynamic]CollisionEventExit,
    collisions_map           : map[Entity_Handle]map[Entity_Handle]struct{},
}

Collider2D :: struct {
    collision_flag   : CollisionFlag,
    collides_with    : CollisionFlagSet,
    collision_radius : f32,
    collision_tint   : v4,
}

DEFAULT_COLLIDER_2D : Collider2D : {
    collision_flag   = nil,
    collides_with    = nil,
    collision_radius = 0.5,
    collision_tint   = V4_COLOR_LIGHT_GREEN
}

collisions_2d_instance : ^Collisions2D = nil 

collisions_2d_init :: proc(instance : ^Collisions2D) {
    assert(collisions_2d_instance == nil)
    assert(instance != nil)
    collisions_2d_instance = instance
}

collisions_2d_finish :: proc() {
    
    using collisions_2d_instance
    delete(collision_enter_events)
    delete(collision_exit_events)
    
    for _, entity_set in collisions_map {
        delete(entity_set)
    }

    delete(collisions_map)
}

query_2d_collisions :: proc() {

    using collisions_2d_instance

    clear(&collision_enter_events)
    clear(&collision_exit_events)
    
    prev_collisions := make([dynamic] CollisionEventEnter, len(collisions_in_last_frame))
    defer delete(prev_collisions)

    copy(prev_collisions[:], collisions_in_last_frame[:])
    clear(&collisions_in_last_frame)

    circle_group := entity_get_group(GROUP_FLAGS_COLLIDER_2D);
    
    // Collision enter handle
    for i in 0..<len(circle_group) {
        entity_A := entity_data(circle_group[i]);
        for j in (i + 1) ..< len(circle_group){
            entity_B := entity_data(circle_group[j]);
            handle_collision_enter(entity_A, entity_B);
            handle_collision_enter(entity_B, entity_A);
        } 
    }

    // Collision exit handle
    for prev_collision in prev_collisions {
        found : bool
        for curr_collision in collisions_in_last_frame {
            if prev_collision == curr_collision {
                found = true
                break
            }
        }
        
        if found do continue

        exit_event : CollisionEventExit = {
            source = prev_collision.source,
            target = prev_collision.target,
        }
        append_elem(&collision_exit_events, exit_event)
        delete_key(&collisions_map[exit_event.source], exit_event.target)
    }
}

circle_collides :: proc(entity_A : ^Entity, entity_B : ^Entity) -> bool {
    radius_sum := entity_A.collision_radius + entity_B.collision_radius;
    return linalg.vector_length2(entity_A.position - entity_B.position) <= radius_sum * radius_sum
}

handle_collision_enter :: proc(entity_A : ^Entity, entity_B : ^Entity) {
    
    using collisions_2d_instance

    entity_handle_A : Entity_Handle = { id = entity_A.id };
    entity_handle_B : Entity_Handle = { id = entity_B.id };
    if(entity_B.collision_flag in entity_A.collides_with) {
        
        if entity_handle_A not_in collisions_map {
            collisions_map[entity_handle_A] = make(map[Entity_Handle]struct{})
        }

        if(circle_collides(entity_A, entity_B)) {
            
            collision_enter_event : CollisionEventEnter = { entity_handle_A, entity_handle_B }
            append_elem(&collisions_in_last_frame, collision_enter_event)

            if(entity_handle_B not_in collisions_map[entity_handle_A]){
                append_elem(&collision_enter_events, collision_enter_event);
                A_collides_width := &collisions_map[entity_handle_A]
                A_collides_width[entity_handle_B] = {}
            }
        }
    }
}