package graphics
import "core:math"

Rect :: struct {
    x, y, width, height: int,
}

v2 :: [2]f32
v3 :: [3]f32
v4 :: [4]f32

m4 :: matrix[4, 4] f32

M4_IDENTITY : m4 : {
    1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 1.0
}

V3_UP      : v3 : { 0, 1, 0 }
V3_RIGHT   : v3 : { 1, 0, 0 }
V3_FORWARD : v3 : { 0, 0, 1 }

m4_translate :: proc(mat: m4, pos : v3) -> m4 {
    op := M4_IDENTITY  
    op[3][0] = pos.x
	op[3][1] = pos.y
	op[3][2] = pos.z
    return op * mat
}

m4_rotate_x :: proc(mat: m4, angle_x: f32) -> m4 {
    c := math.cos(angle_x);
    s := math.sin(angle_x);
    op := M4_IDENTITY;
    op[1][1] =  c;
    op[1][2] = -s;
    op[2][1] =  s;
    op[2][2] =  c;
    return op * mat;
}

m4_rotate_y :: proc(mat: m4, angle_y: f32) -> m4 {
    c := math.cos(angle_y);
    s := math.sin(angle_y);
    op := M4_IDENTITY;
    op[0][0] =  c;
    op[0][2] =  s;
    op[2][0] = -s;
    op[2][2] =  c;
    return op * mat;
}

m4_rotate_z :: proc(mat: m4, angle_z: f32) -> m4 {
    c := math.cos(angle_z);
    s := math.sin(angle_z);
    op := M4_IDENTITY;
    op[0][0] =  c;
    op[0][1] = -s;
    op[1][0] =  s;
    op[1][1] =  c;
    return op * mat;
}

m4_scale :: proc(mat: m4, scale : v3) -> m4 {
    op := M4_IDENTITY
    op[0][0] = scale.x
    op[1][1] = scale.y
    op[2][2] = scale.z
    return op * mat
}

m4_rotate :: proc(mat: m4, rotation : v3) -> m4 {
    return m4_rotate_z(m4_rotate_y(m4_rotate_x(mat, rotation.x), rotation.y), rotation.z);
}