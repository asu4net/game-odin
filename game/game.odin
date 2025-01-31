package game
import "core:mem"
import "core:fmt"

/////////////////////////////
//:Game
/////////////////////////////

Game :: struct {
    renderer_2d      : Renderer2D,
    entity_registry  : Entity_Registry,
    player           : Player,    
    kamikaze_manager : KamikazeManager,
    exit             : bool,
}

game : Game


game_init :: proc() {
    using game

    // Game groups
    entity_create_group(GROUP_FLAGS_PROJECTILE)
    entity_create_group(GROUP_FLAGS_KAMIKAZE)
    entity_create_group(GROUP_FLAGS_KAMIKAZE_SAW)

    player_init(&player)
    kamikaze_manager_init(&kamikaze_manager)
}

game_finish :: proc() {
    using game
    player_finish(&player)
    kamikaze_manager_finish(&kamikaze_manager)
}

game_update :: proc() {
    using game
    player_update(&player)
    projectile_update(&entity_registry)
    kamikaze_manager_update(&kamikaze_manager)
}

game_fixed_update :: proc() {
    using game
}

/////////////////////////////
//:Main
/////////////////////////////

main :: proc() {
    using game

    /////////////////////////////
    //:Track of memory allocations
    /////////////////////////////

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
    renderer_2d_set_instance(&renderer_2d)
    
    /////////////////////////////
    //:Init & Finish
    /////////////////////////////

    window_init(title = GAME_TITLE, width = WINDOW_WIDTH, height = WINDOW_HEIGHT)
    defer window_finish()
    
    renderer_2d_init()
    defer renderer_2d_finish()

    entity_registry_init()
    defer entity_registry_finish()

    defer collision_2d_finish()

    // Engine groups
    entity_create_group(GROUP_FLAGS_SPRITE)
    entity_create_group(GROUP_FLAGS_CIRCLE)
    entity_create_group(GROUP_FLAGS_COLLIDER_2D)

    time_init()
    //#NOTE_asuarez no need to finish

    game_init()
    defer game_finish()

    /////////////////////////////
    //:Main Loop
    /////////////////////////////

    for !window_should_close() && !game.exit {

        window_poll_input_events()
        time_step()

		for time.fixed_update_calls > 0 {
			collision_2d_query(&entity_registry)
            game_fixed_update()
			time.fixed_update_calls-=1
		}

        game_update()
		clear_screen()
        draw_2d_entities(&entity_registry)
        collision_2d_draw(&entity_registry)
        entity_clean_destroyed_entities(&entity_registry)
        window_update()
    }
}