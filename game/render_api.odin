package game

import "vendor:OpenGL"
import "core:c"
import "core:math"

/////////////////////////////
//:Render API
/////////////////////////////

Blending_Mode :: enum {
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
        case OpenGL.FLOAT      : return Shader_Data_Type.Float
        case OpenGL.FLOAT_VEC2 : return Shader_Data_Type.Float2
        case OpenGL.FLOAT_VEC3 : return Shader_Data_Type.Float3
        case OpenGL.FLOAT_VEC4 : return Shader_Data_Type.Float4
        case OpenGL.FLOAT_MAT3 : return Shader_Data_Type.Mat3
        case OpenGL.FLOAT_MAT4 : return Shader_Data_Type.Mat4
        case OpenGL.INT        : return Shader_Data_Type.Int
        case OpenGL.INT_VEC2   : return Shader_Data_Type.Int2
        case OpenGL.INT_VEC3   : return Shader_Data_Type.Int3
        case OpenGL.INT_VEC4   : return Shader_Data_Type.Int4
        case OpenGL.SAMPLER_2D : return Shader_Data_Type.Sampler2D
        case OpenGL.BOOL       : return Shader_Data_Type.Bool
    }
    return Shader_Data_Type.None
}

shader_data_type_to_gl :: proc(type: Shader_Data_Type) -> u32 {
    switch type
    {
        case .Float     : return OpenGL.FLOAT
        case .Float2    : return OpenGL.FLOAT
        case .Float3    : return OpenGL.FLOAT
        case .Float4    : return OpenGL.FLOAT
        case .Mat3      : return OpenGL.FLOAT
        case .Mat4      : return OpenGL.FLOAT
        case .Int       : return OpenGL.INT
        case .Int2      : return OpenGL.INT
        case .Int3      : return OpenGL.INT
        case .Int4      : return OpenGL.INT
        case .Sampler2D : return OpenGL.SAMPLER_2D
        case .Bool      : return OpenGL.BOOL
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
    OpenGL.Viewport(i32(x), i32(y), i32(width), i32(height))
}

set_clear_color_scalar :: proc(r: f32, g: f32, b: f32, a: f32) {
    OpenGL.ClearColor(r, g, b, a)
}

set_clear_color_v4 :: proc(v: v4) {
    set_clear_color_scalar(v.x, v.y, v.z, v.w)
}

set_clear_color :: proc{set_clear_color_scalar, set_clear_color_v4}

clear_screen :: proc() {
    OpenGL.Clear(OpenGL.COLOR_BUFFER_BIT | OpenGL.DEPTH_BUFFER_BIT)
}

set_blending_enabled :: proc(enabled: b32 = true) {
    if enabled
    {
        OpenGL.Enable(OpenGL.BLEND);
        return
    }

    OpenGL.Disable(OpenGL.BLEND)
}

set_blending_mode :: proc(blending_mode : Blending_Mode) {
    switch blending_mode
    {
        case .SOLID: 
            OpenGL.BlendFunc(OpenGL.ONE, OpenGL.ZERO)                
            return
        case .ALPHA:
            OpenGL.BlendFunc(OpenGL.SRC_ALPHA, OpenGL.ONE_MINUS_SRC_ALPHA) 
            return
        case .ADD:
            OpenGL.BlendFunc(OpenGL.SRC_ALPHA, OpenGL.ONE)                 
            return
        case .MULTIPLY: 
            OpenGL.BlendFunc(OpenGL.DST_COLOR, OpenGL.ZERO)                
            return
    }
}

set_depth_test_enabled :: proc(enabled : b8 = true) {
    if enabled {
        OpenGL.Enable(OpenGL.DEPTH_TEST)
        return
    }
    OpenGL.Disable(OpenGL.DEPTH_TEST)
}

draw_elements :: proc(vao : ^Vertex_Array, element_count : u32) {
    vertex_array_bind(vao)
    OpenGL.DrawElements(OpenGL.TRIANGLES, i32(element_count), OpenGL.UNSIGNED_INT, nil)
    vertex_array_unbind(vao)
}