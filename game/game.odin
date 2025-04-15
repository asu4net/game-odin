package game
import "core:mem"
import "core:fmt"
import "engine:window"
import "engine:input"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//:Game
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Game :: struct {
    // Engine
    game_window            : window.Window,
    scene_2d               : Scene2D,
    entity_registry        : Entity_Registry,
    particle_registry      : Particle_Registry,
    collisions_2d          : Collisions2D,
    
    // Game specific
    player             : Player,
    kamikaze_manager   : KamikazeManager,
}

@(private = "file")
game_instance : ^Game

game_init :: proc(instance : ^Game) {
    
    assert(game_instance == nil)
    assert(instance != nil)
    game_instance = instance
    using game_instance

    /////////////////////////////
    //:Track of memory allocations
    /////////////////////////////

    fmt.printf("Size of entity data: %i \n", size_of(Entity))

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

    /////////////////////////////
    //:Init & Finish
    /////////////////////////////
    
    window.init(&game_window, title = GAME_TITLE, width = WINDOW_WIDTH, height = WINDOW_HEIGHT)
    defer window.finish()
    
    scene_2d_init(&scene_2d)
    defer scene_2d_finish()
    
    entity_registry_init(&entity_registry)
    defer entity_registry_finish()

    particle_registry_init(&particle_registry)
    defer particle_registry_finish()

    collisions_2d_init(&collisions_2d)
    defer collisions_2d_finish()
    
    start()
    defer finish()

    /////////////////////////////
    //:Main Loop
    /////////////////////////////

    for window.keep_opened() {
        
        when ODIN_DEBUG do update_frame_by_frame_mode()

        if can_update() {
            update()
            update_pickup_movement();
            update_entity_movement()
            query_2d_collisions()
            post_collisions_update()
            update_particles()
        }
        
        draw_scene_2d()
        
        if can_update() {
            clean_destroyed_entities()
        }
    }
}

delta_seconds :: proc() -> f32 {
    return window.delta_seconds()
}

game_quit :: proc() {
    window.close()
}

viewport_size :: proc() -> (i32, i32) {
    return window.get_size()
}

/////////////////////////////
//:Game Private
/////////////////////////////
@(private = "file")
can_update :: proc() -> bool {
    when ODIN_DEBUG do return frame_by_frame_mode.next_frame
    return true
}

@(private = "file")
start :: proc() {
    using game_instance
    
    player_init(&player)
    kamikaze_manager_init(&kamikaze_manager)
    homing_missile_init();
    pointer_line_init();
}

@(private = "file")
update :: proc() {
    using game_instance
    player_update(&player)
    projectile_update()
    kamikaze_manager_update()
    homing_missile_update();
    pointer_line_update();
}

@(private = "file")
post_collisions_update :: proc() {
    using game_instance;

    for enter_event in collisions_2d.collision_enter_events {
        
        source := entity_data(enter_event.source);
        target := entity_data(enter_event.target);  
        
        if is_damage_target(target) && is_damage_source(source) {
            damage_collision(source, target);
            
            //#REVIEW_asuarez Maybe we should poll the collision events from the projectile class
            // hello, this is Ferdom-M, I agree
            if is_projectile(source) {
                entity_destroy({source.id});
            }
        }
        if .PICK_UP in source.flags && .PLAYER in target.flags { 
            pickup_collision(source, target);
        }
    }
}

@(private = "file")
finish :: proc() {
    using game_instance
    player_finish(&player)
    kamikaze_finish()
    homing_missile_finish();
    pointer_line_finish();
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//:Main
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

game : Game

main :: proc() {
    game_init(&game)
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//:Debug only
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

when ODIN_DEBUG {

    @(private = "file")
    FrameByFrameMode :: struct {
        frame_by_frame         : bool,
        frame_by_frame_pressed : bool,
        next_frame             : bool,
        next_frame_pressed     : bool,
    }

    @(private = "file")
    DEFAULT_FRAME_BY_FRAME_MODE : FrameByFrameMode : {
    }

    @(private = "file")
    frame_by_frame_mode : FrameByFrameMode

    @(private = "file")
    update_frame_by_frame_mode :: proc() {
        using frame_by_frame_mode

        if input.is_key_pressed(input.KEY_LEFT_CONTROL) && input.is_key_pressed(input.KEY_P) {

            if !frame_by_frame_pressed {
                frame_by_frame_pressed = true
                frame_by_frame =! frame_by_frame
            }

        } else {
            frame_by_frame_pressed = false
        }

        if !frame_by_frame {
            next_frame = true
            return    
        }

        next_frame = false
        
        if  input.is_key_pressed(input.KEY_LEFT_CONTROL) && input.is_key_pressed(input.KEY_RIGHT) {
            if !next_frame_pressed {
                next_frame_pressed = true
                next_frame = true
            }
        } else {
            next_frame_pressed = false
        }
    }    
}