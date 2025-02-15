package game

import "core:strings"
import "core:c"
import "core:math/linalg"

import gl "vendor:OpenGL"
import stb "vendor:stb/image"
import "engine:global/matrix4"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//:Graphics API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Blending_Mode :: enum {
    nil,
    ALPHA,
    SOLID,
    ADD,
    MULTIPLY
}

Shader_Data_Type :: enum {
    None, Float, Float2, Float3, Float4, Mat3, Mat4, Int, Sampler2D, Int2, Int3, Int4, Bool
}

shader_data_type_from_gl :: proc(type: c.int) -> Shader_Data_Type {
    switch type
    {
        case gl.FLOAT      : return Shader_Data_Type.Float
        case gl.FLOAT_VEC2 : return Shader_Data_Type.Float2
        case gl.FLOAT_VEC3 : return Shader_Data_Type.Float3
        case gl.FLOAT_VEC4 : return Shader_Data_Type.Float4
        case gl.FLOAT_MAT3 : return Shader_Data_Type.Mat3
        case gl.FLOAT_MAT4 : return Shader_Data_Type.Mat4
        case gl.INT        : return Shader_Data_Type.Int
        case gl.INT_VEC2   : return Shader_Data_Type.Int2
        case gl.INT_VEC3   : return Shader_Data_Type.Int3
        case gl.INT_VEC4   : return Shader_Data_Type.Int4
        case gl.SAMPLER_2D : return Shader_Data_Type.Sampler2D
        case gl.BOOL       : return Shader_Data_Type.Bool
    }
    return Shader_Data_Type.None
}

shader_data_type_to_gl :: proc(type: Shader_Data_Type) -> u32 {
    switch type
    {
        case .Float     : return gl.FLOAT
        case .Float2    : return gl.FLOAT
        case .Float3    : return gl.FLOAT
        case .Float4    : return gl.FLOAT
        case .Mat3      : return gl.FLOAT
        case .Mat4      : return gl.FLOAT
        case .Int       : return gl.INT
        case .Int2      : return gl.INT
        case .Int3      : return gl.INT
        case .Int4      : return gl.INT
        case .Sampler2D : return gl.SAMPLER_2D
        case .Bool      : return gl.BOOL
        case .None      : return 0
    }
    return 0
}

shader_data_type_to_size :: proc(type: Shader_Data_Type) -> u32 {
    switch type {
        case .Float     : return 4;         
        case .Float2    : return 4 * 2;
        case .Float3    : return 4 * 3;
        case .Float4    : return 4 * 4;
        case .Mat3      : return 4 * 3 * 3;
        case .Mat4      : return 4 * 4 * 4;
        case .Int       : return 4;
        case .Sampler2D : return 32;
        case .Int2      : return 4 * 2;
        case .Int3      : return 4 * 3;
        case .Int4      : return 4 * 4;
        case .Bool      : return 1;
        case .None      : return 0;
    }
    return 0
}

shader_data_type_to_count :: proc(type: Shader_Data_Type) -> i32 {
    switch type {
        case .Float     : return 1;         
        case .Float2    : return 2;
        case .Float3    : return 3;
        case .Float4    : return 4;
        case .Mat3      : return 3 * 3;
        case .Mat4      : return 4 * 4;
        case .Int       : return 1;
        case .Sampler2D : return 32;
        case .Int2      : return 2;
        case .Int3      : return 3;
        case .Int4      : return 4;
        case .Bool      : return 1;
        case .None      : return 0;
    }
    return 0
}

set_viewport :: proc(width: u32, height: u32, x: u32 = 0, y: u32 = 0) {
    gl.Viewport(i32(x), i32(y), i32(width), i32(height))
}

set_clear_color_scalar :: proc(r: f32, g: f32, b: f32, a: f32) {
    gl.ClearColor(r, g, b, a)
}

set_clear_color_v4 :: proc(v: v4) {
    set_clear_color_scalar(v.x, v.y, v.z, v.w)
}

set_clear_color :: proc{set_clear_color_scalar, set_clear_color_v4}

clear_screen :: proc() {
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
}

set_blending_enabled :: proc(enabled: b32 = true) {
    if enabled
    {
        gl.Enable(gl.BLEND);
        return
    }

    gl.Disable(gl.BLEND)
}

set_blending_mode :: proc(blending_mode : Blending_Mode) {
    set_blending_enabled()
    switch blending_mode
    {
        case .nil:
             assert(false) 
            return
        case .SOLID:
            gl.BlendFunc(gl.ONE, gl.ZERO)                
            return
        case .ALPHA:
            gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA) 
            return
        case .ADD:
            gl.BlendFunc(gl.SRC_ALPHA, gl.ONE)                 
            return
        case .MULTIPLY: 
            gl.BlendFuncSeparate(gl.DST_COLOR, gl.ONE, gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)                
            return
    }
}

set_depth_test_enabled :: proc(enabled : b8 = true) {
    if enabled {
        gl.Enable(gl.DEPTH_TEST)
        return
    }
    gl.Disable(gl.DEPTH_TEST)
}

draw_elements :: proc(vao : ^Vertex_Array, element_count : u32) {
    vertex_array_bind(vao)
    gl.DrawElements(gl.TRIANGLES, i32(element_count), gl.UNSIGNED_INT, nil)
    vertex_array_unbind(vao)
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//:Buffer Objects
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/////////////////////////////
//:Vertex Buffer
/////////////////////////////

Vertex_Buffer :: struct {
    id : u32,
    layout : Buffer_Layout
}

Buffer_Element :: struct {
    type : Shader_Data_Type,
    name : string,
    normalized : b32,
    size : u32,
    offset : u32
}

Buffer_Layout :: struct {
    elements : [dynamic] Buffer_Element,
    stride : u32
}

vertex_buffer_add_layout :: proc(vertex_buffer : ^Vertex_Buffer, type : Shader_Data_Type, name : string, normalized : b32 = false) {
    
    layout := &vertex_buffer.layout;
    
    element : Buffer_Element = {

        type       = type,
        name       = name,
        normalized = normalized,
        size       = shader_data_type_to_size(type),
        offset     = layout.stride
    }
    
    layout.stride += element.size
    append_elem(&layout.elements, element)
}

buffer_layout_finish :: proc(buffer : ^Buffer_Layout) {
    if len(buffer.elements) != 0 {
        delete(buffer.elements)
    }
    buffer^ = {}
}

vertex_buffer_init :: proc(vertex_buffer : ^Vertex_Buffer, size : u64) {
    using vertex_buffer
    gl.CreateBuffers(1, &id)
    gl.BindBuffer(gl.ARRAY_BUFFER, id)
    gl.BufferData(gl.ARRAY_BUFFER, int(size), nil, gl.DYNAMIC_DRAW)
}

vertex_buffer_finish :: proc(vertex_buffer : ^Vertex_Buffer) {
    using vertex_buffer
    assert(id != 0)
    gl.DeleteBuffers(1, &id)
    buffer_layout_finish(&layout)
    vertex_buffer^ = {}
}

vertex_buffer_init_with_data :: proc(vertex_buffer : ^Vertex_Buffer, vertices : rawptr, size : u64) {
    using vertex_buffer
    gl.CreateBuffers(1, &id)
    gl.BindBuffer(gl.ARRAY_BUFFER, id)
    gl.BufferData(gl.ARRAY_BUFFER, int(size), vertices, gl.STATIC_DRAW)
}

vertex_buffer_set_data :: proc(vertex_buffer : ^Vertex_Buffer, data : rawptr, size : u64) {
    using vertex_buffer
    gl.BindBuffer(gl.ARRAY_BUFFER, id)
    gl.BufferSubData(gl.ARRAY_BUFFER, 0, int(size), data)
}

vertex_buffer_free :: proc(vertex_buffer : ^Vertex_Buffer) {
    using vertex_buffer
    gl.DeleteBuffers(1, &id)
    id = 0
    delete(layout.elements)
    layout.stride = 0
}

vertex_buffer_bind :: proc(vertex_buffer : ^Vertex_Buffer) {
    using vertex_buffer
    gl.BindBuffer(gl.ARRAY_BUFFER, id)
}

vertex_buffer_unbind :: proc(vertex_buffer : ^Vertex_Buffer) {
    using vertex_buffer // unused
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
}

/////////////////////////////
//:Index Buffer
/////////////////////////////

Index_Buffer :: struct {
    id : u32,
    count : u64
}

index_buffer_init :: proc(index_buffer : ^Index_Buffer, indices : ^u32, indices_count : u64) {
    using index_buffer
    count = indices_count
    gl.CreateBuffers(1, &id)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, id)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, int(count * size_of(u32)), indices, gl.STATIC_DRAW)
}

index_buffer_finish :: proc(index_buffer : ^Index_Buffer) {
    using index_buffer
    assert(id != 0)
    gl.DeleteBuffers(1, &id)
    index_buffer^ = {}
}

index_buffer_bind :: proc(index_buffer : ^Index_Buffer) {
    using index_buffer
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, id)
}

index_buffer_unbind :: proc(index_buffer : ^Index_Buffer) {
    using index_buffer // unused
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)
}

/////////////////////////////
//:Vertex Array
/////////////////////////////

Vertex_Array :: struct {
    id : u32,
    vertex_buffers : [dynamic] ^Vertex_Buffer,
    index_buffer : ^Index_Buffer
}

vertex_array_init :: proc(vertex_array : ^Vertex_Array) {
    using vertex_array
    gl.CreateVertexArrays(1, &id)
}

vertex_array_finish :: proc(vertex_array : ^Vertex_Array) {
    using vertex_array
    for vertex_buffer in vertex_buffers {
        assert(vertex_buffer != nil)
        if vertex_buffer.id != 0 {
            vertex_buffer_finish(vertex_buffer)
        }
    }
    if len(vertex_buffers) != 0 {
        delete(vertex_buffers)
    }
    assert(index_buffer != nil)
    if index_buffer.id != 0 {
        index_buffer_finish(index_buffer)
    }

    gl.DeleteVertexArrays(1, &id)
    vertex_array^ = {}
}

vertex_array_bind :: proc(vertex_array : ^Vertex_Array) {
    using vertex_array
    gl.BindVertexArray(id)
}

vertex_array_unbind :: proc(vertex_array : ^Vertex_Array) {
    using vertex_array // unsused
    gl.BindVertexArray(0)
}

add_index_buffer :: proc(vertex_array : ^Vertex_Array, index_buffer : ^Index_Buffer) {
    if vertex_array.index_buffer != nil {
        assert(false)
        return
    }
    vertex_array.index_buffer = index_buffer
    vertex_array_bind(vertex_array)
    index_buffer_bind(index_buffer)
}

add_vertex_buffer :: proc(vertex_array : ^Vertex_Array, vertex_buffer : ^Vertex_Buffer) {
    using vertex_array
    assert(len(vertex_buffer.layout.elements) > 0)
    vertex_array_bind(vertex_array)
    vertex_buffer_bind(vertex_buffer)
    index : u32 = 0
    for &element in vertex_buffer.layout.elements {
        gl.EnableVertexAttribArray(index)
        switch element.type {
            case .None:
                assert(false)
            case .Float, .Float2, .Float3, .Float4, .Mat3, .Mat4, .Sampler2D:
                gl.VertexAttribPointer(
                    index, 
                    shader_data_type_to_count(element.type), 
                    shader_data_type_to_gl(element.type), 
                    element.normalized ? gl.TRUE : gl.FALSE,
                    cast(i32) vertex_buffer.layout.stride,
                    cast(uintptr) element.offset
                )
            case .Int, .Int2, .Int3, .Int4, .Bool:
                gl.VertexAttribIPointer(
                    index, 
                    shader_data_type_to_count(element.type), 
                    shader_data_type_to_gl(element.type), 
                    cast(i32) vertex_buffer.layout.stride,
                    cast(uintptr) element.offset
                )
        }
        index = index + 1
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//:Texture
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Min_Filter :: enum {
    LINEAR,
    NEAREST
}

Mag_Filter :: enum {
    LINEAR,
    NEAREST
}

Wrap_Mode :: enum {
    REPEAT, 
    CLAMP_TO_EDGE
}

Texture_Coordinate :: enum {
    U,
    V
}

Texture2D :: struct {
    id : u32,
    width : u32,
    height : u32,
    channels : u32,
    min_filter : Min_Filter,
    mag_filter : Mag_Filter,
    wrap_mode_u : Wrap_Mode,
    wrap_mode_v : Wrap_Mode,
    pixel_data : []u8,
    image_path : string
}

@(private = "file")
set_mag_filter :: proc(texture_id : u32, mag_filter : Mag_Filter) {
    switch mag_filter {
        case .LINEAR:  gl.TextureParameteri(texture_id, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
        case .NEAREST: gl.TextureParameteri(texture_id, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    }
}

@(private = "file")
set_min_filter :: proc(texture_id : u32, min_filter : Min_Filter) {
    switch min_filter {
        case .LINEAR:  gl.TextureParameteri(texture_id, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
        case .NEAREST: gl.TextureParameteri(texture_id, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    }
}

@(private = "file")
set_wrap_mode :: proc(texture_id : u32, texture_coordinate : Texture_Coordinate, wrap_mode : Wrap_Mode) {
    coord : gl.GL_Enum = texture_coordinate == .U ? .TEXTURE_WRAP_S : .TEXTURE_WRAP_T
    switch wrap_mode {
        case .REPEAT: gl.TextureParameteri(texture_id, cast(u32) coord, gl.REPEAT)
        case .CLAMP_TO_EDGE: gl.TextureParameteri(texture_id, cast(u32) coord, gl.CLAMP_TO_EDGE)
    }
}

@(private = "file")
texture_upload_to_gpu :: proc(texture : ^Texture2D) {
    using texture

    assert(id == 0)
    
    data_format     : u32 = gl.ZERO
    internal_format : u32 = gl.ZERO 
    
    if channels == 4 {
        internal_format = gl.RGBA8
        data_format = gl.RGBA
    } 
    else if channels == 3 {
        internal_format = gl.RGB8
        data_format = gl.RGB
   }

    local_id : u32
    gl.CreateTextures(gl.TEXTURE_2D, 1, &local_id)
    id = local_id
    
    gl.TextureStorage2D(id, 1, internal_format, cast(i32) width, cast(i32) height)

    set_min_filter(id, min_filter)
    set_mag_filter(id, mag_filter)

    set_wrap_mode(id, .U, wrap_mode_u)
    set_wrap_mode(id, .V, wrap_mode_v)

    gl.TextureSubImage2D(id, 0, 0, 0, cast(i32) width, cast(i32) height, data_format, gl.UNSIGNED_BYTE, raw_data(pixel_data))
}

texture_2d_init_as_white :: proc(texture : ^Texture2D) {
    using texture
    width = 1
    height = 1
    channels = 4
    assert(pixel_data == nil)
    pixel_data = make([]u8, 4)
    for i in 0..<4 {
        pixel_data[i] = 255
    }
    texture_upload_to_gpu(texture)
}

texture_2d_init_form_path :: proc(
    texture  : ^Texture2D, 
    path     : string, 
    mag      : Mag_Filter = .NEAREST,
    min      : Min_Filter = .NEAREST,
    wrap_u   : Wrap_Mode  = .REPEAT,
    wrap_v   : Wrap_Mode  = .REPEAT,
) {
    
    using texture
    
    mag_filter = mag
    min_filter = min
    wrap_mode_u = wrap_u
    wrap_mode_v = wrap_v
    
    image_path = path

    assert(pixel_data == nil)
    assert(len(image_path) != 0)

    stb.set_flip_vertically_on_load(1)
    
    x, y, c : i32
    
    image_path_str := strings.clone_to_cstring(image_path)
    defer delete(image_path_str)
    
    raw_pixel_data := stb.load(image_path_str, &x, &y, &c, 0)
    assert(raw_pixel_data != nil)
    
    data_len := x * y * c
    pixel_data = raw_pixel_data[:data_len]
    
    width    = u32(x)
    height   = u32(y)
    channels = u32(c)

    texture_upload_to_gpu(texture)
}

texture_2d_finish :: proc(texture : ^Texture2D) {
    using texture
    assert(id != 0)
    gl.DeleteTextures(1, &id)
    assert(pixel_data != nil)
    if len(image_path) != 0 {
        stb.image_free(raw_data(pixel_data))
    } else {
        delete(pixel_data)
    }
    texture^ = {}
}

texture_2d_bind :: proc(texture : ^Texture2D, slot : u32 = 0) {
    using texture
    assert(id != 0)
    gl.BindTextureUnit(slot, id)
}

texture_2d_init :: proc{ texture_2d_init_form_path, texture_2d_init_as_white }

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//:Shader
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

SHADER_VERT_QUAD :: `
    #version 420 core
            
    layout(location = 0) in vec4 a_Position;
    layout(location = 1) in vec4 a_Tint;
    layout(location = 2) in vec2 a_UV;
    layout(location = 3) in int  a_Texture;
    layout(location = 4) in int  a_EntityID;

    uniform mat4 u_ProjectionView;        
            
    out vec4     v_Tint;
    out vec2     v_UV;
    flat out int v_Texture;
    flat out int v_EntityID;

    void main()
    {
        gl_Position   = u_ProjectionView * a_Position;
        v_Tint        = a_Tint;
        v_UV          = a_UV;
        v_Texture     = a_Texture;
        v_EntityID    = a_EntityID;
    }
`

SHADER_FRAG_QUAD :: `
    #version 420 core
            
    layout(location = 0) out vec4 o_Color;
    layout(location = 1) out int  o_EntityID;
    
    uniform sampler2D u_Textures[32];
    
    in vec4      v_Tint;
    in vec2      v_UV;
    flat in int  v_Texture;
    flat in int  v_EntityID;

    void main()
    {
        o_Color = texture(u_Textures[v_Texture], v_UV) * v_Tint;
        o_EntityID = v_EntityID;
    }
`

SHADER_VERT_CIRCLE :: `
    #version 420 core
            
    layout(location = 0) in vec4  a_Position;
    layout(location = 1) in vec4  a_LocalPosition;
    layout(location = 2) in vec4  a_Tint;
    layout(location = 3) in float a_Thickness;
    layout(location = 4) in float a_Fade;
    layout(location = 5) in int   a_EntityID;
    
    uniform mat4 u_ProjectionView;
    
     // Vertex output
    out vec4     v_LocalPosition;
    out vec4     v_Tint;
    out float    v_Thickness;
    out float    v_Fade;
    flat out int v_EntityID;
    
    void main()
    {
        gl_Position     = u_ProjectionView * a_Position;
        v_LocalPosition = a_LocalPosition;
        v_Tint          = a_Tint;
        v_Thickness     = a_Thickness;
        v_Fade          = a_Fade;
        v_EntityID      = a_EntityID;
    }

`

SHADER_FRAG_CIRCLE :: `
    #version 420 core

    layout(location = 0) out vec4 o_Color;
    layout(location = 1) out int  o_EntityID;

    // Vertex input
    in vec4     v_LocalPosition;
    in vec4     v_Tint;
    in float    v_Thickness;
    in float    v_Fade;
    flat in int v_EntityID;

    void main()
    {
        vec2 localPos = vec2(v_LocalPosition.x * 2, v_LocalPosition.y * 2);
        float d = 1.0 - length(localPos);
        float alpha = smoothstep(0.0, v_Fade, d);
        alpha *= smoothstep(v_Thickness + v_Fade, v_Thickness, d);
        o_Color = vec4(v_Tint.rgb, alpha);
        o_EntityID = v_EntityID;    
    }

`

Shader_Default :: enum {
    QUAD,
    CIRCLE
}

Shader :: struct {
    id : u32,
    //uniforms : gl.Uniforms
}

shader_init_from_source :: proc(shader : ^Shader, vertex_source : string, fragment_source : string) {
    using shader

    assert(id == 0)
    shader_id, ok := gl.load_shaders_source(vertex_source, fragment_source)
    
    if !ok {
        assert(false)
        return
    }
    id = shader_id
    //gl.get_uniforms_from_program(shader_id)
}

shader_init_from_default :: proc(shader : ^Shader, def : Shader_Default) {
    switch def {
        case .QUAD : shader_init_from_source(shader, SHADER_VERT_QUAD, SHADER_FRAG_QUAD)
        case .CIRCLE : shader_init_from_source(shader, SHADER_VERT_CIRCLE, SHADER_FRAG_CIRCLE)
    }
}

shader_finish :: proc(shader : ^Shader) {
    using shader
    //gl.destroy_uniforms(uniforms)
    assert(id != 0)
    gl.DeleteProgram(id)
    shader^ = {}
}

shader_bind :: proc(shader : ^Shader) {
    using shader
    assert(id != 0)
    gl.UseProgram(id)
}

shader_unbind :: proc() {
    gl.UseProgram(0)
}

shader_init :: proc { shader_init_from_source, shader_init_from_default }

shader_get_constant_location :: proc(shader : ^Shader, name : string) -> i32 {
    return gl.GetUniformLocation(shader.id, cstring(raw_data(name)))
}

shader_set_constant_m4 :: proc(shader : ^Shader, name : string, value : m4) {
    using shader
    location := shader_get_constant_location(shader, name)
    arg := value;
    gl.UniformMatrix4fv(location, 1, false, raw_data(&arg))
}

shader_set_constant_sampler2D :: proc(shader : ^Shader, name : string, value : [^]i32, count : i32) {
    using shader
    location := shader_get_constant_location(shader, name)
    gl.Uniform1iv(location, count, value)
}

shader_set_constant_int :: proc(shader : ^Shader, name : string, value : i32) {
    using shader
    location := shader_get_constant_location(shader, name)
    gl.Uniform1i(location, value)
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//:Primitives2D
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

VERTICES_PER_2D_PRIMITIVE   :: 4
INDICES_PER_2D_PRIMITIVE    :: 6
MAX_2D_PRIMITIVES_PER_BATCH :: 3000
MAX_TEXTURE_SLOTS           :: 32

Default_Texture_Slots :: enum {
    WHITE,
    COUNT,
}

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

fill_circle_vertex_positions :: proc(vertex_positions : ^V4Verts2D, radius : f32) {
    
    radius := radius * 2.0
    scale_mat := matrix4.scale(matrix4.IDENTITY, { radius, radius, 1.0 })
    vertex_positions[0] = scale_mat * DEFAULT_VERTEX_POSITIONS_2D[0]
    vertex_positions[1] = scale_mat * DEFAULT_VERTEX_POSITIONS_2D[1]
    vertex_positions[2] = scale_mat * DEFAULT_VERTEX_POSITIONS_2D[2]
    vertex_positions[3] = scale_mat * DEFAULT_VERTEX_POSITIONS_2D[3]
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

fill_quad_sub_tex_vertex_uvs :: proc(
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