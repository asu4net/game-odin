package game
import "core:math"
import "core:fmt"

Blink :: struct {
    enabled    : bool,
    duration   : f32,
    tint       : v4,
    progress   : f32,
    start_tint : v4,
}

DEFAULT_BLINK : Blink : {
    duration   = 0.25,
    tint       = V4_COLOR_RED,
}

draw_2d_entities :: proc() {
    
    width, height := window_get_size()
    
    scene : Scene2D = {
        camera = DEFAULT_CAMERA,
        window_width = f32(width),
        window_height = f32(height)   
    }
        
    scene_2d_begin(scene)

    for handle in entity_get_group(GROUP_FLAGS_SPRITE) {
        
        entity := entity_data(handle)
        
        // VFX handle
        {
            using entity.blink
            
            if enabled {

                if progress == 0 {
                    start_tint = entity.tint
                }

                progress += delta_seconds()
                progress = math.clamp(progress, 0.0, duration)
                normalized_progress := progress / duration
                entity.tint = interp_linear_v4(normalized_progress, start_tint, tint) 
                
                if normalized_progress == 1 {
                    new_target := start_tint
                    start_tint = tint 
                    tint       = new_target
                    progress   = 0
                }
            }
        }

        draw_sprite_atlas_item(entity.transform, entity.sprite, entity.tint, entity.id)
    }

    for handle in entity_get_group(GROUP_FLAGS_CIRCLE) {
        
        entity := entity_data(handle)
        draw_circle(entity.transform, entity.circle, entity.tint, entity.id)
    }

    scene_2d_end() 
}

draw_2d_particles :: proc() {
    width, height := window_get_size()
    
    scene : Scene2D = {
        camera = DEFAULT_CAMERA,
        window_width = f32(width),
        window_height = f32(height)   
    }
        
    scene_2d_begin(scene)

    for handle in particle_get_group() {
        
        particle := particle_data(handle)

        draw_sprite_atlas_item(particle.transform, particle.sprite, particle.color, particle.id)
    }

    scene_2d_end() 
}