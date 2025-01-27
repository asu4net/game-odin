package game

import "core:fmt"
import "core:c"
import "vendor:OpenGL"
import "core:math"
import "core:math/linalg"

/////////////////////////////
//:Primitives2D
/////////////////////////////

VERTICES_PER_2D_PRIMITIVE   :: 4
INDICES_PER_2D_PRIMITIVE    :: 6

V4Verts2D :: [VERTICES_PER_2D_PRIMITIVE] v4
V2Verts2D :: [VERTICES_PER_2D_PRIMITIVE] v2

DEFAULT_VERTEX_POSITIONS_2D : V4Verts2D : {
    {-0.5, -0.5, 0.0, 1.0 }, // bottom-left
    { 0.5, -0.5, 0.0, 1.0 }, // bottom-right
    { 0.5,  0.5, 0.0, 1.0 }, // top-right
    {-0.5,  0.5, 0.0, 1.0 }  // top-left
}

DEFAULT_VERTEX_UVS_2D : V2Verts2D : {
    { 0.0, 0.0 }, // bottom-left
    { 1.0, 0.0 }, // bottom-right
    { 1.0, 1.0 }, // top-right
    { 0.0, 1.0 }  // top-left
}

DEFAULT_VERTEX_COLORS_2D : V4Verts2D : {
    { 1.0, 1.0, 1.0, 1.0 }, // bottom-left
    { 1.0, 1.0, 1.0, 1.0 }, // bottom-right
    { 1.0, 1.0, 1.0, 1.0 }, // top-right
    { 1.0, 1.0, 1.0, 1.0 }  // top-left
}

transform_vertex_positions :: proc(vertex_positions : ^V4Verts2D, transform : m4) {
    vertex_positions[0] = transform * vertex_positions[0]
    vertex_positions[1] = transform * vertex_positions[1]
    vertex_positions[2] = transform * vertex_positions[2]
    vertex_positions[3] = transform * vertex_positions[3]    
}

fill_quad_vertex_positions :: proc(vertex_positions : ^V4Verts2D, size : v2) {
    
    pos := linalg.normalize(size) / 2.0;
    vertex_positions[0] = { -pos.x, -pos.y, 0.0, 1.0 };
    vertex_positions[1] = {  pos.x, -pos.y, 0.0, 1.0 };
    vertex_positions[2] = {  pos.x,  pos.y, 0.0, 1.0 };
    vertex_positions[3] = { -pos.x,  pos.y, 0.0, 1.0 };
}

flip_quad_vertex_uv :: proc(vertex_uvs : ^V2Verts2D, flip_x : bool, flip_y : bool) {
    uv := vertex_uvs
    if flip_x && flip_y {
        vertex_uvs[0] = uv[3]
        vertex_uvs[1] = uv[2]
        vertex_uvs[2] = uv[1]
        vertex_uvs[3] = uv[0]
        return
    }
    if flip_x {
        vertex_uvs[0] = uv[1]
        vertex_uvs[1] = uv[0]
        vertex_uvs[2] = uv[3]
        vertex_uvs[3] = uv[2]
        return
    }
    if flip_y {
        vertex_uvs[0] = uv[2]
        vertex_uvs[1] = uv[3]
        vertex_uvs[2] = uv[0]
        vertex_uvs[3] = uv[1]
        return
    }
}

fill_quad_vertex_uvs :: proc(vertex_uvs : ^V2Verts2D, flip_x : bool, flip_y : bool, tiling_factor : v2) {
    flip_quad_vertex_uv(vertex_uvs, flip_x, flip_y)
    for i in 1..< VERTICES_PER_2D_PRIMITIVE {
        vertex_uvs[i].x *= tiling_factor.x
        vertex_uvs[i].y *= tiling_factor.y
    }
}

fill_vertex_colors :: proc(vertex_colors : ^V4Verts2D, color : v4) {
    vertex_colors[0] = color
    vertex_colors[1] = color
    vertex_colors[2] = color
    vertex_colors[3] = color
}

fill_sprite_sheet_vertex_uvs :: proc(
    vertex_uvs    : ^V2Verts2D, 
    texture_size  : v2,
    item_size     : v2,
    item_px_pos   : v2,
    flip_x        : bool, 
    flip_y        : bool, 
    tiling_factor : v2
) 
{
    top_right, bottom_left : v2
    
    top_right.x = (item_px_pos.x + item_size.x) * (1 / texture_size.x);
    top_right.y = 1 - ((item_px_pos.y + item_size.y) * (1 / texture_size.y));

    bottom_left.x = item_px_pos.x * (1 / texture_size.x);
    bottom_left.y = 1 - (item_px_pos.y * (1 / texture_size.y));

    vertex_uvs[0] = { bottom_left.x, top_right.y };   // bottom-left
    vertex_uvs[1] = { top_right.x,   top_right.y };   // bottom-right
    vertex_uvs[2] = { top_right.x,   bottom_left.y }; // top-right
    vertex_uvs[3] = { bottom_left.x, bottom_left.y }; // top-left

    fill_quad_vertex_uvs(vertex_uvs, flip_x, flip_y, tiling_factor);
}

/////////////////////////////
//:Renderer 2D
/////////////////////////////

Quad_Vertex :: struct {
    position : v4,
    tint     : v4,
    uv       : v2,
    texture  : i32,
    entity   : i32
}

Renderer2D :: struct {
    white_texture     : Texture2D,
    texture_slots     : [MAX_TEXTURE_SLOTS] i32,
    textures_to_bind  : [MAX_TEXTURE_SLOTS]^Texture2D,
    last_texture_slot : i32,
    projection_view   : m4,
    quad_ibo          : Index_Buffer,
    quad_vao          : Vertex_Array,
    quad_vbo          : Vertex_Buffer,
    quad_batch        : [] Quad_Vertex,
    quad_count        : u32,
    quad_index_count  : u32,
    quad_shader       : Shader,
}

// Should access this through your provided instance
@(private = "file")
renderer_2d : ^Renderer2D

@(private = "file")
assign_texture_slot :: proc(texture : ^Texture2D) -> (texture_slot : i32) {
    if texture == nil {
        texture_slot = 0
        return
    }

    using renderer_2d
    for i in 0..<last_texture_slot {
        if textures_to_bind[i].id == texture.id {
            texture_slot = i
            break
        }
    }
    if texture_slot == 0 {
        if last_texture_slot > MAX_TEXTURE_SLOTS {
            next_batch()
        }
        textures_to_bind[last_texture_slot] = texture
        texture_slot = last_texture_slot
        last_texture_slot += 1
    }
    return
}

renderer_2d_set_instance :: proc(renderer : ^Renderer2D) {
    if (renderer_2d != nil) {
        assert(false)
        return
    }
    renderer_2d = renderer
}

renderer_get_instance :: proc() -> ^Renderer2D {
    return renderer_2d
}

renderer_2d_init :: proc() {
    using renderer_2d
    assert(renderer_2d != nil)

    quad_batch = make([]Quad_Vertex, MAX_2D_PRIMITIVES_PER_BATCH * VERTICES_PER_2D_PRIMITIVE)

    projection_view = M4_IDENTITY
    texture_2d_init_as_white(&white_texture)
    
    textures_to_bind[0] = &white_texture
    last_texture_slot = 1

    for i in 0..<MAX_TEXTURE_SLOTS {
        texture_slots[i] = i32(i)
    }

    shader_init(&quad_shader, .QUAD)

    {
        INDEX_COUNT :: MAX_2D_PRIMITIVES_PER_BATCH * INDICES_PER_2D_PRIMITIVE
        
        indices := make([]u32, INDEX_COUNT) 
        defer delete(indices)
        
        offset : u32 = 0

        for i := 0; i < INDEX_COUNT; i += INDICES_PER_2D_PRIMITIVE {

            indices[i + 0] = offset + 0
            indices[i + 1] = offset + 1
            indices[i + 2] = offset + 2

            indices[i + 3] = offset + 2
            indices[i + 4] = offset + 3
            indices[i + 5] = offset + 0

            offset += VERTICES_PER_2D_PRIMITIVE
        }

        index_buffer_init(&quad_ibo, raw_data(indices), INDEX_COUNT)

        {
            VERTICES :: MAX_2D_PRIMITIVES_PER_BATCH * VERTICES_PER_2D_PRIMITIVE
            vertex_array_init(&quad_vao)
            vertex_buffer_init(&quad_vbo, VERTICES * size_of(Quad_Vertex))
            vertex_buffer_add_layout(&quad_vbo, type = .Float4, name = "a_Position")
            vertex_buffer_add_layout(&quad_vbo, type = .Float4, name = "a_Tint")
            vertex_buffer_add_layout(&quad_vbo, type = .Float2, name = "a_UV")
            vertex_buffer_add_layout(&quad_vbo, type = .Int,    name = "a_Texture")
            vertex_buffer_add_layout(&quad_vbo, type = .Int,    name = "a_EntityID")
            add_vertex_buffer(&quad_vao, &quad_vbo)
            add_index_buffer(&quad_vao, &quad_ibo)
        }
    }
}

renderer_2d_finish :: proc() {
    using renderer_2d
    assert(renderer_2d != nil)
    delete(quad_batch)
    vertex_buffer_finish(&quad_vbo)
    texture_2d_finish(&white_texture)
    shader_finish(&quad_shader)
    renderer_2d^ = {}
}

@(private = "file")
start_batch :: proc() {
    using renderer_2d
    assert(renderer_2d != nil)
    quad_count = 0
    last_texture_slot = 1
    quad_index_count = 0
}

@(private = "file")
flush :: proc() {
    using renderer_2d
    assert(renderer_2d != nil)
    for i in 0..<last_texture_slot {
        texture_2d_bind(textures_to_bind[i], u32(i))
    }
    shader_bind(&quad_shader)
    shader_set_constant_sampler2D(&quad_shader, "u_Textures[0]", cast([^]i32) &texture_slots, MAX_TEXTURE_SLOTS)
    shader_set_constant_m4(&quad_shader, "u_ProjectionView", projection_view)
    vertex_buffer_set_data(&quad_vbo, &quad_batch[0], u64(size_of(Quad_Vertex) * VERTICES_PER_2D_PRIMITIVE * quad_count))
    draw_elements(&quad_vao, quad_index_count)
}

@(private = "file")
next_batch :: proc() {
    flush()
    start_batch()
}

/////////////////////////////
//:Scene2D
/////////////////////////////

Camera :: struct {
    aspect : f32,
    near   : f32,
    far    : f32,
    size   : f32      
}

DEFAULT_CAMERA : Camera : {
    near   = 0.1,
    far    = 1000,
    size   = CAMERA_SIZE
}

Scene2D :: struct {
    camera        : Camera,
    window_width  : f32,
    window_height : f32
}

DEFAULT_SCENE_2D : Scene2D : {
    camera = DEFAULT_CAMERA,
    window_width = WINDOW_WIDTH,
    window_height = WINDOW_HEIGHT
}

scene_2d_begin :: proc(scene : Scene2D = DEFAULT_SCENE_2D) {
    assert(renderer_2d != nil)
    using renderer_2d, scene, scene.camera
    
    set_viewport(u32(window_width), u32(window_height))
    aspect = window_width / window_height
    set_blending_mode(.Alpha)
    set_depth_test_enabled(false)
    set_blending_enabled()

    right      := aspect * size
    left       := -right
    projection := linalg.matrix_ortho3d_f32(left, right, -size, size, near, far)
    view       := linalg.matrix4_look_at_from_fru_f32(V3_FORWARD * -3, V3_FORWARD, V3_RIGHT, V3_UP)
    projection_view = projection * view
    
    start_batch()
}

scene_2d_end :: proc() {
    flush()
}

/////////////////////////////
//:Transform
/////////////////////////////

Transform :: struct {
    position : v3,
    rotation : v3,
    scale    : v3
}

DEFAULT_TRANSFORM : Transform : {
    V3_ZERO, V3_ZERO, V3_ONE
}

/////////////////////////////
//:Sprite
/////////////////////////////

Sprite :: struct {
    texture   : ^Texture2D ,
    tiling    : v2         ,
    flip_x    : bool       ,
    flip_y    : bool       ,
    autosize  : bool       ,
}

DEFAULT_SPRITE : Sprite : {
    texture   = nil,
    tiling    = V2_ONE,
    flip_x    = false,
    flip_y    = false,
    autosize  = true,
}

//#TODO_asuarez add subtextures
draw_sprite :: proc(transform : ^Transform = nil, sprite : ^Sprite = nil, tint : v4 = V4_COLOR_WHITE, entity_id : u32 = 0)
{
    assert(renderer_2d != nil && transform != nil && sprite != nil)
    using renderer_2d, transform, sprite

    assert(quad_count <= MAX_2D_PRIMITIVES_PER_BATCH)

    if quad_count == MAX_2D_PRIMITIVES_PER_BATCH {
        next_batch()
    }

    vertex_positions := DEFAULT_VERTEX_POSITIONS_2D
    vertex_uvs       := DEFAULT_VERTEX_UVS_2D
    vertex_colors    := DEFAULT_VERTEX_COLORS_2D

    fill_vertex_colors(&vertex_colors, tint)

    if texture != nil {
       fill_quad_vertex_uvs(&vertex_uvs, flip_x, flip_y, tiling)
       if autosize {
           fill_quad_vertex_positions(&vertex_positions, {f32(texture.width), f32(texture.height)}) 
       }
    }

    transform_vertex_positions(&vertex_positions, m4_transform(position, rotation, scale))
    
    slot := assign_texture_slot(texture) 

    for i in 0..<VERTICES_PER_2D_PRIMITIVE {
        quad_batch[i + int(quad_count) * VERTICES_PER_2D_PRIMITIVE] = {
            vertex_positions[i], vertex_colors[i], vertex_uvs[i], slot, i32(entity_id)
        }
    }    
    
    quad_index_count += INDICES_PER_2D_PRIMITIVE
    quad_count += 1
}