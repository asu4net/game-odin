package game

CollisionShape :: enum {

}

CollisionFlags :: enum {

}

Collider :: struct {

}

DEFAULT_COLLIDER : Collider : {

}

collision_2d_init :: proc() {
    entity_create_group(COLLIDER_GROUP_FLAGS)
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