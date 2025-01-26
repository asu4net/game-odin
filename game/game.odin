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
    renderer_2d_set_instance(&renderer_2d)
    
    renderer_2d_init()
    entity_registry_init()

    enities_2d_init()

    // Test goblin
    {
        texture_2d_init(&goblin_tex, "assets/goblin.png")
        _, entity := entity_create("Goblin", { .SPRITE })
        entity.texture = &goblin_tex
    }
}

game_finish :: proc() {
    using gs
    texture_2d_finish(&goblin_tex)    
    entity_registry_finish()
    renderer_finish()
}

game_update :: proc() {
    using gs
    entities_2d_draw(&entity_registry)        
}

game_fixed_update :: proc() {
    
}