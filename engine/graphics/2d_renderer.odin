package graphics
import "engine:global/matrix4"
import "core:math/linalg"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//:Draw 2D
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Quad_Vertex :: struct {
    position : v4,
    tint     : v4,
    uv       : v2,
    texture  : i32,
    entity   : i32
}

Circle_Vertex :: struct {
    position       : v4,
    local_position : v4,
    tint           : v4,
    thickness      : f32,
    fade           : f32,
    entity         : i32
}

Primitive_Type :: enum {
    nil,
    QUAD,
    CIRCLE
}


Draw2D_Context :: struct {
    white_texture      : Texture2D,
    texture_slots      : [MAX_TEXTURE_SLOTS] i32,
    textures_to_bind   : [MAX_TEXTURE_SLOTS]^Texture2D,
    last_texture_slot  : i32,
    projection_view    : m4,

    curr_blending      : Blending_Mode,
    curr_primitive     : Primitive_Type,

    // Quad
    quad_ibo           : Index_Buffer,
    quad_vao           : Vertex_Array,
    quad_vbo           : Vertex_Buffer,
    quad_batch         : [] Quad_Vertex,
    quad_count         : u32,
    quad_index_count   : u32,
    quad_shader        : Shader,
    
    // Circle
    circle_vao         : Vertex_Array,
    circle_vbo         : Vertex_Buffer,
    circle_batch       : [] Circle_Vertex,
    circle_count       : u32,
    circle_index_count : u32,
    circle_shader      : Shader,
}

@(private = "file")
draw_2d_context : ^Draw2D_Context

@(private = "file")
assign_texture_slot :: proc(texture : ^Texture2D) -> (texture_slot : i32) {
    if texture == nil {
        texture_slot = i32(Default_Texture_Slots.WHITE)
        return
    }

    using draw_2d_context
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

draw_2d_init :: proc(instance : ^Draw2D_Context) {
    assert(draw_2d_context == nil)
    assert(instance != nil)
    
    set_blending_mode(.ALPHA)

    draw_2d_context = instance
    using draw_2d_context

    projection_view = matrix4.IDENTITY
    texture_2d_init_as_white(&white_texture)
    //texture_2d_init(&atlas_texture, "assets/atlas.png")

    textures_to_bind[Default_Texture_Slots.WHITE] = &white_texture
    //textures_to_bind[Default_Texture_Slots.ATLAS] = &atlas_texture
    last_texture_slot = i32(Default_Texture_Slots.COUNT)

    for i in 0..<MAX_TEXTURE_SLOTS {
        texture_slots[i] = i32(i)
    }

    shader_init(&quad_shader, .QUAD)
    shader_init(&circle_shader, .CIRCLE)

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
        
        VERTICES :: MAX_2D_PRIMITIVES_PER_BATCH * VERTICES_PER_2D_PRIMITIVE
        
        // Quad
        {
            quad_batch = make([]Quad_Vertex, VERTICES)
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

        // Circle
        {
            circle_batch = make([]Circle_Vertex, VERTICES)
            vertex_array_init(&circle_vao)
            vertex_buffer_init(&circle_vbo, VERTICES * size_of(Circle_Vertex))
            vertex_buffer_add_layout(&circle_vbo, type = .Float4, name = "a_Position")
            vertex_buffer_add_layout(&circle_vbo, type = .Float4, name = "a_LocalPosition")
            vertex_buffer_add_layout(&circle_vbo, type = .Float4, name = "a_Tint")
            vertex_buffer_add_layout(&circle_vbo, type = .Float,  name = "a_Thickness")
            vertex_buffer_add_layout(&circle_vbo, type = .Float,  name = "a_Fade")
            vertex_buffer_add_layout(&circle_vbo, type = .Int,    name = "a_EntityID")
            add_vertex_buffer(&circle_vao, &circle_vbo)
            add_index_buffer(&circle_vao, &quad_ibo)
        }
    }
}

draw_2d_finish :: proc() {
    using draw_2d_context
    assert(draw_2d_context != nil)
    texture_2d_finish(&white_texture)
    //texture_2d_finish(&atlas_texture)

    delete(quad_batch)
    vertex_buffer_finish(&quad_vbo)
    shader_finish(&quad_shader)
    
    delete(circle_batch)
    vertex_buffer_finish(&circle_vbo)
    shader_finish(&circle_shader)
    
    draw_2d_context^ = {}
}

@(private = "file")
start_batch :: proc() {
    using draw_2d_context
    assert(draw_2d_context != nil)
    
    last_texture_slot = i32(Default_Texture_Slots.COUNT)
    
    quad_count = 0
    quad_index_count = 0
    
    circle_count = 0
    circle_index_count = 0
}

@(private = "file")
flush :: proc() {
    using draw_2d_context
    assert(draw_2d_context != nil)
    
    switch curr_primitive {
        
        case .nil: return
        
        case .QUAD: {
            for i in 0..<last_texture_slot {
                texture_2d_bind(textures_to_bind[i], u32(i))
            }
            shader_bind(&quad_shader)
            shader_set_constant_sampler2D(&quad_shader, "u_Textures[0]", cast([^]i32) &texture_slots, MAX_TEXTURE_SLOTS)
            shader_set_constant_m4(&quad_shader, "u_ProjectionView", projection_view)
            vertex_buffer_set_data(&quad_vbo, &quad_batch[0], u64(size_of(Quad_Vertex) * VERTICES_PER_2D_PRIMITIVE * quad_count))
            draw_elements(&quad_vao, quad_index_count)
        }
        case .CIRCLE: {
            shader_bind(&circle_shader)
            shader_set_constant_m4(&circle_shader, "u_ProjectionView", projection_view)
            vertex_buffer_set_data(&circle_vbo, &circle_batch[0], u64(size_of(Circle_Vertex) * VERTICES_PER_2D_PRIMITIVE * circle_count))
            draw_elements(&circle_vao, circle_index_count)
        }
    }

    curr_primitive = nil
}

@(private = "file")
next_batch :: proc() {
    flush()
    start_batch()
}

draw_2d_begin :: proc(
    viewport : v2  = v2{ 1920, 1080 }, 
    eye      : v3  = v3{ 0, 0, -1 }, 
    size     : f32 = 1, 
    near     : f32 = 0.1,
    far      : f32 = 1000,
    front    : v3  = FRONT_3D,
    right    : v3  = RIGHT_3D,
    up       : v3  = UP_3D,
) {
    assert(draw_2d_context != nil)
    using draw_2d_context
    
    set_viewport(u32(viewport.x), u32(viewport.y))
    aspect := viewport.x / viewport.y
    limit  := aspect * size
    projection := linalg.matrix_ortho3d_f32(-limit, limit, -size, size, near, far)
    view := linalg.matrix4_look_at_from_fru_f32({ 0, 0, -3 }, front, right, up)
    projection_view = projection * view
    
    start_batch()
}

draw_2d_end :: proc() {
    flush()
}

QuadFlag :: enum {
    AUTOSIZE,
    FLIP_X,
    FLIP_Y,
    USE_SUBTEX,
}

QuadFlagSet :: bit_set[QuadFlag]

DEFAULT_QUAD_FLAGS : QuadFlagSet : { .AUTOSIZE }

draw_quad :: proc(
    transform     : m4            = matrix4.IDENTITY,
    texture       : ^Texture2D    = nil,
    tiling        : v2            = { 1, 1 },
    blending      : Blending_Mode = .ALPHA,
    sub_tex_rect  : Rect          = {},
    tint          : v4            = { 1, 1, 1, 1},
    entity_id     : u32           = 0,
    flags         : QuadFlagSet   = DEFAULT_QUAD_FLAGS,
)
{
    assert(draw_2d_context != nil)
    using draw_2d_context

    assert(quad_count <= MAX_2D_PRIMITIVES_PER_BATCH)
    
    if curr_blending != blending {
        next_batch()
        set_blending_mode(blending)
        curr_blending = blending
    }

    if curr_primitive != .nil && curr_primitive != .QUAD {
        next_batch()
    }

    curr_primitive = .QUAD

    if quad_count == MAX_2D_PRIMITIVES_PER_BATCH {
        next_batch()
    }

    vertex_positions := DEFAULT_VERTEX_POSITIONS_2D
    vertex_uvs       := DEFAULT_VERTEX_UVS_2D

    vertex_colors    : V4Verts2D = ---
    fill_vertex_colors(&vertex_colors, tint)

    if texture != nil {

        pixel_width, pixel_height : int

        if .USE_SUBTEX in flags {
            
            pixel_width  = sub_tex_rect.width
            pixel_height = sub_tex_rect.height

            fill_quad_sub_tex_vertex_uvs(
                &vertex_uvs,
                {f32(texture.width), f32(texture.height)},
                {f32(sub_tex_rect.width), f32(sub_tex_rect.height)},
                {f32(sub_tex_rect.x), f32(sub_tex_rect.y)},
                .FLIP_X in flags,
                .FLIP_Y in flags,
                tiling
            )
        } else {

            pixel_width  = int(texture.width)
            pixel_height = int(texture.height)

            fill_quad_vertex_uvs(&vertex_uvs, .FLIP_X in flags, .FLIP_Y in flags, tiling)
        }

        if .AUTOSIZE in flags {
            fill_quad_vertex_positions(&vertex_positions, { f32(pixel_width), f32(pixel_height) })
        }
    }
    
    transform_vertex_positions(&vertex_positions, transform)
    
    slot := assign_texture_slot(texture) 

    for i in 0..<VERTICES_PER_2D_PRIMITIVE {
        quad_batch[i + int(quad_count) * VERTICES_PER_2D_PRIMITIVE] = {
            vertex_positions[i], vertex_colors[i], vertex_uvs[i], slot, i32(entity_id)
        }
    }    
    
    quad_index_count += INDICES_PER_2D_PRIMITIVE
    quad_count += 1
}

draw_circle :: proc(
    transform : m4  = matrix4.IDENTITY,
    radius    : f32 = 0.5,
    thickness : f32 = 0.05,
    fade      : f32 = 0.01,
    tint      : v4  = { 1, 1, 1, 1 }, 
    entity_id : u32 = 0,
)
{
    assert(draw_2d_context != nil)
    using draw_2d_context

    if curr_blending != .ALPHA {
        next_batch()
        set_blending_mode(.ALPHA)
    }
    
    if curr_primitive != .nil && curr_primitive != .CIRCLE {
        next_batch()
    }

    curr_primitive = .CIRCLE

    assert(circle_count <= MAX_2D_PRIMITIVES_PER_BATCH)

    if circle_count == MAX_2D_PRIMITIVES_PER_BATCH {
        next_batch()
    }

    vertex_positions : V4Verts2D = ---
    fill_circle_vertex_positions(&vertex_positions, radius)
    final_thickness := thickness / (radius * 2)

    vertex_colors    : V4Verts2D = ---
    fill_vertex_colors(&vertex_colors, tint)

    transform_vertex_positions(&vertex_positions, transform)
    
    default_vertex_positions := DEFAULT_VERTEX_POSITIONS_2D 
    
    for i in 0..<VERTICES_PER_2D_PRIMITIVE {

        vert := &circle_batch[i + int(circle_count) * VERTICES_PER_2D_PRIMITIVE]
        
        vert.local_position = default_vertex_positions[i]
        vert.position       = vertex_positions[i]
        vert.tint           = vertex_colors[i]
        vert.thickness      = final_thickness
        vert.fade           = fade
        vert.entity         = i32(entity_id)
    }    
    
    circle_index_count += INDICES_PER_2D_PRIMITIVE
    circle_count += 1
}