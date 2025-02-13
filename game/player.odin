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
    using input      : Player_Input,
    using movement   : Player_Movement,
    using weapons    : Player_Weapons,
    entity           : Entity_Handle,
    initialized      : bool,
}

player_initialized :: proc(player : ^Player) -> bool {
    assert(player != nil)
    return player.initialized
}

player_init :: proc(player : ^Player) {
    assert(!player_initialized(player))
    using player
    entity_handler, data := entity_create(NAME_PLAYER, { .PLAYER, .COLLIDER_2D, .DAMAGE_TARGET } + GROUP_FLAGS_SPRITE)
    entity = entity_handler
    data.item = .Player
    speed = PLAYER_SPEED 
    firerate = PLAYER_FIRERATE
    
    data.collision_flag = CollisionFlag.player;
    data.collides_with = { .enemy, .enemy_bullet };
    data.damage_target.life = 1
    emitter_handle, emitter_data := emitter_create();
    data.particle_emitter = emitter_handle;
    emitter_data.position = data.position;
    emitter_data.scale = V3_ONE * 0.15

    initialized = true
}

player_finish :: proc(player : ^Player) {
    assert(player_initialized(player))
    entity_destroy(player.entity)
}

player_update :: proc(player : ^Player) {
    assert(player_initialized(player))
    input_update(player)
    movement_update(player)
    weapons_update(player)
}

player_collision :: proc(source : ^Entity, target : ^Entity) {
    if source.collision_flag == .enemy {
        game_quit()
    }
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
    
    emitter_data := emitter_data(entity.particle_emitter);
    emitter_data.velocity = (-entity.position + emitter_data.position) / delta_seconds();
    emitter_data.active = emitter_data.velocity != V3_ZERO;
    emitter_data.position = entity.position;
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

    handle, entity := entity_create(name = "Bullet", flags = GROUP_FLAGS_PROJECTILE + GROUP_FLAGS_CIRCLE)
    player_entity := entity_data(player.entity)
    entity.position = player_entity.position
    entity.radius = 0.1
    entity.collision_radius = 0.15
    entity.thickness = 1
    entity.tint = V4_COLOR_RED
    entity.collision_flag = CollisionFlag.player_bullet;
    entity.collides_with = { .enemy };
    entity.damage_target.life = 1
    entity.damage_source.damage = PLAYER_DAMAGE
}