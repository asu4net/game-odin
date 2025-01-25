package engine
import gl "vendor:OpenGL"

/////////////////////////////
//:Render Objects
/////////////////////////////

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