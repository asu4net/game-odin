package game

CollisionFlag :: enum {
    nil    
}

CollisionFlagSet :: bit_set[CollisionFlag]

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

collision_2d_init :: proc() {
    entity_create_group(CIRCLE_COLLIDER_GROUP_FLAGS)
}

collision_2d_draw :: proc(reg : ^Entity_Registry) {
    
    width, height := window_get_size()
    
    scene : Scene2D = {
        camera = DEFAULT_CAMERA,
        window_width = f32(width),
        window_height = f32(height)   
    }
        
    scene_2d_begin(scene)

    for handle in entity_get_group(CIRCLE_COLLIDER_GROUP_FLAGS) {
        
        entity := entity_data(handle)
        
        if Entity_Flag.ENABLED not_in entity.flags {
            continue
        }

        circle : Circle = DEFAULT_CIRCLE
        circle.radius = entity.collision_radius
        draw_circle(&entity.tranform, &circle, entity.collision_tint, entity.id)
    }
    
    scene_2d_end()        
}

collision_2d_query :: proc(reg : ^Entity_Registry) {
    /*assert(reg != nil)
    using reg

    width, height := window_get_size()
    
    scene : Scene2D = {
        camera = DEFAULT_CAMERA,
        window_width = f32(width),
        window_height = f32(height)   
    }
        
    scene_2d_begin(scene)

    for handle in entity_get_group(SPRITE_GROUP_FLAGS) {
        entity := entity_data(handle)
        if Entity_Flag.ENABLED not_in entity.flags || Entity_Flag.VISIBLE not_in entity.flags {
            continue
        }
        draw_sprite(&entity.tranform, &entity.sprite, entity.tint, entity.id)
    }

    for handle in entity_get_group(CIRCLE_GROUP_FLAGS) {
        entity := entity_data(handle)
        if Entity_Flag.ENABLED not_in entity.flags || Entity_Flag.VISIBLE not_in entity.flags {
            continue
        }
        draw_circle(&entity.tranform, &entity.circle, entity.tint, entity.id)
    }
    
    scene_2d_end()*/
}