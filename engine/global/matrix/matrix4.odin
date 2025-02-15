package matrix4
import "core:math"
import "engine:global/vector"

/////////////////////////////
//:Matrix
/////////////////////////////

m4 :: matrix[4, 4] f32
v3 :: vector.v3

IDENTITY : m4 : {
    1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 1.0
}

translate :: proc(mat: m4, p : v3) -> m4 {
    op := IDENTITY  
    op[3][0] = p.x
	op[3][1] = p.y
	op[3][2] = p.z
    return op * mat
}

rotate_x :: proc(mat: m4, angle_x: f32) -> m4 {
    c := math.cos(angle_x);
    s := math.sin(angle_x);
    op := IDENTITY;
    op[1][1] =  c;
    op[1][2] = -s;
    op[2][1] =  s;
    op[2][2] =  c;
    return op * mat;
}

rotate_y :: proc(mat: m4, angle_y: f32) -> m4 {
    c := math.cos(angle_y);
    s := math.sin(angle_y);
    op := IDENTITY;
    op[0][0] =  c;
    op[0][2] =  s;
    op[2][0] = -s;
    op[2][2] =  c;
    return op * mat;
}

rotate_z :: proc(mat: m4, angle_z: f32) -> m4 {
    c := math.cos(angle_z);
    s := math.sin(angle_z);
    op := IDENTITY;
    op[0][0] =  c;
    op[0][1] = -s;
    op[1][0] =  s;
    op[1][1] =  c;
    return op * mat;
}

scale :: proc(mat: m4, s : v3) -> m4 {
    op := IDENTITY
    op[0][0] = s.x
    op[1][1] = s.y
    op[2][2] = s.z
    return op * mat
}

rotate :: proc(mat: m4, rotation : v3) -> m4 {
    return rotate_z(rotate_y(rotate_x(mat, rotation.x), rotation.y), rotation.z);
}

transform :: proc(position, rotation, sc : v3) -> m4 {
    identity := IDENTITY
    scale_matrix := scale(identity, sc)
    rotation_matrix := rotation != vector.ZERO ? rotate(scale_matrix, math.RAD_PER_DEG * rotation) : scale_matrix
    translation_matrix := translate(rotation_matrix, position)
    return translation_matrix
}