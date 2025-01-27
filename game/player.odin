package game
import "core:math/linalg"

Player_Movement :: struct {
    speed : f32,
}

Player_Input :: struct {
    axis : v2,
}

Player :: struct {
    using input    : Player_Input,
    using movement : Player_Movement,
    handle         : Entity_Handle,
    texture        : Texture2D,
    initialized    : bool
}

player_initialized :: proc(player : ^Player) -> bool {
    assert(player != nil)
    return player.initialized
}

player_init :: proc(player : ^Player) {
    assert(!player_initialized(player))
    using player
    texture_2d_init(&player.texture, "assets/player.png")
    entity, data := entity_create("Player", {
        .PLAYER,
        .SPRITE
    })
    player.handle  = entity
    data.texture = &player.texture
    speed = PLAYER_SPEED 
    initialized = true
}

player_finish :: proc(player : ^Player) {
    assert(player_initialized(player))
    texture_2d_finish(&player.texture)
    entity_destroy(player.handle)
}

player_update :: proc(player : ^Player) {
    assert(player_initialized(player))
    input_update(player)
    movement_update(player)
}

@(private = "file")
input_update :: proc(player : ^Player) {
    using player.input
    assert(player_initialized(player))

    if input_is_key_pressed(KEY_W) {
        axis.y = 1    
    } else if input_is_key_pressed(KEY_S) {
        axis.y = -1
    } else {
        axis.y = 0
    }

    if input_is_key_pressed(KEY_A) {
        axis.x = -1    
    } else if input_is_key_pressed(KEY_D) {
        axis.x = 1
    } else {
        axis.x = 0
    }

    if axis != V2_ZERO {
        axis = linalg.normalize(axis)
    }
}

@(private = "file")
movement_update :: proc(player : ^Player) {
    assert(player_initialized(player))
    using player.movement, player.input
    entity := entity_data(player.handle)
    entity.position.xy += axis * speed * delta_seconds() 
}