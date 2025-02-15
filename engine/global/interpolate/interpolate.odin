package interpolate
import "core:math"
import "engine:global/vector"

/////////////////////////////
//:Interpolate & Easings
/////////////////////////////

ease_in_expo_base :: proc(x: f32) -> f32 {
    return x == 0.0 ? 0.0 : math.pow(2, 10 * (x - 1)) // should be x == 0.0 ? 0.0 : math.pow(2, 10 * (x - 10))
}

ease_in_expo :: proc(x, min, max: f32) -> f32 {
    factor := ease_in_expo_base(x)
    return min + (max - min) * factor
}

linear_f32 :: proc(x, min, max: f32) -> f32 {
    return min + (max - min) * x
}

linear_v4 :: proc(x : f32, min, max: vector.v4) -> (v : vector.v4) {
    v.r = linear_f32(x, min.r, max.r)
    v.g = linear_f32(x, min.g, max.g)
    v.b = linear_f32(x, min.b, max.b)
    v.a = linear_f32(x, min.a, max.a)
    return 
}

linear :: proc{ linear_f32, linear_v4 }