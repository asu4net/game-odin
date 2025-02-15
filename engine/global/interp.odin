package global
import "core:math"

/////////////////////////////
//:Interp & Easings
/////////////////////////////

ease_out_expo :: proc(x: f32) -> f32 {
    return x == 1 ? 1 : math.pow(2.0, -10.0 * x)
}

interp_ease_in_expo :: proc(x, min, max: f32) -> f32 {
    factor := ease_in_expo(x)
    return min + (max - min) * factor
}

interp_linear_f32 :: proc(x, min, max: f32) -> f32 {
    return min + (max - min) * x
}

interp_linear_v4 :: proc(x : f32, min, max: v4) -> (v : v4) {
    v.r = interp_linear_f32(x, min.r, max.r)
    v.g = interp_linear_f32(x, min.g, max.g)
    v.b = interp_linear_f32(x, min.b, max.b)
    v.a = interp_linear_f32(x, min.a, max.a)
    return 
}

ease_in_expo :: proc(x: f32) -> f32 {
    return x == 0.0 ? 0.0 : math.pow(2, 10 * (x - 1))
}