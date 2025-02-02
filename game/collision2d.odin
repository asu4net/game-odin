package game
import "core:math/linalg"

CollisionFlag :: enum {
    nil,
    player,
    player_bullet,
    enemy,
    enemy_bullet,
}

CollisionFlagSet :: bit_set[CollisionFlag]

CollisionEventEnter :: struct {
    self  : Entity_Handle,
    other : Entity_Handle,
}

CollisionEventExit :: struct {
    self  : Entity_Handle,
    other : Entity_Handle,
}

Collider2D :: struct {
    collision_flag   : CollisionFlag,
    collides_with    : CollisionFlagSet,
    collision_radius : f32,
    collision_tint   : v4,
    collision_enter  : [dynamic]CollisionEventEnter,
    collision_exit   : [dynamic]CollisionEventExit,
    colliding_with   : map[Entity_Handle]struct{},
}

DEFAULT_COLLIDER_2D : Collider2D : {
    collision_flag   = nil,
    collides_with    = nil,
    collision_radius = 0.5,
    collision_tint   = V4_COLOR_LIGHT_GREEN
}

collision_2d_finish :: proc() {
    for handle in entity_get_group(GROUP_FLAGS_COLLIDER_2D) {
        entity := entity_data(handle);
        delete(entity.collision_enter);
        delete(entity.collision_exit);
        delete(entity.colliding_with);
    }       
}

draw_2d_collisions :: proc() {

    reg := entity_registry_get_instance()
    assert(reg != nil);
    
    width, height := window_get_size()
    
    scene : Scene2D = {
        camera = DEFAULT_CAMERA,
        window_width = f32(width),
        window_height = f32(height)   
    }
    
    if !DEBUG_DRAW_COLLIDERS {
        return
    }

    scene_2d_begin(scene)

    for handle in entity_get_group(GROUP_FLAGS_COLLIDER_2D) {
        
        entity := entity_data(handle)
        
        circle : Circle = DEFAULT_CIRCLE
        circle.radius = entity.collision_radius
        if(len(entity.colliding_with) == 0){
            draw_circle(&entity.tranform, &circle, entity.collision_tint, entity.id)
        } else {
            draw_circle(&entity.tranform, &circle, {1, 0, 0, 1}, entity.id)
        }
    }

    scene_2d_end()
            
}

collision_2d_query :: proc() {
    reg := entity_registry_get_instance()
    assert(reg != nil);

    circle_group : = entity_get_group(GROUP_FLAGS_COLLIDER_2D);
    for i in 0..<len(circle_group) {
        entity := entity_data(circle_group[i]);
        clear(&entity.collision_enter);
        clear(&entity.collision_exit);
    }
    for i in 0..<len(circle_group) {
        entity_A := entity_data(circle_group[i]);
        for j in (i + 1) ..< len(circle_group){
            entity_B := entity_data(circle_group[j]);
            handle_collision(entity_A, entity_B);
            handle_collision(entity_B, entity_A);
        } 

    }
}

circle_collides :: proc(entity_A : ^Entity, entity_B : ^Entity) -> bool {
    radius_sum := entity_A.collision_radius + entity_B.collision_radius;
    return linalg.vector_length2(entity_A.position - entity_B.position) <= radius_sum * radius_sum
}

handle_collision :: proc(entity_A : ^Entity, entity_B : ^Entity) {
    entity_handle_A : Entity_Handle = { id = entity_A.id };
    entity_handle_B : Entity_Handle = { id = entity_B.id };
    if(entity_B.collision_flag in entity_A.collides_with){
        if(circle_collides(entity_A, entity_B)) {
            if(entity_handle_B not_in entity_A.colliding_with){
                append_elem(&entity_A.collision_enter, CollisionEventEnter{ entity_handle_A, entity_handle_B });
                entity_A.colliding_with[entity_handle_B] = {};
            }
        }else{
            if(entity_handle_B in entity_A.colliding_with){
                append_elem(&entity_A.collision_exit, CollisionEventExit{ entity_handle_A, entity_handle_B });
                delete_key(&entity_A.colliding_with, entity_handle_B);
            }
        }
    }
}