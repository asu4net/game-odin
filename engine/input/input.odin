package input

import "vendor:glfw"
import "engine:window"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//:Input
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

get_mouse_position :: proc() -> (x, y : f32) {
    assert(window.instance != nil)
    x64, y64 := glfw.GetCursorPos(window.instance.handle)
    x = f32(x64)
    y = f32(y64)
    return
}

is_mouse_button_pressed :: proc(button : i32) -> i32 {
    assert(window.instance != nil)
    return glfw.GetMouseButton(window.instance.handle, button) == glfw.PRESS
}

is_mouse_button_released :: proc(button : i32) -> i32 {
    assert(window.instance != nil)
    return glfw.GetMouseButton(window.instance.handle, button) == glfw.RELEASE
}

is_mouse_button_repeated :: proc(button : i32) -> i32 {
    assert(window.instance != nil)
    return glfw.GetMouseButton(window.instance.handle, button) == glfw.REPEAT
}

is_key_pressed :: proc(button : i32) -> bool {
    assert(window.instance != nil)
    return glfw.GetKey(window.instance.handle, button) == glfw.PRESS
}

is_key_released :: proc(button : i32) -> bool {
    assert(window.instance != nil)
    return glfw.GetKey(window.instance.handle, button) == glfw.RELEASE
}

is_key_repeated :: proc(button : i32) -> bool {
    assert(window.instance != nil)
    return glfw.GetKey(window.instance.handle, button) == glfw.REPEAT
}