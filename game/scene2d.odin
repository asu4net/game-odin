package game
import "core:math"
import "core:fmt"

/////////////////////////////
//:Sprite
/////////////////////////////

Sprite :: struct {
    texture   : ^Texture2D    ,
    tiling    : v2            ,
    flip_x    : bool          ,
    flip_y    : bool          ,
    autosize  : bool          ,
    blending  : Blending_Mode ,
}

DEFAULT_SPRITE : Sprite : {
    texture   = nil,
    tiling    = V2_ONE,
    flip_x    = false,
    flip_y    = false,
    autosize  = true,
    blending  = .ALPHA
}

/////////////////////////////
//:Sprite Atlas Item
/////////////////////////////

Sprite_Atlas_Item :: struct {
    item      : Texture_Name           ,
    tiling    : v2                     ,
    flip_x    : bool                   ,
    flip_y    : bool                   ,
    autosize  : bool                   ,
    blending  : Blending_Mode ,
}

DEFAULT_SPRITE_ATLAS_ITEM : Sprite_Atlas_Item : {
    item     = nil,
    tiling   = V2_ONE,
    flip_x   = false,
    flip_y   = false,
    autosize = true,
    blending = .ALPHA,
}

/////////////////////////////
//:Circle
/////////////////////////////

Circle :: struct {
    radius    : f32,
    thickness : f32,
    fade      : f32,
}

DEFAULT_CIRCLE : Circle : {
    radius    = 0.5,
    thickness = 0.05,
    fade      = 0.01,
}

/////////////////////////////
//:Blink
/////////////////////////////

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

Scene2D :: struct {
    draw_2d       : Draw2D_Context,
    atlas_texture : Texture2D,
}

@(private = "file")
scene2d_instance : ^Scene2D

scene_2d_initialized :: proc() -> bool {
    return scene2d_instance != nil
}

scene_2d_init :: proc(scene2d : ^Scene2D) {
    assert(!scene_2d_initialized())
    assert(scene2d != nil)
    scene2d_instance = scene2d
    using scene2d_instance

    set_clear_color(V4_COLOR_DARK_GRAY)
    draw_2d_init(&scene2d.draw_2d)
    texture_2d_init(&atlas_texture, "assets/atlas.png")
}

scene_2d_finish :: proc() {
    assert(scene_2d_initialized())
    using scene2d_instance
    texture_2d_finish(&atlas_texture)
    draw_2d_finish()
}

draw_scene_2d :: proc() {

    clear_screen()
    
    width, height := viewport_size()
    window_size : v2 = { f32(width), f32(height) }

    draw_2d_begin(viewport = window_size, size = CAMERA_SIZE)
    draw_particles()
    draw_entities()
    draw_collisions()
    draw_2d_end()
}

@(private = "file")
draw_circle_internal :: proc(transform := DEFAULT_TRANSFORM, circle := DEFAULT_CIRCLE, tint := V4_COLOR_WHITE, entity_id : u32 = 0) {
    draw_circle(
        transform = transform_to_m4(transform),
        radius    = circle.radius,
        thickness = circle.thickness,
        fade      = circle.fade,
        tint      = tint,
        entity_id = entity_id
    )
}

@(private = "file")
draw_sprite_atlas_item :: proc(transform := DEFAULT_TRANSFORM, sprite := DEFAULT_SPRITE_ATLAS_ITEM, tint := V4_COLOR_WHITE, entity_id : u32 = 0) {

    rect : Rect
    quad_flags := DEFAULT_QUAD_FLAGS
    
    if sprite.autosize do quad_flags += {.AUTOSIZE}
    if sprite.flip_x   do quad_flags += {.FLIP_X}
    if sprite.flip_y   do quad_flags += {.FLIP_Y}

    texture : ^Texture2D

    if (sprite.item != nil) {
        texture = &scene2d_instance.atlas_texture
        quad_flags += {.USE_SUBTEX}
        rect = atlas_textures[sprite.item].rect
    }

    draw_quad(
        transform    = transform_to_m4(transform),
        texture      = texture,
        tiling       = sprite.tiling,
        blending     = sprite.blending,
        sub_tex_rect = rect,
        tint         = tint,
        entity_id    = entity_id,
        flags        = quad_flags,
    )
}

@(private = "file")
draw_entities :: proc() {

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

        rect : Rect
        draw_sprite_atlas_item(entity.transform, entity.sprite, entity.tint, entity.id)
    }

    for handle in entity_get_group(GROUP_FLAGS_CIRCLE) {
        
        entity := entity_data(handle)
        draw_circle_internal(entity.transform, entity.circle, entity.tint, entity.id)
    }
}

@(private = "file")
draw_particles :: proc() {    
    for handle in particle_get_group() {
        
        particle := particle_data(handle)
        draw_sprite_atlas_item(particle.transform, particle.sprite, particle.color, particle.id)
    }
}

@(private = "file")
draw_collisions :: proc() {
    
    using collisions_2d_instance

    if !DEBUG_DRAW_COLLIDERS {
        return
    }

    for handle in entity_get_group(GROUP_FLAGS_COLLIDER_2D) {
        
        entity := entity_data(handle)
        
        circle : Circle = DEFAULT_CIRCLE
        circle.radius = entity.collision_radius
        
        if handle in collisions_map {
            collides_with := collisions_map[handle] 
            if len(collides_with) == 0 {
                draw_circle_internal(entity.transform, circle, entity.collision_tint, entity.id)
            } else {
                draw_circle_internal(entity.transform, circle, {1, 0, 0, 1}, entity.id)
            }
        }
    }
}