package game
import "core:math"
import "core:fmt"
import "engine:global/color"
import "engine:global/matrix4"
import "engine:global/interpolate"
import gfx "engine:graphics"

/////////////////////////////
//:Transform
/////////////////////////////

Transform :: struct {
    position : v3,
    rotation : v3,
    scale    : v3
}

DEFAULT_TRANSFORM : Transform : {
    ZERO_3D, ZERO_3D, ONE_3D
}

transform_to_m4 :: proc(transform : Transform) -> m4 {
    return matrix4.transform(transform.position, transform.rotation, transform.scale)
}

/////////////////////////////
//:Sprite
/////////////////////////////

Sprite :: struct {
    texture   : ^Texture2D    ,
    tiling    : v2                ,
    flip_x    : bool              ,
    flip_y    : bool              ,
    autosize  : bool              ,
    blending  : Blending_Mode ,
}

DEFAULT_SPRITE : Sprite : {
    texture   = nil,
    tiling    = ONE_2D,
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
    tiling   = ONE_2D,
    flip_x   = false,
    flip_y   = false,
    autosize = true,
    blending = .ALPHA,
}

/////////////////////////////
//:FlipBook
/////////////////////////////

FlipBookKey :: struct {
    name : Texture_Name,
    time : f32,
}

FlipBook :: struct {
    keys        : [MAX_FLIPBOOK_KEYS] FlipBookKey,
    key_count   : u32,
    duration    : f32,
    time        : f32,
    current_key : u32,
    playing     : bool,
    loop        : bool,
}

flipbook_create :: proc(flipbook : ^FlipBook, duration : f32 = 1.0, loop := false, items : []Texture_Name = {}) {
    assert(flipbook != nil)

    flipbook.duration = duration
    flipbook.loop = loop
    
    for item, i in items {
        flipbook.keys[i].name = item
        flipbook.key_count += 1
    }
    flipbook_adjust_to_duration(flipbook)
}

flipbook_adjust_to_duration :: proc(flipbook : ^FlipBook) {
    assert(flipbook != nil)
    using flipbook

    if key_count == 0 || duration <= 0 do return
    
    if key_count == 1 {
        keys[0].time = duration
        return
    }

    key_duration := duration / cast(f32) (key_count)
    acc_time : f32

    for i in 0..<key_count {
        acc_time += key_duration 
        keys[i].time = acc_time
    }
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
    tint       = color.RED,
}

Scene2D :: struct {
    draw_2d       : gfx.Draw2D_Context,
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

    gfx.set_clear_color(color.DARK_GRAY)
    gfx.draw_2d_init(&scene2d.draw_2d)
    gfx.texture_2d_init(&atlas_texture, "assets/atlas.png")
}

scene_2d_finish :: proc() {
    assert(scene_2d_initialized())
    using scene2d_instance
    gfx.texture_2d_finish(&atlas_texture)
    gfx.draw_2d_finish()
}

draw_scene_2d :: proc() {

    gfx.clear_screen()
    
    width, height := viewport_size()
    window_size : v2 = { f32(width), f32(height) }

    gfx.draw_2d_begin(viewport = window_size, size = CAMERA_SIZE)
    draw_particles()
    draw_entities()
    draw_collisions()
    gfx.draw_2d_end()
}

@(private = "file")
draw_circle_internal :: proc(transform := DEFAULT_TRANSFORM, circle := DEFAULT_CIRCLE, tint := color.WHITE, entity_id : u32 = 0) {
    gfx.draw_circle(
        transform = transform_to_m4(transform),
        radius    = circle.radius,
        thickness = circle.thickness,
        fade      = circle.fade,
        tint      = tint,
        entity_id = entity_id
    )
}

@(private = "file")
draw_sprite_atlas_item :: proc(transform := DEFAULT_TRANSFORM, sprite := DEFAULT_SPRITE_ATLAS_ITEM, tint := color.WHITE, entity_id : u32 = 0) {

    rect : Rect
    quad_flags := gfx.DEFAULT_QUAD_FLAGS
    
    if sprite.autosize do quad_flags += {.AUTOSIZE}
    if sprite.flip_x   do quad_flags += {.FLIP_X}
    if sprite.flip_y   do quad_flags += {.FLIP_Y}

    texture : ^Texture2D

    if (sprite.item != nil) {
        texture = &scene2d_instance.atlas_texture
        quad_flags += {.USE_SUBTEX}
        rect = atlas_textures[sprite.item].rect
    }

    gfx.draw_quad(
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
        
        // FlipBook handle
        if .FLIPBOOK in entity.flags {
            using entity.flipbook
            if playing && key_count != 0 {
                time += delta_seconds()
                key := keys[current_key]
                if time >= key.time {
                    current_key += 1
                    if current_key == key_count {
                        time = 0
                        current_key = 0
                        if !loop do playing = false
                    }
                }
                entity.item = key.name
            }
        }

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
                entity.tint = interpolate.linear(normalized_progress, start_tint, tint) 
                
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