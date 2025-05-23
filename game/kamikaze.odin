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
}

is_kamikaze :: proc(entity : ^Entity) -> bool {
    assert(entity_valid({entity.id}));
    return entity.kamikaze.attack_cd > 0;
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
        handle, entity := entity_create(NAME_KAMIKAZE);
        {
            using entity
            sprite                        = DEFAULT_SPRITE_ATLAS_ITEM;
            kamikaze                      = DEFAULT_KAMIKAZE_SKULL;
            movement_2d                   = DEFAULT_MOVEMENT_2D;
            damage_target                 = DEFAULT_DAMAGE_TARGET;
            damage_source                 = DEFAULT_DAMAGE_SOURCE;
            collider                      = DEFAULT_COLLIDER_2D;

            sprite.item                   = .Kamikaze_Skull;
            kamikaze.attack_cd            = KAMIKAZE_ATTACK_CD;
            movement_2d.speed_min         = KAMIKAZE_SPEED_MIN;
            movement_2d.speed_max         = KAMIKAZE_SPEED_MAX;
            movement_2d.time_to_max_speed = KAMIKAZE_ACC;
            collision_flag                = CollisionFlag.enemy;
            collides_with                 = { .player, .player_bullet };
            damage_target.life            = KAMIKAZE_LIFE;
            skull_prefab                  = handle;

            emitter_handle, emitter_data := emitter_create();
            entity.particle_emitter = emitter_handle;
            emitter_data.position = entity.position;
            emitter_data.scale = v3{ 0.2, 0.2, 0.2 };
            emitter_data.color = v4{ 1, 0.2, 0.2, 1 };
            emitter_data.pos_amplitude = v3{0.05,0.05,0};
            emitter_data.vel_amplitude = ZERO_3D;            

            entity_remove_flags(handle, {.ENABLED})
        }
        
    }
    
    // SAW
    {
        handle, entity := entity_create(NAME_KAMIKAZE_SAW)
        entity.sprite = DEFAULT_SPRITE_ATLAS_ITEM;
        saw_prefab = handle
        entity.transform.position = ZERO_3D
        entity.sprite.item = .Kazmikaze_Saw
        entity_remove_flags(handle, {.GLOBAL_ENABLED})
    }

    entity_set_parent(saw_prefab, skull_prefab);
    spawner_init(&spawner, skull_prefab, UP_3D * 3)
    //spawn(&spawner)
}

kamikaze_finish :: proc() {
    assert(kamikaze_manager_instance != nil)
    spawner_finish(&kamikaze_manager_instance.spawner)
}

kamikaze_manager_update :: proc() {
    
    assert(kamikaze_manager_instance != nil)
    using kamikaze_manager_instance

    if !DEBUG_AI_MOVEMENT_ENABLED {
        return
    }

    for i in 0..< entity_count() {
        
        entity := entity_at_index(i);
        
        if !entity_enabled({entity.id}) do continue;
        
        if !is_kamikaze(entity) {
            continue;
        }
        
        // saw management
        children := entity_get_children({entity.id});
        assert(len(children) > 0);
        saw := entity_data(children[0]);
        saw.rotation.z -= KAMIKAZE_SAW_SPEED * delta_seconds()

        emitter_data := emitter_data(entity.particle_emitter);
        // no () on purpose, effect goes hard
        emitter_data.velocity = entity.position - emitter_data.position * 2;
        emitter_data.active = emitter_data.velocity != ZERO_3D;
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