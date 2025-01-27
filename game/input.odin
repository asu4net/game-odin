package game
import "vendor:glfw"

/////////////////////////////
//:Input
/////////////////////////////

input_get_mouse_position :: proc() -> (pos : v2) {
    assert(window_handle != nil)
    x, y := glfw.GetCursorPos(window_handle)
    pos.x = f32(x)
    pos.y = f32(y)
    return
}

input_is_mouse_button_pressed :: proc(button : i32) -> i32 {
    assert(window_handle != nil)
    return glfw.GetMouseButton(window_handle, button) == glfw.PRESS
}

input_is_mouse_button_released :: proc(button : i32) -> i32 {
    assert(window_handle != nil)
    return glfw.GetMouseButton(window_handle, button) == glfw.RELEASE
}

input_is_mouse_button_repeated :: proc(button : i32) -> i32 {
    assert(window_handle != nil)
    return glfw.GetMouseButton(window_handle, button) == glfw.REPEAT
}

input_is_key_pressed :: proc(button : i32) -> bool {
    assert(window_handle != nil)
    return glfw.GetKey(window_handle, button) == glfw.PRESS
}

input_is_key_released :: proc(button : i32) -> bool {
    assert(window_handle != nil)
    return glfw.GetKey(window_handle, button) == glfw.RELEASE
}

input_is_key_repeated :: proc(button : i32) -> bool {
    assert(window_handle != nil)
    return glfw.GetKey(window_handle, button) == glfw.REPEAT
}