package window
import "vendor:glfw"
import "vendor:OpenGL"
import "core:c"
import "core:strings"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//:Window
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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

instance : ^Window

init :: proc(
    wnd         : ^Window,
    title       : string      = "Game", 
    width       : i32         = 1280, 
    height      : i32         = 720,
    v_sync      : b32         = true,
    start_max   : b32         = false,
    cursor_mode : Cursor_Mode = Cursor_Mode.Normal
) {
    assert(instance == nil)
    assert(wnd != nil)
    instance = wnd

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
	
    instance.handle = glfw.CreateWindow(width, height, title_cstring, nil, nil)
	assert(instance.handle != nil)

    glfw.MakeContextCurrent(instance.handle)
    OpenGL.load_up_to(int(GL_MAJOR_VERSION), GL_MINOR_VERSION, glfw.gl_set_proc_address)

    if start_max {
        maximize()
    }
	
    set_v_sync(v_sync)
	set_cursor_mode(cursor_mode)

    time_init(&instance.time)
}

finish :: proc() {
    assert(instance != nil)
    glfw.Terminate()
	glfw.DestroyWindow(instance.handle)
    instance.handle = nil
}

close :: proc() {
    assert(instance != nil)
    glfw.SetWindowShouldClose(instance.handle, true)
}

keep_opened :: proc() -> b32 {
    assert(instance != nil)
    glfw.SwapBuffers(instance.handle)
    glfw.PollEvents()
    time_step(&instance.time)
    return !glfw.WindowShouldClose(instance.handle)
}

maximize :: proc() {
    assert(instance != nil)
    glfw.MaximizeWindow(instance.handle)
}

set_v_sync :: proc (enabled : b32 = true) {
    v_sync : c.int = enabled ? 1 : 0;
    glfw.SwapInterval(v_sync);
}

set_cursor_mode :: proc (mode : Cursor_Mode) {
    assert(instance != nil)

    switch mode {
        case .Normal:
            glfw.SetInputMode(instance.handle, glfw.CURSOR, glfw.CURSOR_NORMAL)
        case .Disabled:
            glfw.SetInputMode(instance.handle, glfw.CURSOR, glfw.CURSOR_DISABLED)
        case .Hidden:
            glfw.SetInputMode(instance.handle, glfw.CURSOR, glfw.CURSOR_HIDDEN)
        case .Captured:
            glfw.SetInputMode(instance.handle, glfw.CURSOR, glfw.CURSOR_CAPTURED)
    }
}

get_size :: proc() -> (width, height : i32) {
    assert(instance != nil)
    width, height = glfw.GetWindowSize(instance.handle)
    return
}

get_aspect :: proc() -> f32 {
    width, height := get_size()
    return f32(width) / f32(height)
}

winodw_get_cursor_position :: proc() -> (x, y : f32) {
    assert(instance != nil)
    xpos, ypos := glfw.GetCursorPos(instance.handle);
    x = f32(xpos)
    y = f32(ypos)
    return
}

get_time :: proc() -> f64 {
    return glfw.GetTime()
}