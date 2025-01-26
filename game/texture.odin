package game

import "core:strings"
import gl "vendor:OpenGL"
import stb "vendor:stb/image"

/////////////////////////////
//:Texture
/////////////////////////////

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

set_mag_filter :: proc(texture_id : u32, mag_filter : Mag_Filter) {
    switch mag_filter {
        case .LINEAR:  gl.TextureParameteri(texture_id, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
        case .NEAREST: gl.TextureParameteri(texture_id, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    }
}

set_min_filter :: proc(texture_id : u32, min_filter : Min_Filter) {
    switch min_filter {
        case .LINEAR:  gl.TextureParameteri(texture_id, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
        case .NEAREST: gl.TextureParameteri(texture_id, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    }
}

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

texture_init_as_white :: proc(texture : ^Texture2D) {
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

texture_init_form_path :: proc(
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

texture_finish :: proc(texture : ^Texture2D) {
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

texture_bind :: proc(texture : ^Texture2D, slot : u32 = 0) {
    using texture
    assert(id != 0)
    gl.BindTextureUnit(slot, id)
}

texture_init :: proc{ texture_init_form_path, texture_init_as_white }