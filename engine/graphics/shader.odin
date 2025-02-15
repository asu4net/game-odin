package graphics

import gl "vendor:OpenGL"

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