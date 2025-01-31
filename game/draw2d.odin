package game

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

    for handle in entity_get_group(GROUP_FLAGS_SPRITE) {
        
        entity := entity_data(handle)
        draw_sprite(&entity.tranform, &entity.sprite, entity.tint, entity.id)
    }

    for handle in entity_get_group(GROUP_FLAGS_CIRCLE) {
        
        entity := entity_data(handle)
        draw_circle(&entity.tranform, &entity.circle, entity.tint, entity.id)
    }
    
    scene_2d_end()
}