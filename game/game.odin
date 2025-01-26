package game
import "core:mem"
import "core:fmt"

GameState :: struct {
    renderer_2d     : Renderer2D,
    goblin_tex      : Texture2D,
    entity_registry : Entity_Registry,
}

gs : GameState

main :: proc() {
    using gs

    when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

    entity_registry_set_instance(&entity_registry)
    renderer_set_instance(&renderer_2d)
    
    window_init(title = "Game")
    defer window_finish()
    
    renderer_init()
    defer renderer_finish()

    entity_registry_init()
    defer entity_registry_finish()

    // Goblin
    texture_init(&goblin_tex, "assets/goblin.png")
    defer texture_finish(&goblin_tex)    
    
    {
        handle := entity_create("Goblin", { .SPRITE })
        entity := entity_data(handle)
        entity.texture = &goblin_tex
    }

    for !window_should_close() {

        window_poll_events()
        clear_color()

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
                    using entity.tranform, entity.sprite, entity.common
                    draw_quad(position, rotation, scale, tint, texture, tiling, flip_x, flip_y, autosize, i32(id))
                }
            }
        }

        scene_2d_end()
        
        window_update()
    }
}