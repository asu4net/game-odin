package game
import "core:math/linalg"
import "core:strings"
import "core:fmt"

Player_Movement :: struct {
    speed : f32,
}

Player_Input :: struct {
    axis : v2,
    fire : bool,
}

Player_Weapons :: struct { 
    firerate : f32,
    time_since_fired : f32,
}

Player :: struct {
    using input    : Player_Input,
    using movement : Player_Movement,
    using weapons  : Player_Weapons,
    entity         : Entity_Handle,
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
    texture_2d_init(&texture, PLAYER_TEXTURE_PATH)
    entity_handler, data := entity_create(PLAYER_NAME, PLAYER_FLAGS)
    entity  = entity_handler
    data.texture = &texture
    speed = PLAYER_SPEED 
    firerate = PLAYER_FIRERATE
    initialized = true
}

player_finish :: proc(player : ^Player) {
    assert(player_initialized(player))
    texture_2d_finish(&player.texture)
    entity_destroy(player.entity)
}

player_update :: proc(player : ^Player) {
    assert(player_initialized(player))
    input_update(player)
    movement_update(player)
    weapons_update(player)
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

    fire = input_is_key_pressed(KEY_SPACE)
}

@(private = "file")
movement_update :: proc(player : ^Player) {
    assert(player_initialized(player))
    using player.movement, player.input
    entity := entity_data(player.entity)
    entity.position.xy += axis * speed * delta_seconds() 
}

@(private = "file")
weapons_update :: proc(player : ^Player) {
    assert(player_initialized(player))
    using player
    weapons.time_since_fired += delta_seconds()
    if (input.fire && weapons.time_since_fired >= firerate) {
        fire_projectile(player)
        player.weapons.time_since_fired = 0
    }
}

projectiles := 0

@(private = "file")
fire_projectile :: proc(player : ^Player) {
    // placeholder projectile

    handle, data := entity_create(flags = { .CIRCLE, .PROJECTILE, .CIRCLE_COLLIDER, })
    player_entity := entity_data(player.entity)
    data.position = player_entity.position
    data.radius = 0.1
    data.thickness = 1
    data.tint = V4_COLOR_RED
}