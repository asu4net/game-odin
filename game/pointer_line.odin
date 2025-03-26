package game
import "core:math"
import "core:math/linalg"
import "engine:global/color"

PointerLine :: struct {
    origin_pos : v3,
    dir        : v3
}

is_pointer_line :: proc(entity : ^Entity) -> bool {
    assert(entity_valid({entity.id}));
    return entity.pointer_line.dir != ZERO_3D;
}

DEFAULT_POINTER_LINE : PointerLine : {
    origin_pos = ZERO_3D,
    dir        = RIGHT_3D
}

pointer_line_prefab  : Entity_Handle = { NIL_ENTITY_ID };

pointer_line_init :: proc() {
    
    /*
    handle, entity := entity_create(NAME_POINTER_LINE, GROUP_FLAGS_POINTER_LINE);
    {
        using entity;
        sprite.item         = nil; // appear white
        scale.y             = 0.05;
        tint                = color.RED;
        pointer_line_prefab = handle;

        entity_remove_flags(handle, { .GLOBAL_ENABLED });
    }
    */
} 

pointer_line_finish :: proc() {
    // :p
}

pointer_line_update :: proc() {

    for i in 0..< entity_count() {
        
        entity := entity_at_index(i);
        
        if !entity_enabled({entity.id}) do continue;
        using entity;

        if !is_pointer_line(entity) {
            continue;
        }

        // right is 0º
        if (linalg.vector_length2(pointer_line.dir) > 0) {
            rotation.z = math.to_degrees(math.atan2(pointer_line.dir.y, pointer_line.dir.x));
        }

        // position doesnt care about rotation lol
        transform.position = pointer_line.dir * (scale.x / 2);
    }
}
