package core
import "vendor:glfw"

/////////////////////////////
//:Input
/////////////////////////////

input_get_mouse_position :: proc() -> (x, y : f32) {
    assert(window_instance != nil)
    x64, y64 := glfw.GetCursorPos(window_instance.handle)
    x = f32(x64)
    y = f32(y64)
    return
}

input_is_mouse_button_pressed :: proc(button : i32) -> i32 {
    assert(window_instance != nil)
    return glfw.GetMouseButton(window_instance.handle, button) == glfw.PRESS
}

input_is_mouse_button_released :: proc(button : i32) -> i32 {
    assert(window_instance != nil)
    return glfw.GetMouseButton(window_instance.handle, button) == glfw.RELEASE
}

input_is_mouse_button_repeated :: proc(button : i32) -> i32 {
    assert(window_instance != nil)
    return glfw.GetMouseButton(window_instance.handle, button) == glfw.REPEAT
}

input_is_key_pressed :: proc(button : i32) -> bool {
    assert(window_instance != nil)
    return glfw.GetKey(window_instance.handle, button) == glfw.PRESS
}

input_is_key_released :: proc(button : i32) -> bool {
    assert(window_instance != nil)
    return glfw.GetKey(window_instance.handle, button) == glfw.RELEASE
}

input_is_key_repeated :: proc(button : i32) -> bool {
    assert(window_instance != nil)
    return glfw.GetKey(window_instance.handle, button) == glfw.REPEAT
}