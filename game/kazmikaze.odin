package game
import "core:fmt"
import "core:math/linalg"

KamikazeState :: enum {
    IDLE,
    ATTACK,
}

KamikazeSkull :: struct {
    kamikaze_speed         : f32,
    kamikaze_state         : KamikazeState,
    kamikaze_idle_time     : f32,
    kamikaze_attack_target : v3, 
    kamikaze_cd            : f32 
}

KamikazeSaw :: struct {
    kamikaze_skull : Entity_Handle
}

DEFAULT_KAMIKAZE_SKULL : KamikazeSkull : {
    kamikaze_speed = KAMIKAZE_SPEED,
    kamikaze_cd    = KAMIKAZE_ATTACK_CD
}

KamikazeManager :: struct {
    enabled       : bool,
    current_score : f32,
    cooldown      : f32,
    skull_prefab  : Entity_Handle,  
    saw_prefab    : Entity_Handle,  
    skull_tex     : Texture2D,
    saw_tex       : Texture2D,
}

DEFAULT_KAMIKAZE_MANAGER : KamikazeManager : { 
    enabled  = true,
    cooldown = KAMIKAZE_ATTACK_CD
}

spawn_kamikaze :: proc(manager : ^KamikazeManager, pos := V3_ZERO, cd : f32 = KAMIKAZE_ATTACK_CD) {

    // Skull
    skull : Entity_Handle
    {
        handle, data := entity_create("KamikazeSkullPrefab", KAMIKAZE_FLAGS)
        skull = handle
        manager.skull_prefab = handle
        data.sprite.texture = &manager.skull_tex
        data.position = pos
        data.kamikaze_cd = cd
    }

    // Saw
    {
        handle, data := entity_create("KamikazeSawPrefab", KAMIKAZE_SAW_FLAGS)
        manager.saw_prefab = handle
        data.tranform.position = V3_UP
        data.sprite.texture = &manager.saw_tex
        data.kamikaze_skull = skull
        data.position = pos
        data.kamikaze_cd = cd
    }
}

kamikaze_manager_init :: proc(manager : ^KamikazeManager) {
    manager := manager
    texture_2d_init(&manager.saw_tex,   "assets/kazmikaze_saw.png")
    texture_2d_init(&manager.skull_tex, "assets/kamikaze_skull.png")

    // placeholder as fuck
    spawn_kamikaze(manager, V3_UP * 3)
    spawn_kamikaze(manager, V3_UP * 3 + V3_RIGHT * 1, KAMIKAZE_ATTACK_CD + 0.25)
    spawn_kamikaze(manager, V3_UP * 3 + V3_RIGHT * 2, KAMIKAZE_ATTACK_CD + 0.5)
}

kamikaze_manager_update :: proc(manager : ^KamikazeManager) {
    
    // Saw follows skull
    for handle in entity_get_group({.KAMIKAZE_SAW}) {
        entity := entity_data(handle)
        if Entity_Flag.ENABLED not_in entity.flags {
            continue
        }
        entity.rotation.z -= KAMIKAZE_SAW_SPEED * delta_seconds()
        entity.tranform.position = entity_data(entity.kamikaze_skull).tranform.position
    }

    // Skull //TODO: Interpolate speed
    for handle in entity_get_group({.KAMIKAZE}) {
        
        entity := entity_data(handle)
        
        if Entity_Flag.ENABLED not_in entity.flags {
            continue
        }

        switch entity.kamikaze_state {
            
            case .IDLE: {
                entity.kamikaze_idle_time += delta_seconds()
                if entity.kamikaze_idle_time >= entity.kamikaze_cd {
                    entity.kamikaze_idle_time = 0
                    entity.kamikaze_attack_target = entity_data(game.player.entity).position
                    entity.kamikaze_state = .ATTACK
                }
            }
            case .ATTACK: {
                delta_speed := entity.kamikaze_speed * delta_seconds()
                distance := linalg.distance(entity.kamikaze_attack_target, entity.position)
                
                if delta_speed >= distance {
                    entity.position = entity.kamikaze_attack_target
                } else {
                    dir := linalg.normalize(entity.kamikaze_attack_target - entity.position)
                    entity.position += dir * delta_speed
                }

                if entity.position == entity.kamikaze_attack_target {
                    entity.kamikaze_state = .IDLE
                }
            }
        }
    }
}

kamikaze_manager_finish :: proc(manager : ^KamikazeManager) {
    texture_2d_finish(&manager.saw_tex)    
    texture_2d_finish(&manager.skull_tex)    
}