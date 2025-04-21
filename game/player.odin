package game

import "core:math/linalg"
import "core:strings"
import "core:fmt"
import "engine:global/color"
import "engine:input"
import "core:math/rand"
import "engine:global/interpolate"

Player_Movement :: struct {
    speed              : f32,
    pos_history        : [POSITION_HISTORY_AMOUNT]v3,
    current_pos        : u16,
    pos_history_update : f32,
}

Player_Weapons :: struct { 
    firerate         : f32,
    time_since_fired : f32,
    level            : u8,
    ammo             : u32,
}

Minion_Movement :: struct { 
    direction        : v2,
    speed            : f32,
    alignment        : v2,
    cohesion         : v2,
    separation       : v2,
    last_pos_ckecked : v3,
    time_last_pos    : f32,
}

minion_alignment  : f32 = 0;
minion_cohesion   : f32 = 0.7;
minion_separation : f32 = 0.6;

Player_Minion :: struct {
    movement      : Minion_Movement,
    entity        : Entity_Handle,
}

Player :: struct {
    using movement     : Player_Movement,
    using weapons      : Player_Weapons,
    entity             : Entity_Handle,
    initialized        : bool,
    axis               : v2,
    fire               : bool,
    minions            : [MAX_AMMO]Player_Minion,
}

player_initialized :: proc(player : ^Player) -> bool {
    assert(player != nil)
    return player.initialized
}

player_init :: proc(player : ^Player) {
    assert(!player_initialized(player))
    using player;

    entity_handle, data := entity_create(NAME_PLAYER, { .PLAYER })
    entity = entity_handle;
    data.sprite = DEFAULT_SPRITE_ATLAS_ITEM;
    data.damage_target = DEFAULT_DAMAGE_TARGET;
    data.collider = DEFAULT_COLLIDER_2D;

    firerate = PLAYER_FIRERATE;
    speed    = PLAYER_SPEED; 
    ammo     = 0;
    level    = 1;
    data.item = .Player;
    data.collision_flag = CollisionFlag.player;
    data.collides_with = { .enemy, .enemy_bullet, .pick_up };
    data.damage_target.life = 1;
    emitter_handle, emitter_data := emitter_create();
    data.particle_emitter = emitter_handle;
    emitter_data.position = data.position;
    emitter_data.scale = ONE_3D * 0.15;

    for i in 0..< len(minions) { 
        minion_handle, minion_data := entity_create(NAME_PLAYER_MINION);
        
        minions[i].entity        = minion_handle;
        minions[i].movement.speed = MINION_SPEED;
        
        //random := v3{ (rand.float32() - 0.5) * 2, (rand.float32() - 0.5) * 2, 0 } 
        minion_data.position = {data.position.x, data.position.y, data.position.z}; 
        minion_data.scale    = {0.2, 0.2, 0.2};
        minion_data.sprite   = DEFAULT_SPRITE_ATLAS_ITEM;
        minion_data.item     = .Player;

        //entity_set_parent(minion_handle, entity_handle);
        entity_remove_flags(minion_handle, { .ENABLED });
    }
    /*
    flipbook_create(&data.flipbook, duration = 1, loop = true, items = {
        Texture_Name.Kamikaze_Skull,
        Texture_Name.Kazmikaze_Saw,
        Texture_Name.Player,
    })
    */

    data.flipbook.playing = true

    initialized = true

    player_set_ammo(player, MAX_AMMO);
}

player_finish :: proc(player : ^Player) {
    assert(player_initialized(player))
    entity_destroy(player.entity)
}

player_update :: proc(player : ^Player) {
    assert(player_initialized(player));
    input_update(player);
    movement_update(player);
    minions_movement_update(player);
    weapons_update(player);
}

player_set_ammo :: proc(player : ^Player, new_ammo : u32) { 
    assert(player_initialized(player));
    player.ammo = new_ammo;
    
    if(new_ammo >= AMMO_LV3) {   
        player.level = 3;
    }
    else if(new_ammo >= AMMO_LV2) {   
        player.level = 2;
    }
    else {
        player.level = 1;
    }

    for i in 0..< new_ammo { 
        minion_data := entity_data(player.minions[i].entity);
        
        entity_add_flags(player.minions[i].entity, { .ENABLED });
    }
    for i in new_ammo..< len(player.minions) { 
        minion_data := entity_data(player.minions[i].entity);
        
        entity_remove_flags(player.minions[i].entity, { .ENABLED });
    }
}

player_damage_collision :: proc(player : ^Player, source : ^Entity) {
    using source.damage_source;

    if(player.ammo > 0) {
        new_ammo := clamp(player.ammo - damage, 0, MAX_AMMO);
        player_set_ammo(player, new_ammo);
    } else {
        game_quit();
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
    
    if(player.axis.x != 0 || player.axis.y != 0) {
        player.pos_history_update += delta_seconds();
        for (player.pos_history_update >= POSITION_HISTORY_UPDATE) {
            player.current_pos = (player.current_pos + 1) % (POSITION_HISTORY_AMOUNT);
            player.pos_history[player.current_pos] = entity.position;
            player.pos_history_update -= POSITION_HISTORY_UPDATE;
        }
    }
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
        player_pos := entity_data(player.entity).position;
        switch(player.level) {
            case 1:
                fire_projectile(player_pos, PLAYER_BULLET_LV1_DAMAGE, PLAYER_BULLET_LV1_SPEED, PLAYER_BULLET_LV1_RADIUS);
                break;
            case 2, 3:
                fire_projectile({ player_pos.x - 0.1, player_pos.y, player_pos.z }, PLAYER_BULLET_LV1_DAMAGE, PLAYER_BULLET_LV1_SPEED, PLAYER_BULLET_LV1_RADIUS);
                fire_projectile({ player_pos.x + 0.1, player_pos.y, player_pos.z }, PLAYER_BULLET_LV1_DAMAGE, PLAYER_BULLET_LV1_SPEED, PLAYER_BULLET_LV1_RADIUS);
                break;
        }
        player.weapons.time_since_fired = 0

        for i in 0..< ammo { 
            minion := entity_data(minions[i].entity);
            fire_projectile(//player_pos +
                minion.position, MINION_BULLET_LV1_DAMAGE, MINION_BULLET_LV1_SPEED, MINION_BULLET_LV1_RADIUS);
        }
    }
}

projectiles := 0

@(private = "file")
fire_projectile :: proc(position : v3, damage : u32, speed : f32, radius : f32) {
    // placeholder projectile

    // ok its now urgent to use a bullet pool

    handle, entity := entity_create(name = "Bullet");

    entity.collider             = DEFAULT_COLLIDER_2D;
    entity.circle               = DEFAULT_CIRCLE;
    entity.damage_source        = DEFAULT_DAMAGE_SOURCE;
    entity.projectile           = DEFAULT_PROJECTILE;
    
    entity.position             = position;
    entity.radius               = radius;
    entity.collision_radius     = radius;
    entity.thickness            = 1;
    entity.tint                 = color.LIGHT_RED;
    entity.collision_flag       = CollisionFlag.player_bullet;
    entity.collides_with        = { .enemy };
    entity.damage_source.damage = damage;
    entity.projectile.speed     = speed;
}

@(private = "file")
minions_movement_update :: proc(player : ^Player) {
    player_entity := entity_data(player.entity);

    if(player.axis.x == 0 && player.axis.y == 0) {
        return;
    }
    for i in 0..< player.ammo { 
        minion := entity_data(player.minions[i].entity);
        using player.minions[i].movement;
        using minion;
        
        delay : f32 = MINION_MOVEMENT_DELAY / POSITION_HISTORY_UPDATE;

        current_pos : f32 = ((f32)(player.current_pos) - delay * (f32)(i + 1));
        pos_int : u16 = u16(current_pos);
        decimals := current_pos - (f32)(pos_int);
        decimals = decimals < 0 ? -decimals : decimals;
        pos_int = pos_int % POSITION_HISTORY_AMOUNT;
        pos_int = pos_int < 0 ? pos_int + POSITION_HISTORY_AMOUNT: pos_int;

        next_pos_int := pos_int;
        iterations := 0;
        for (player.pos_history[pos_int] == player.pos_history[next_pos_int] && iterations < 5) {
            next_pos_int = (next_pos_int + 1) % POSITION_HISTORY_AMOUNT;
            iterations += 1;
        }
        
        alpha := time_last_pos / POSITION_HISTORY_UPDATE + decimals;
        if (alpha > 1) {
            alpha       -= 1;
            pos_int      = (pos_int + 1) % POSITION_HISTORY_AMOUNT;
            next_pos_int = (next_pos_int + 1) % POSITION_HISTORY_AMOUNT;
        }

        minion.position.x = interpolate.linear_f32(alpha, player.pos_history[pos_int].x, player.pos_history[next_pos_int].x);
        minion.position.y = interpolate.linear_f32(alpha, player.pos_history[pos_int].y, player.pos_history[next_pos_int].y);
        minion.position.z = interpolate.linear_f32(alpha, player.pos_history[pos_int].z, player.pos_history[next_pos_int].z);
        
        time_last_pos = player.pos_history[pos_int] == last_pos_ckecked ? time_last_pos + delta_seconds() : 0;
        last_pos_ckecked = player.pos_history[pos_int];
        /*
        alignment  = ZERO_2D;
        cohesion   = ZERO_2D;
        separation = ZERO_2D;

        for j in 0..< player.ammo { 
            if(i == j) { continue; }
            other := entity_data(player.minions[j].entity);

            dir := other.position - position;
            // alignment
            distance := linalg.length(dir);
            alpha    := (distance - 10) / (-10);
            
            alignment += player.minions[j].movement.direction * linalg.lerp(alpha, 1, 0);
            
            // cohesion
            alpha = (distance - 100) / (-100);
            alpha = linalg.lerp(alpha, 1, 0);
            
            cohesion.x += linalg.lerp(alpha, position.x, other.position.x); 
            cohesion.y += linalg.lerp(alpha, position.y, other.position.y); 

            // separation
            alpha = (distance - 1.5) / (-1.5);
            alpha = linalg.lerp(alpha, 1, 0);
            
            separation.x += linalg.lerp(alpha, 0, dir.x); 
            separation.y += linalg.lerp(alpha, 0, dir.y); 
        }
        alignment = alignment / (f32)(player.ammo);
        if (alignment.x != 0 || alignment.y != 0) {
            alignment = linalg.vector_normalize(alignment) * minion_alignment;
        }

        cohesion = cohesion / (f32)(player.ammo) - position.xy;
        if (cohesion.x != 0 || cohesion.y != 0) {
            cohesion = linalg.vector_normalize(cohesion) * minion_cohesion;
        }
         
        separation = -separation / (f32)(player.ammo);
        if (separation.x != 0 || separation.y != 0) {
            separation = linalg.vector_normalize(separation) * minion_separation;
        }

        random := v2{ (rand.float32() - 0.5) * 2, (rand.float32() - 0.5) * 2 } 
        leader_direction := linalg.normalize(player_entity.position - position);
        new_dir := direction + alignment + cohesion + separation + leader_direction.xy;
        if (new_dir.x != 0 || new_dir.y != 0) {
            direction = linalg.vector_normalize(new_dir);
        }
        else {
            direction = new_dir;
        }

        position.xy += direction * speed * delta_seconds();  

        /*
        leader_direction := linalg.vector_normalize(player_entity.position - position);
        direction = linalg.vector_normalize(direction + leader_direction.xy);


        position.xy += direction * speed * delta_seconds();
        */
        */
    }
}