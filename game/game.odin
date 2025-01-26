package game
import "core:mem"
import "core:fmt"

GameState :: struct {
    renderer_2d     : Renderer2D,
    goblin_tex      : Texture2D,
    entity_registry : Entity_Registry,
}

gs : GameState

game_init :: proc() {
    using gs

    entity_registry_set_instance(&entity_registry)
    renderer_set_instance(&renderer_2d)
    
    renderer_init()
    entity_registry_init()
    texture_init(&goblin_tex, "assets/goblin.png")

    {
        handle := entity_create("Goblin", { .SPRITE })
        entity := entity_data(handle)
        entity.texture = &goblin_tex
    }
}

game_finish :: proc() {
    using gs
    texture_finish(&goblin_tex)    
    entity_registry_finish()
    renderer_finish()
}

game_update :: proc() {
    using gs
    
    width, height := window_get_size()
    scene : Scene2D = {
        camera = DEFAULT_CAMERA,
        window_width = f32(width),
        window_height = f32(height)   
    }
        
    scene_2d_begin(scene)

    // Entity iteration
    {
        using entity_registry
        for i in 0..<entity_count {

            entity := &entities[i]
            
            if Entity_Flag.ENABLED not_in entity.flags {
                continue
            }
            
            if Entity_Flag.SPRITE in entity.flags {
                draw_sprite(&entity.tranform, &entity.sprite, entity.tint, entity.id)
            }
        }
    }

    scene_2d_end()       
}