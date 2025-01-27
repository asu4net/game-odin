package game

ENTITIES_2D_FLAGS : Entity_Flag_Set : {
    .SPRITE
} 

enities_2d_init :: proc() {
    entity_create_group(ENTITIES_2D_FLAGS)
}

draw_2d_entities :: proc(reg : ^Entity_Registry) {
    assert(reg != nil)
    using reg

    width, height := window_get_size()
    
    scene : Scene2D = {
        camera = DEFAULT_CAMERA,
        window_width = f32(width),
        window_height = f32(height)   
    }
        
    scene_2d_begin(scene)

    for handle in entity_get_group(ENTITIES_2D_FLAGS) {
        entity := entity_data(handle)
        if Entity_Flag.ENABLED not_in entity.flags || Entity_Flag.VISIBLE not_in entity.flags {
            continue
        }
        draw_sprite(&entity.tranform, &entity.sprite, entity.tint, entity.id)
    }
    
    scene_2d_end()
}