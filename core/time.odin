package core

/////////////////////////////
//:Time
/////////////////////////////

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