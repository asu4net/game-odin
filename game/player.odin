package game

import "core:math/linalg"
import "core:strings"
import "core:fmt"
import "engine:global/color"
import "engine:input"

Player_Movement :: struct {
    speed : f32,
}

Player_Weapons :: struct { 
    firerate : f32,
    time_since_fired : f32,
}

Player :: struct {
    using movement     : Player_Movement,
    using weapons      : Player_Weapons,
    entity             : Entity_Handle,
    initialized        : bool,
    axis               : v2,
    fire               : bool,
}

player_initialized :: proc(player : ^Player) -> bool {
    assert(player != nil)
    return player.initialized
}

player_init :: proc(player : ^Player) {
    assert(!player_initialized(player))
    using player;

    entity_handler, data := entity_create(NAME_PLAYER, { .PLAYER })
    entity = entity_handler
    data.sprite = DEFAULT_SPRITE_ATLAS_ITEM;
    data.damage_target = DEFAULT_DAMAGE_TARGET;
    data.collider = DEFAULT_COLLIDER_2D;

    firerate = PLAYER_FIRERATE;
    speed = PLAYER_SPEED; 
    data.item = .Player;
    data.collision_flag = CollisionFlag.player;
    data.collides_with = { .enemy, .enemy_bullet };
    data.damage_target.life = 1;
    emitter_handle, emitter_data := emitter_create();
    data.particle_emitter = emitter_handle;
    emitter_data.position = data.position;
    emitter_data.scale = ONE_3D * 0.15;

    /*
    flipbook_create(&data.flipbook, duration = 1, loop = true, items = {
        Texture_Name.Kamikaze_Skull,
        Texture_Name.Kazmikaze_Saw,
        Texture_Name.Player,
    })
    */

    data.flipbook.playing = true

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
    using player
    assert(player_initialized(player))

    if input.is_key_pressed(input.KEY_W) {
        axis.y = 1    
    } else if input.is_key_pressed(input.KEY_S) {
        axis.y = -1
    } else {
        axis.y = 0
    }

    if input.is_key_pressed(input.KEY_A) {
        axis.x = -1    
    } else if input.is_key_pressed(input.KEY_D) {
        axis.x = 1
    } else {
        axis.x = 0
    }

    if axis != ZERO_2D {
        axis = linalg.normalize(axis)
    }

    fire = input.is_key_pressed(input.KEY_SPACE)
}

@(private = "file")
movement_update :: proc(player : ^Player) {
    assert(player_initialized(player))
    entity := entity_data(player.entity)
    entity.position.xy += player.axis * player.speed * delta_seconds() 
    
    if emitter_exists(entity.particle_emitter) {
        emitter_data := emitter_data(entity.particle_emitter);
        emitter_data.velocity = (-entity.position + emitter_data.position) / delta_seconds();
        emitter_data.active = emitter_data.velocity != ZERO_3D;
        emitter_data.position = entity.position;
    }
}

@(private = "file")
weapons_update :: proc(player : ^Player) {
    assert(player_initialized(player))
    using player
    weapons.time_since_fired += delta_seconds()
    if (player.fire && weapons.time_since_fired >= firerate) {
        fire_projectile(player)
        player.weapons.time_since_fired = 0
    }
}

projectiles := 0

@(private = "file")
fire_projectile :: proc(player : ^Player) {
    // placeholder projectile

    handle, entity := entity_create(name = "Bullet");
    player_entity := entity_data(player.entity);
    entity.collider       = DEFAULT_COLLIDER_2D;
    entity.circle         = DEFAULT_CIRCLE;
    entity.damage_source  = DEFAULT_DAMAGE_SOURCE;
    entity.damage_target  = DEFAULT_DAMAGE_TARGET;
    entity.projectile     = DEFAULT_PROJECTILE;
    
    entity.position = player_entity.position;
    entity.radius = 0.1;
    entity.collision_radius = 0.15;
    entity.thickness = 1;
    entity.tint = color.LIGHT_RED;
    entity.collision_flag = CollisionFlag.player_bullet;
    entity.collides_with = { .enemy };
    entity.damage_target.life = 1;
    entity.damage_source.damage = PLAYER_DAMAGE;
}