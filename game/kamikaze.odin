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
    attack_cd     : f32 
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
}

DEFAULT_KAMIKAZE_MANAGER : KamikazeManager : { 
    cooldown = KAMIKAZE_ATTACK_CD
}

@(private = "file")
kamikaze_manager_instance : ^KamikazeManager = nil

spawn_kamikaze :: proc(pos := V3_ZERO, cd : f32 = KAMIKAZE_ATTACK_CD) {

    using kamikaze_manager_instance

    // Skull
    skull : Entity_Handle
    {
        flags := GROUP_FLAGS_KAMIKAZE
        handle, entity := entity_create(NAME_KAMIKAZE, flags)
        skull = handle
        skull_prefab = handle
        entity.sprite.item = .Kamikaze_Skull
        entity.position = pos
        entity.kamikaze.attack_cd = cd
        entity.movement_2d.speed_min = KAMIKAZE_SPEED_MIN
        entity.movement_2d.speed_max = KAMIKAZE_SPEED_MAX
        entity.movement_2d.time_to_max_speed = KAMIKAZE_ACC

        entity.collision_flag = CollisionFlag.enemy;
        entity.collides_with = { .player, .player_bullet };
        
        emitter_handle, emitter_data := emitter_create();
        entity.particle_emitter = emitter_handle;
        emitter_data.position = entity.position;
        emitter_data.pos_amplitude = v3{0.05,0.05,0};
        emitter_data.vel_amplitude = V3_ZERO;
    }

    // Saw
    {
        handle, entity := entity_create(NAME_KAMIKAZE_SAW, GROUP_FLAGS_KAMIKAZE_SAW)
        saw_prefab = handle
        entity.tranform.position = V3_UP
        entity.sprite.item = .Kazmikaze_Saw
        entity.kamikaze_saw.kamikaze_skull = skull
        entity.position = pos
        entity.kamikaze.attack_cd = cd
    }
}

kamikaze_manager_init :: proc(instance : ^KamikazeManager) {
    assert(kamikaze_manager_instance == nil)
    kamikaze_manager_instance = instance
    using kamikaze_manager_instance
    
    // placeholder as fuck
    spawn_kamikaze(V3_UP * 3)
    spawn_kamikaze(V3_UP * 3 + V3_RIGHT * 1, KAMIKAZE_ATTACK_CD + 0.25)
    spawn_kamikaze(V3_UP * 3 + V3_RIGHT * 2, KAMIKAZE_ATTACK_CD + 0.5)
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
        
        entity.tranform.position = entity_data(entity.kamikaze_saw.kamikaze_skull).tranform.position
    }

    if !DEBUG_AI_MOVEMENT_ENABLED {
        return
    }

    // Skull //TODO: Interpolate speed
    for handle in entity_get_group(GROUP_FLAGS_KAMIKAZE) {
        
        entity := entity_data(handle)

        emitter_data := emitter_data(entity.particle_emitter);
        // no () on purpose, effect goes hard
        emitter_data.velocity = entity.position - emitter_data.position * 2;
        emitter_data.active = emitter_data.velocity != V3_ZERO;
        emitter_data.position = entity.position;

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