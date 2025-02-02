package game
import "core:fmt"
import "core:math/linalg"
import "core:math"

KamikazeState :: enum {
    IDLE,
    ATTACK,
}

KamikazeSkull :: struct {
    speed_min     : f32,
    speed         : f32,
    acc           : f32,
    acc_time      : f32,
    state         : KamikazeState,
    idle_time     : f32,
    attack_target : v3, 
    attack_cd     : f32 
}

KamikazeSaw :: struct {
    kamikaze_skull : Entity_Handle
}

DEFAULT_KAMIKAZE_SKULL : KamikazeSkull : {
    speed_min = KAMIKAZE_SPEED_MIN,
    speed     = KAMIKAZE_SPEED,
    acc       = KAMIKAZE_ACC,
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
        handle, data := entity_create(NAME_KAMIKAZE, flags)
        skull = handle
        skull_prefab = handle
        data.sprite.item = .Kamikaze_Skull
        data.position = pos
        data.kamikaze.attack_cd = cd
        
        data.collision_flag = CollisionFlag.enemy;
        data.collides_with = { .player, .player_bullet };
    }

    // Saw
    {
        handle, data := entity_create(NAME_KAMIKAZE_SAW, GROUP_FLAGS_KAMIKAZE_SAW)
        saw_prefab = handle
        data.tranform.position = V3_UP
        data.sprite.item = .Kazmikaze_Saw
        data.kamikaze_saw.kamikaze_skull = skull
        data.position = pos
        data.kamikaze.attack_cd = cd
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

        switch entity.kamikaze.state {
            
            case .IDLE: {
                entity.kamikaze.idle_time += delta_seconds()
                if entity.kamikaze.idle_time >= entity.kamikaze.attack_cd {
                    entity.kamikaze.idle_time = 0
                    entity.kamikaze.attack_target = entity_data(game.player.entity).position
                    entity.kamikaze.acc_time = 0
                    entity.kamikaze.state = .ATTACK
                }
            }
            case .ATTACK: {

                entity.kamikaze.acc_time += delta_seconds()
                entity.kamikaze.acc_time = math.clamp(entity.kamikaze.acc_time, 0.0, entity.kamikaze.acc)
                normalized_time := entity.kamikaze.acc_time / entity.kamikaze.acc
                speed :=  interp_ease_in_expo(normalized_time, entity.kamikaze.speed_min, entity.kamikaze.speed)
                
                delta_speed := speed * delta_seconds()
                distance := linalg.distance(entity.kamikaze.attack_target, entity.position)
                
                if delta_speed >= distance {
                    entity.position = entity.kamikaze.attack_target
                } else {
                    dir := linalg.normalize(entity.kamikaze.attack_target - entity.position)
                    entity.position += dir * delta_speed
                }

                if entity.position == entity.kamikaze.attack_target {
                    entity.kamikaze.state = .IDLE
                }
            }
        }
    }
}