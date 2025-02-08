package core

import "core:fmt"
import "core:c"
import "core:strings"

import "vendor:OpenGL"
import "vendor:glfw"

/////////////////////////////
//:Window
/////////////////////////////

Cursor_Mode :: enum  {
    Normal,
    Disabled,
    Hidden,
    Captured
}

Window :: struct {
    handle : glfw.WindowHandle,
    time   : Time,
}

window_instance : ^Window

window_init :: proc(
    instance    : ^Window,
    title       : string      = "Game", 
    width       : i32         = 1280, 
    height      : i32         = 720,
    v_sync      : b32         = false,
    start_max   : b32         = false,
    cursor_mode : Cursor_Mode = Cursor_Mode.Normal
) {
    assert(window_instance == nil)
    assert(instance != nil)
    window_instance = instance

    glfw.WindowHint(glfw.RESIZABLE, glfw.TRUE)

	glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, glfw.TRUE)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

    GL_MAJOR_VERSION : c.int : 4
    GL_MINOR_VERSION :: 6

	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_MAJOR_VERSION) 
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_MINOR_VERSION)

	if glfw.Init() != glfw.TRUE {
		assert(false)
		return
	}

    title_cstring := strings.clone_to_cstring(title)
    defer delete(title_cstring)
	
    window_instance.handle = glfw.CreateWindow(width, height, title_cstring, nil, nil)
	assert(window_instance.handle != nil)

    glfw.MakeContextCurrent(window_instance.handle)
    OpenGL.load_up_to(int(GL_MAJOR_VERSION), GL_MINOR_VERSION, glfw.gl_set_proc_address)

    if start_max {
        window_maximize()
    }
	
    window_set_v_sync(v_sync)
	window_set_cursor_mode(cursor_mode)

    time_init(&window_instance.time)
}

window_finish :: proc() {
    assert(window_instance != nil)
    glfw.Terminate()
	glfw.DestroyWindow(window_instance.handle)
    window_instance.handle = nil
}

window_close :: proc() {
    assert(window_instance != nil)
    glfw.SetWindowShouldClose(window_instance.handle, true)
}

keep_window_opened :: proc() -> b32 {
    assert(window_instance != nil)
    glfw.SwapBuffers(window_instance.handle)
    glfw.PollEvents()
    time_step(&window_instance.time)
    return !glfw.WindowShouldClose(window_instance.handle)
}

window_maximize :: proc() {
    assert(window_instance != nil)
    glfw.MaximizeWindow(window_instance.handle)
}

window_set_v_sync :: proc (enabled : b32 = true) {
    v_sync : c.int = enabled ? 1 : 0;
    glfw.SwapInterval(v_sync);
}

window_set_cursor_mode :: proc (mode : Cursor_Mode) {
    assert(window_instance != nil)

    switch mode {
        case .Normal:
            glfw.SetInputMode(window_instance.handle, glfw.CURSOR, glfw.CURSOR_NORMAL)
        case .Disabled:
            glfw.SetInputMode(window_instance.handle, glfw.CURSOR, glfw.CURSOR_DISABLED)
        case .Hidden:
            glfw.SetInputMode(window_instance.handle, glfw.CURSOR, glfw.CURSOR_HIDDEN)
        case .Captured:
            glfw.SetInputMode(window_instance.handle, glfw.CURSOR, glfw.CURSOR_CAPTURED)
    }
}

window_get_size :: proc() -> (width, height : i32) {
    assert(window_instance != nil)
    width, height = glfw.GetWindowSize(window_instance.handle)
    return
}

window_get_aspect :: proc() -> f32 {
    width, height := window_get_size()
    return f32(width) / f32(height)
}

winodw_get_cursor_position :: proc() -> (x, y : f32) {
    assert(window_instance != nil)
    xpos, ypos := glfw.GetCursorPos(window_instance.handle);
    x = f32(xpos)
    y = f32(ypos)
    return
}

window_get_time :: proc() -> f64 {
    return glfw.GetTime()
}