package game
import "core:math"
import "core:math/linalg"
import "engine:global/color"


HomingState :: enum {
    IDLE,
    WAITING,
    ATTACK,
}

HomingMissile :: struct {
    state               : HomingState,
    attack_dir          : v3, 
    wait_timer          : f32,
    blink_timer         : f32,

    distance_to_attack  : f32,
    wait_time           : f32, 
    blink_time          : f32, 
    approach_speed      : f32, 
    attack_speed        : f32, 
}

DEFAULT_HOMING_MISSILE : HomingMissile : {
    state              = HomingState.IDLE,
    attack_dir         = ZERO_3D, 
    wait_timer         = 0,
    blink_timer        = 0,

    distance_to_attack = HOMING_MISSILE_DISTANCE_TO_ATTACK,
    wait_time          = HOMING_MISSILE_WAIT_TIME,
    blink_time         = HOMING_MISSILE_BLINK_TIME,
    approach_speed     = HOMING_MISSILE_APPROACH_SPEED, 
    attack_speed       = HOMING_MISSILE_ATTACK_SPEED, 

}

homing_missile_prefab  : Entity_Handle;
homing_missile_spawner : Spawner; 

homing_missile_init :: proc() {
    
    // MISSILE
    {
        handle, entity := entity_create(NAME_HOMING_MISSILE, GROUP_FLAGS_HOMING_MISSILE);
        using entity;
        sprite.item                   = .Kamikaze_Skull;
        collision_radius              = HOMING_MISSILE_RADIUS;
        movement_2d.speed_min         = HOMING_MISSILE_APPROACH_SPEED;
        movement_2d.speed_max         = HOMING_MISSILE_APPROACH_SPEED;
        movement_2d.time_to_max_speed = 1;
        collision_flag                = CollisionFlag.enemy;
        collides_with                 = { .player, .player_bullet };
        collides_with                 = { .player, .player_bullet };
        damage_target.life            = HOMING_MISSILE_LIFE;
        homing_missile_prefab         = handle;
        blink.tint                    = color.WHITE;

        emitter_handle, emitter_data := emitter_create();
        entity.particle_emitter       = emitter_handle;
        emitter_data.position         = entity.position;
        emitter_data.scale            = v3{  0.2,  0.2, 0.2 };
        emitter_data.color            = v4{    1,  0.2, 0.2, 1 };
        emitter_data.pos_amplitude    = v3{ 0.05, 0.05,   0 };
        emitter_data.vel_amplitude    = v3{  0.4,  0.4,   0 };  

        entity_remove_flags(handle, { .ENABLED });
    }
    
    // POINTER LINE
    line_handle, line_entity := entity_create("NAME_POINTER_LINE", GROUP_FLAGS_POINTER_LINE);
    {
        using line_entity;
        sprite.item         = nil; // appear white
        scale.y             = 0.05;
        tint                = color.RED;

        entity_remove_flags(line_handle, { .GLOBAL_ENABLED });
    
    }

    entity_set_parent(line_handle, homing_missile_prefab);

    spawner_init(&homing_missile_spawner, homing_missile_prefab, UP_3D * 3);
    spawn(&homing_missile_spawner);
} 

homing_missile_finish :: proc() {
    assert(&homing_missile_spawner != nil);
    spawner_finish(&homing_missile_spawner);
}

homing_missile_collision :: proc(source : ^Entity, target : ^Entity) {
    if .player_bullet == source.collision_flag {
        entity_destroy({ id = target.id });
    }
}


homing_missile_update :: proc() {

    if !DEBUG_AI_MOVEMENT_ENABLED {
        return;
    }
    for handle in entity_get_group(GROUP_FLAGS_HOMING_MISSILE) { 

        if !entity_valid(handle) {
            continue;
        }
        entity := entity_data(handle);
        using entity;

        player_position := entity_data(game.player.entity).position;

        pointer_data : ^Entity = nil;
        if(entity_valid(children[0])) { 
            pointer_data = entity_data(children[0]);
            pointer_data.pointer_line.dir = -UP_3D;
        }

        switch homing_missile.state {
            case HomingState.IDLE: {
                movement_2d.start = true;
                movement_2d.target = entity_data(game.player.entity).position;
                
                dir := player_position - position;
                distance : f32 = linalg.vector_length(dir);
                angle := -math.to_degrees(linalg.atan2(dir.y, dir.x)) - 90;
                
                rotation.z = angle;
                if distance <= homing_missile.distance_to_attack { 
                    homing_missile.state = HomingState.WAITING;
                }

                emitter_data := emitter_data(particle_emitter);
                emitter_data.velocity = ((position - player_position) / distance) * homing_missile.approach_speed;
                emitter_data.active = emitter_data.velocity != ZERO_3D;
                emitter_data.position = position;
                
                if entity_valid(children[0]) {
                    // doesn't really work yet, group shenanigans
                    homing_missile.blink_timer += delta_seconds();
                    if(homing_missile.blink_timer > homing_missile.blink_time) {
                        homing_missile.blink_timer = 0;
                        if(.ENABLED in pointer_data.flags) {
                            entity_remove_flags(children[0], { .ENABLED }); 
                        } 
                        else {
                            entity_add_flags(children[0], { .ENABLED }); 
                        }
                    }
                    
                    pointer_data.scale.x = distance;
                }
            }
            case HomingState.WAITING: {
                movement_2d.start = false;

                dir := player_position - position;
                angle := -math.to_degrees(linalg.atan2(dir.y, dir.x)) - 90;
                rotation.z = angle;
                
                homing_missile.wait_timer += delta_seconds();
                if homing_missile.wait_timer >= homing_missile.wait_time {
                    homing_missile.attack_dir = linalg.vector_normalize(player_position - transform.position);
                    homing_missile.state = HomingState.ATTACK;
                }
                
                if entity_valid(children[0]) {
                    distance : f32 = linalg.vector_length(dir);
                    pointer_data.scale.x = distance;
                }
                
            }
            case HomingState.ATTACK: {
                blink.enabled = false;
                position += homing_missile.attack_dir * homing_missile.attack_speed * delta_seconds();

                emitter_data := emitter_data(particle_emitter);
                emitter_data.velocity = (-position + emitter_data.position) / delta_seconds();
                emitter_data.active = emitter_data.velocity != ZERO_3D;
                emitter_data.position = position;
                // Explode after a set time?
                
                if entity_valid(children[0]) {
                    pointer_data.scale.x = 1000;
                }
            }
        }
    }
}

