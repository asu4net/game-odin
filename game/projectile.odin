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
    dir          = V3_UP,
    speed        = 7,
    max_lifetime = 1.0,
}

projectile_init :: proc() {
    
}

projectile_update :: proc(reg : ^Entity_Registry) {

    for handle in entity_get_group({.PROJECTILE}) {
        if !entity_iterable(handle) {
            continue
        }
        entity := entity_data(handle)

        for collision_enter_event in entity.collision_enter {
            entity_destroy(handle)
        }
        
        using entity.projectile, entity.tranform
        curr_lifetime += delta_seconds()
        if curr_lifetime >= max_lifetime {
            entity_destroy(handle)
        }
        position += dir * speed * delta_seconds()
    }
}