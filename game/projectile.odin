package game
import "core:fmt"

//#TODO_asuarez implement object pooling here

Projectile :: struct {
    dir           : v3,
    speed         : f32,
    curr_lifetime : f32,
    max_lifetime  : f32,
}

DEFAULT_PROJECTILE : Projectile : {
    dir          = UP_3D,
    speed        = 7,
    max_lifetime = 1.0,
}

is_projectile :: proc(entity : ^Entity) -> bool {
    assert(entity_valid({entity.id}));
    return entity.projectile.max_lifetime > 0;
}

projectile_collision :: proc(source : ^Entity, target : ^Entity) {
    entity_destroy({ id = target.id })
}

projectile_update :: proc() {
    for i in 0..< entity_count() {
        entity := entity_at_index(i);
        
        if !entity_enabled({entity.id}) do continue;
        
        if !is_projectile(entity) {
            continue;
        }
        entity.projectile.curr_lifetime += delta_seconds();
        if entity.projectile.curr_lifetime >= entity.projectile.max_lifetime {
            entity_destroy({entity.id});
        }
        entity.position += entity.projectile.dir * entity.projectile.speed * delta_seconds();
    }
}