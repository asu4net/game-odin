package game
import "core:fmt"
import "core:math/linalg"
import "core:math"

KamikazeState :: enum {
    IDLE,
    ATTACK,
}

KamikazeSkull :: struct {
    state         : KamikazeState,
    idle_time     : f32,
    attack_target : v3, 
    attack_cd     : f32,
    saw           : Entity_Handle,
}

KamikazeSaw :: struct {
    kamikaze_skull : Entity_Handle
}

DEFAULT_KAMIKAZE_SKULL : KamikazeSkull : {
    attack_cd = KAMIKAZE_ATTACK_CD
}

KamikazeManager :: struct {
    current_score : f32,
    cooldown      : f32,
    skull_prefab  : Entity_Handle,  
    saw_prefab    : Entity_Handle,
    spawner       : Spawner
}

DEFAULT_KAMIKAZE_MANAGER : KamikazeManager : { 
    cooldown = KAMIKAZE_ATTACK_CD
}

@(private = "file")
kamikaze_manager_instance : ^KamikazeManager = nil

kamikaze_manager_init :: proc(instance : ^KamikazeManager) {
    assert(kamikaze_manager_instance == nil)
    kamikaze_manager_instance = instance
    using kamikaze_manager_instance
    
    // SKULL
    {
        handle, entity := entity_create(NAME_KAMIKAZE, GROUP_FLAGS_KAMIKAZE)
        {
            using entity
            sprite.item                   = .Kamikaze_Skull
            kamikaze.attack_cd            = KAMIKAZE_ATTACK_CD
            movement_2d.speed_min         = KAMIKAZE_SPEED_MIN
            movement_2d.speed_max         = KAMIKAZE_SPEED_MAX
            movement_2d.time_to_max_speed = KAMIKAZE_ACC
            collision_flag                = CollisionFlag.enemy;
            collides_with                 = { .player, .player_bullet };
            damage_target.life            = KAMIKAZE_LIFE
            skull_prefab                  = handle

            /*
            emitter_handle, emitter_data := emitter_create();
            entity.particle_emitter = emitter_handle;
            emitter_data.position = entity.position;
            emitter_data.pos_amplitude = v3{0.05,0.05,0};
            emitter_data.vel_amplitude = V3_ZERO;
            emitter_add_texture(emitter_handle, .Kamikaze_Skull)
            emitter_add_texture(emitter_handle, .Kazmikaze_Saw)
            */

            entity_remove_flags(handle, {.ENABLED})
        }
        
    }

    // SAW
    {
        handle, entity := entity_create(NAME_KAMIKAZE_SAW, GROUP_FLAGS_KAMIKAZE_SAW)
        saw_prefab = handle
        entity.transform.position = V3_UP
        entity.sprite.item = .Kazmikaze_Saw
        entity.kamikaze_saw.kamikaze_skull = skull_prefab
        entity_data(skull_prefab).kamikaze.saw = handle
        entity_remove_flags(handle, {.ENABLED})
    }

    spawner_init(&spawner, skull_prefab, V3_UP * 3)
    spawn(&spawner)
}

kamikaze_finish :: proc() {
    assert(kamikaze_manager_instance != nil)
    spawner_finish(&kamikaze_manager_instance.spawner)
}

kamikaze_collision :: proc(source : ^Entity, target : ^Entity) {
    if .player_bullet == source.collision_flag {
        entity_destroy({ id = target.id })
    }
}

kamikaze_manager_update :: proc() {
    
    assert(kamikaze_manager_instance != nil)
    using kamikaze_manager_instance

    // Saw follows skull
    for handle in entity_get_group(GROUP_FLAGS_KAMIKAZE_SAW) {
        entity := entity_data(handle)
        entity.rotation.z -= KAMIKAZE_SAW_SPEED * delta_seconds()
        skull := entity.kamikaze_saw.kamikaze_skull
        
        if !entity_exists(skull) || !entity_valid(skull) {
            entity_destroy(handle)
            continue
        }
        
        entity.transform.position = entity_data(entity.kamikaze_saw.kamikaze_skull).transform.position
    }

    if !DEBUG_AI_MOVEMENT_ENABLED {
        return
    }

    for handle in entity_get_group(GROUP_FLAGS_KAMIKAZE) {
        
        entity := entity_data(handle)

        /*
        emitter_data := emitter_data(entity.particle_emitter);
        // no () on purpose, effect goes hard
        emitter_data.velocity = entity.position - emitter_data.position * 2;
        emitter_data.active = emitter_data.velocity != V3_ZERO;
        emitter_data.position = entity.position;
        */
        
        switch entity.kamikaze.state {
            
            case .IDLE: {
                entity.kamikaze.idle_time += delta_seconds()
                if entity.kamikaze.idle_time >= entity.kamikaze.attack_cd {
                    entity.kamikaze.idle_time = 0
                    entity.movement_2d.start = true
                    entity.movement_2d.target = entity_data(game.player.entity).position
                    entity.kamikaze.state = .ATTACK
                }
            }
            case .ATTACK: {
                if entity.position == entity.movement_2d.target {
                    entity.kamikaze.state = .IDLE
                }
            }
        }
    }
}