package game

import "core:fmt"
import "core:c"
import "core:strings"

import gl "vendor:OpenGL"
import "vendor:glfw"

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
    gl.load_up_to(int(GL_MAJOR_VERSION), GL_MINOR_VERSION, glfw.gl_set_proc_address)

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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//:Time
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Time :: struct {
    max_delta_time      : f64,
    fixed_delta_seconds : f64,
    delta_seconds       : f32,
    seconds             : f64,
    frame_count         : u32,
    acc_fixed_delta     : f64,
    last_time           : f64,
    fixed_update_calls  : u32,
    scale               : f32
}

time_init :: proc(time : ^Time, max_delta : f64 = 1.0 / 15.0, fixed_delta : f64 = 0.06) {
    using time
    assert(window_instance.handle != nil)
    time^ = {}
    last_time = window_get_time()
    fixed_delta_seconds = fixed_delta
    acc_fixed_delta = fixed_delta_seconds
    max_delta_time = max_delta
    scale = 1;
}

time_step :: proc(time : ^Time) {
    using time
    current_time := window_get_time()
    frame_count+=1;
    time_between_frames := current_time - last_time;
    last_time = current_time;
    seconds += time_between_frames;
    delta_seconds = cast(f32) clamp(time_between_frames, 0, max_delta_time) * scale;
    acc_fixed_delta += f64(delta_seconds);
    
    for acc_fixed_delta >= fixed_delta_seconds
    {
        acc_fixed_delta -= fixed_delta_seconds;
        fixed_update_calls += 1;
    }
}

delta_seconds :: proc() -> f32 {
    assert(window_instance.handle != nil)
    return window_instance.time.delta_seconds
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//:Input
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//:Keys
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//-------------------------------------------------------------------------------------------------------

/* Button/Key states */
RELEASE :: 0
PRESS   :: 1
REPEAT  :: 2

/* Joystick hat states. */
HAT_CENTERED   :: 0
HAT_UP         :: 1
HAT_RIGHT      :: 2
HAT_DOWN       :: 4
HAT_LEFT       :: 8
HAT_RIGHT_UP   :: (HAT_RIGHT | HAT_UP)
HAT_RIGHT_DOWN :: (HAT_RIGHT | HAT_DOWN)
HAT_LEFT_UP    :: (HAT_LEFT  | HAT_UP)
HAT_LEFT_DOWN  :: (HAT_LEFT  | HAT_DOWN)

/* The unknown key */
KEY_UNKNOWN :: -1

/** Printable keys **/

/* Named printable keys */
KEY_SPACE         :: 32
KEY_APOSTROPHE    :: 39  /* ' */
KEY_COMMA         :: 44  /* , */
KEY_MINUS         :: 45  /* - */
KEY_PERIOD        :: 46  /* . */
KEY_SLASH         :: 47  /* / */
KEY_SEMICOLON     :: 59  /* ; */
KEY_EQUAL         :: 61  /* :: */
KEY_LEFT_BRACKET  :: 91  /* [ */
KEY_BACKSLASH     :: 92  /* \ */
KEY_RIGHT_BRACKET :: 93  /* ] */
KEY_GRAVE_ACCENT  :: 96  /* ` */
KEY_WORLD_1       :: 161 /* non-US #1 */
KEY_WORLD_2       :: 162 /* non-US #2 */

/* Alphanumeric characters */
KEY_0 :: 48
KEY_1 :: 49
KEY_2 :: 50
KEY_3 :: 51
KEY_4 :: 52
KEY_5 :: 53
KEY_6 :: 54
KEY_7 :: 55
KEY_8 :: 56
KEY_9 :: 57

KEY_A :: 65
KEY_B :: 66
KEY_C :: 67
KEY_D :: 68
KEY_E :: 69
KEY_F :: 70
KEY_G :: 71
KEY_H :: 72
KEY_I :: 73
KEY_J :: 74
KEY_K :: 75
KEY_L :: 76
KEY_M :: 77
KEY_N :: 78
KEY_O :: 79
KEY_P :: 80
KEY_Q :: 81
KEY_R :: 82
KEY_S :: 83
KEY_T :: 84
KEY_U :: 85
KEY_V :: 86
KEY_W :: 87
KEY_X :: 88
KEY_Y :: 89
KEY_Z :: 90


/** Function keys **/

/* Named non-printable keys */
KEY_ESCAPE       :: 256
KEY_ENTER        :: 257
KEY_TAB          :: 258
KEY_BACKSPACE    :: 259
KEY_INSERT       :: 260
KEY_DELETE       :: 261
KEY_RIGHT        :: 262
KEY_LEFT         :: 263
KEY_DOWN         :: 264
KEY_UP           :: 265
KEY_PAGE_UP      :: 266
KEY_PAGE_DOWN    :: 267
KEY_HOME         :: 268
KEY_END          :: 269
KEY_CAPS_LOCK    :: 280
KEY_SCROLL_LOCK  :: 281
KEY_NUM_LOCK     :: 282
KEY_PRINT_SCREEN :: 283
KEY_PAUSE        :: 284

/* Function keys */
KEY_F1  :: 290
KEY_F2  :: 291
KEY_F3  :: 292
KEY_F4  :: 293
KEY_F5  :: 294
KEY_F6  :: 295
KEY_F7  :: 296
KEY_F8  :: 297
KEY_F9  :: 298
KEY_F10 :: 299
KEY_F11 :: 300
KEY_F12 :: 301
KEY_F13 :: 302
KEY_F14 :: 303
KEY_F15 :: 304
KEY_F16 :: 305
KEY_F17 :: 306
KEY_F18 :: 307
KEY_F19 :: 308
KEY_F20 :: 309
KEY_F21 :: 310
KEY_F22 :: 311
KEY_F23 :: 312
KEY_F24 :: 313
KEY_F25 :: 314

/* Keypad numbers */
KEY_KP_0 :: 320
KEY_KP_1 :: 321
KEY_KP_2 :: 322
KEY_KP_3 :: 323
KEY_KP_4 :: 324
KEY_KP_5 :: 325
KEY_KP_6 :: 326
KEY_KP_7 :: 327
KEY_KP_8 :: 328
KEY_KP_9 :: 329

/* Keypad named function keys */
KEY_KP_DECIMAL  :: 330
KEY_KP_DIVIDE   :: 331
KEY_KP_MULTIPLY :: 332
KEY_KP_SUBTRACT :: 333
KEY_KP_ADD      :: 334
KEY_KP_ENTER    :: 335
KEY_KP_EQUAL    :: 336

/* Modifier keys */
KEY_LEFT_SHIFT    :: 340
KEY_LEFT_CONTROL  :: 341
KEY_LEFT_ALT      :: 342
KEY_LEFT_SUPER    :: 343
KEY_RIGHT_SHIFT   :: 344
KEY_RIGHT_CONTROL :: 345
KEY_RIGHT_ALT     :: 346
KEY_RIGHT_SUPER   :: 347
KEY_MENU          :: 348

KEY_LAST :: KEY_MENU

/* Bitmask for modifier keys */
MOD_SHIFT     :: 0x0001
MOD_CONTROL   :: 0x0002
MOD_ALT       :: 0x0004
MOD_SUPER     :: 0x0008
MOD_CAPS_LOCK :: 0x0010
MOD_NUM_LOCK  :: 0x0020

/* Mouse buttons */
MOUSE_BUTTON_1 :: 0
MOUSE_BUTTON_2 :: 1
MOUSE_BUTTON_3 :: 2
MOUSE_BUTTON_4 :: 3
MOUSE_BUTTON_5 :: 4
MOUSE_BUTTON_6 :: 5
MOUSE_BUTTON_7 :: 6
MOUSE_BUTTON_8 :: 7

/* Mousebutton aliases */
MOUSE_BUTTON_LAST   :: MOUSE_BUTTON_8
MOUSE_BUTTON_LEFT   :: MOUSE_BUTTON_1
MOUSE_BUTTON_RIGHT  :: MOUSE_BUTTON_2
MOUSE_BUTTON_MIDDLE :: MOUSE_BUTTON_3

/* Joystick buttons */
JOYSTICK_1  :: 0
JOYSTICK_2  :: 1
JOYSTICK_3  :: 2
JOYSTICK_4  :: 3
JOYSTICK_5  :: 4
JOYSTICK_6  :: 5
JOYSTICK_7  :: 6
JOYSTICK_8  :: 7
JOYSTICK_9  :: 8
JOYSTICK_10 :: 9
JOYSTICK_11 :: 10
JOYSTICK_12 :: 11
JOYSTICK_13 :: 12
JOYSTICK_14 :: 13
JOYSTICK_15 :: 14
JOYSTICK_16 :: 15

JOYSTICK_LAST :: JOYSTICK_16

/* Gamepad buttons */
GAMEPAD_BUTTON_A            :: 0
GAMEPAD_BUTTON_B            :: 1
GAMEPAD_BUTTON_X            :: 2
GAMEPAD_BUTTON_Y            :: 3
GAMEPAD_BUTTON_LEFT_BUMPER  :: 4
GAMEPAD_BUTTON_RIGHT_BUMPER :: 5
GAMEPAD_BUTTON_BACK         :: 6
GAMEPAD_BUTTON_START        :: 7
GAMEPAD_BUTTON_GUIDE        :: 8
GAMEPAD_BUTTON_LEFT_THUMB   :: 9
GAMEPAD_BUTTON_RIGHT_THUMB  :: 10
GAMEPAD_BUTTON_DPAD_UP      :: 11
GAMEPAD_BUTTON_DPAD_RIGHT   :: 12
GAMEPAD_BUTTON_DPAD_DOWN    :: 13
GAMEPAD_BUTTON_DPAD_LEFT    :: 14
GAMEPAD_BUTTON_LAST         :: GAMEPAD_BUTTON_DPAD_LEFT

GAMEPAD_BUTTON_CROSS    :: GAMEPAD_BUTTON_A
GAMEPAD_BUTTON_CIRCLE   :: GAMEPAD_BUTTON_B
GAMEPAD_BUTTON_SQUARE   :: GAMEPAD_BUTTON_X
GAMEPAD_BUTTON_TRIANGLE :: GAMEPAD_BUTTON_Y

/* Gamepad axes */
GAMEPAD_AXIS_LEFT_X        :: 0
GAMEPAD_AXIS_LEFT_Y        :: 1
GAMEPAD_AXIS_RIGHT_X       :: 2
GAMEPAD_AXIS_RIGHT_Y       :: 3
GAMEPAD_AXIS_LEFT_TRIGGER  :: 4
GAMEPAD_AXIS_RIGHT_TRIGGER :: 5
GAMEPAD_AXIS_LAST          :: GAMEPAD_AXIS_RIGHT_TRIGGER

/* Cursor draw state and whether keys are sticky */
CURSOR               :: 0x00033001
STICKY_KEYS          :: 0x00033002
STICKY_MOUSE_BUTTONS :: 0x00033003
LOCK_KEY_MODS        :: 0x00033004

/* Mouse motion */
RAW_MOUSE_MOTION :: 0x00033005

// /* Joystick? */
CONNECTED    :: 0x00040001
DISCONNECTED :: 0x00040002

JOYSTICK_HAT_BUTTONS :: 0x00050001
ANGLE_PLATFORM_TYPE  :: 0x00050002
PLATFORM             :: 0x00050003