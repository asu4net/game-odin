package game
import "core:math"
import "core:math/linalg"
import "core:fmt"
import "engine:global/interpolate"
import "engine:global/color"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//:Movement 2D
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Movement2D :: struct {
    start              : bool,
    speed_min          : f32,
    speed_max          : f32,
    time_to_max_speed  : f32,
    speed_progress     : f32,
    target             : v3, 
    //TODO: add function ptr to specify interp proc (probablemente esto te lo comas tú, Fer :3)
}

is_movable :: proc(entity : ^Entity) -> bool {
    assert(entity_valid({entity.id}));
    return entity.movement_2d.speed_max > 0;
}

DEFAULT_MOVEMENT_2D : Movement2D : {
    speed_max = 8,
    time_to_max_speed = 0.7
}

update_entity_movement :: proc() {

    for i in 0..< entity_count() {
        entity := entity_at_index(i);
        
        if !entity_enabled({entity.id}) do continue;
        
        using entity.movement_2d

        if !start {
            continue
        }

        speed_progress += delta_seconds()
        speed_progress = math.clamp(speed_progress, 0.0, time_to_max_speed)
        norm_speed_progress := speed_progress / time_to_max_speed
        speed :=  interpolate.ease_in_expo(norm_speed_progress, speed_min, speed_max)
        delta_traslation := speed * delta_seconds()
        distance := linalg.distance(target, entity.position)
        
        if delta_traslation >= distance {
            entity.position = target
        } else {
            dir := linalg.normalize(target - entity.position)
            entity.position += dir * delta_traslation
        }

        if entity.position == target {
            speed_progress = 0
            speed = 0
            start = false
        }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//:Spawn
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Un spawner crea una cantidad de entidades de un solo tipo en una localización dada
Spawner :: struct {
    template_handle   : Entity_Handle,
    position          : v3,
    amount            : u32,
    points_per_entity : f32, 
    entities          : [dynamic] Entity_Handle,
    // para saber si una entidad ha muerto iterar entities y comprobar su nivel de vida o si se han destruido
}

spawner_init :: proc(spawner : ^Spawner, template : Entity_Handle, position := UP_3D, amount : u32 = 1, points : f32 = 0) {
    assert(spawner != nil)
    assert(entity_valid(template))
    entity_remove_flags(template, { .ENABLED })
    assert(amount > 0)
    spawner.amount = amount
    spawner.template_handle = template
    spawner.entities = make([dynamic] Entity_Handle, 0, spawner.amount)
    spawner.position = position
}

spawner_finish :: proc(spawner : ^Spawner) {
    assert(spawner != nil)
    delete(spawner.entities)
}

spawn :: proc(spawner : ^Spawner) {
    assert(spawner != nil && spawner.amount > 0 && len(&spawner.entities) == 0)
    for i in 0..<spawner.amount {
        handle, entity := entity_clone(spawner.template_handle)
        entity.position = spawner.position
        entity_add_flags(handle, { .ENABLED })
        append_elem(&spawner.entities, handle)
    }
}

// Una ronda crea una cantidad x entidades de x tipos
Wave :: struct {
    spawners : [dynamic] Spawner
}

// Cuando pasa el tiempo o todas las entidades de la ronda son destruidas pasamos a la siguiente
// Cada entidad destruida en una ronda da puntuación
WaveManager :: struct {
    enabled            : bool,
    spawners           : [dynamic] Wave,
    points             : u32,
    current_wave       : u32,
    time_between_waves : f32
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//:Damage
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

DamageSource :: struct {
    damage  : f32    
}

is_damage_source :: proc(entity : ^Entity) -> bool {
    assert(entity_valid({entity.id}));
    return entity.damage_source.damage > 0;
}

DEFAULT_DAMAGE_SOURCE : DamageSource : {
    damage  = 10,
}

DamageTarget :: struct {
    max_life : f32,
    life     : f32,
}

is_damage_target :: proc(entity : ^Entity) -> bool {
    assert(entity_valid({entity.id}));
    return entity.damage_target.max_life > 0;
}

DEFAULT_DAMAGE_TARGET : DamageTarget : {
    max_life = 100,
    life     = 100,
}


damage_collision :: proc(source, target : ^Entity) {
    using source.damage_source, target.damage_target
    life = clamp(life - damage, 0, max_life)
    if DEBUG_PRINT_DAMAGE do fmt.printf("%v did %v of damage to %v. %v life is %v \n", source.name, damage, target.name, target.name, life)
    if life == 0 {
        //TODO: this a placeholder, should send dead event
        if DEBUG_PRINT_DAMAGE do fmt.printf("%v killed %v\n", source.name, target.name)
        
        if target.id == game.player.entity.id {
            game_quit()
            return
        }

        spawn_ammo({target.position.x + 0.1, target.position.y - 0.05, target.position.z});
        spawn_ammo({target.position.x - 0.1, target.position.y - 0.05, target.position.z});
        spawn_ammo({target.position.x,       target.position.y + 0.05, target.position.z});
        entity_destroy({target.id})
    }
}

PickUpType :: enum {
    AMMO,
}

PickUp :: struct {
    magnet_radius : f32,
    type          : PickUpType,
    amount        : u16,

    entity_target : Entity_Handle,
}

DEFAULT_PICK_UP : PickUp : {
    magnet_radius = 2,
    type          = PickUpType.AMMO,
    amount        = AMMO_AMOUNT_PICK_UP,

    entity_target = {NIL_ENTITY_ID},
}

update_pickup_movement :: proc() {

    for i in 0..< entity_count() {
        entity := entity_at_index(i);
        
        if !entity_enabled({entity.id}) do continue;
        if entity.pick_up.magnet_radius <= 0 do continue;
        
        using entity.pick_up;

        if entity.movement_2d.start {
            // after some time destroy

            if(entity_exists(entity_target))
            {
                entity.movement_2d.target = entity_data(entity_target).position;
                continue;
            }
            entity.movement_2d.start = false;
        }
        
        // if multiple players just use the closest one lol
        sqr_distance := linalg.vector_length2(entity_data(game.player.entity).position - entity.position);
        if(sqr_distance < magnet_radius * magnet_radius)
        {
            entity.movement_2d.start = true;
            entity_target = game.player.entity;
        }
    }
}

pickup_collision :: proc(source, target : ^Entity){
    // what the fuck
    if target.id == game.player.entity.id {
        switch(source.pick_up.type)
        {
            case PickUpType.AMMO:
                player_set_ammo(&game.player, game.player.ammo + source.pick_up.amount);
                break;
        }
        entity_destroy({source.id});
    }
}

spawn_ammo :: proc(position : v3) {
    handle, entity := entity_create("Ammo PickUp", { .PICK_UP });

    entity.collider         = DEFAULT_COLLIDER_2D;
    entity.circle           = DEFAULT_CIRCLE;
    entity.pick_up          = DEFAULT_PICK_UP;
    entity.pick_up.type     = PickUpType.AMMO;

    entity.position         = position;
    entity.radius           = AMMO_RADIUS;
    entity.collision_radius = AMMO_COLLISION_RADIUS;
    entity.thickness        = 1;
    entity.tint             = color.YELLOW;
    entity.collision_flag   = CollisionFlag.pick_up;
    entity.collides_with    = { .player };
    entity.movement_2d.speed_min         = KAMIKAZE_SPEED_MIN;
    entity.movement_2d.speed_max         = KAMIKAZE_SPEED_MAX;
    entity.movement_2d.time_to_max_speed = KAMIKAZE_ACC;
}

