package game
import "core:mem"
import "core:fmt"

/////////////////////////////
//:Game
/////////////////////////////

Game :: struct {
    // Engine
    window             : Window,
    scene_2d           : Scene2D,
    entity_registry    : Entity_Registry,
    particle_registry  : Particle_Registry,
    collisions_2d      : Collisions2D,

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
    //:Init & Finish
    /////////////////////////////
    
    window_init(&window, title = GAME_TITLE, width = WINDOW_WIDTH, height = WINDOW_HEIGHT)
    defer window_finish()
    
    scene_2d_init(&scene_2d)
    defer scene_2d_finish()
    
    entity_registry_init(&entity_registry)
    defer entity_registry_finish()

    particle_registry_init(&particle_registry)
    defer particle_registry_finish()

    collisions_2d_init(&collisions_2d)
    defer collisions_2d_finish()
    
    // Engine groups
    entity_create_group(GROUP_FLAGS_SPRITE)
    entity_create_group(GROUP_FLAGS_CIRCLE)
    entity_create_group(GROUP_FLAGS_COLLIDER_2D)
    entity_create_group(GROUP_FLAGS_MOVEMENT_2D)

    start()
    defer finish()

    /////////////////////////////
    //:Main Loop
    /////////////////////////////

    for keep_window_opened() {
        update()
        update_entity_movement()
        query_2d_collisions()
        post_collisions_update()
        particle_update()
        draw_scene_2d()
        clean_destroyed_entities()
    }
}

game_quit :: proc() {
    window_close()
}

/////////////////////////////
//:Game Private
/////////////////////////////

@(private = "file")
start :: proc() {
    using game_instance
    
    // Game groups
    entity_create_group(GROUP_FLAGS_PROJECTILE)
    entity_create_group(GROUP_FLAGS_KAMIKAZE)
    entity_create_group(GROUP_FLAGS_KAMIKAZE_SAW)

    player_init(&player)
    kamikaze_manager_init(&kamikaze_manager)
}

@(private = "file")
update :: proc() {
    using game_instance
    player_update(&player)
    projectile_update()
    kamikaze_manager_update()
}

@(private = "file")
post_collisions_update :: proc() {
    using game_instance

    for enter_event in collisions_2d.collision_enter_events {
        
        source := entity_data(enter_event.source) 
        target := entity_data(enter_event.target)  

        if .KAMIKAZE in target.flags {
            kamikaze_collision(source, target)    
        } else if .PROJECTILE in target.flags {
            projectile_collision(source, target)
        } else if target.id == player.entity.id {
            player_collision(source, target)
        }
    }
}

@(private = "file")
finish :: proc() {
    using game_instance
    player_finish(&player)
}