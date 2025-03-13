package vector
import "core:math"

/////////////////////////////
//:Vector2
/////////////////////////////

v2 :: [2] f32

ZERO_2D  : v2 : {}
ONE_2D   : v2 : { 1, 1 }
UP_2D    : v2 : { 0, 1 }
RIGHT_2D : v2 : { 1, 0 }

rotate_around :: proc(pivot : v2, angle : f32, point : v2) -> (v2) {
    s := math.sin_f32(math.to_radians(angle));
    c := math.cos(math.to_radians(angle));

    // translate point back to origin:
    new_point := point;
    new_point.x -= pivot.x;
    new_point.y -= pivot.y;

    // rotate point
    x_new := new_point.x * c - new_point.y * s;
    y_new := new_point.x * s + new_point.y * c;

    // translate point back:
    new_point.x = x_new + new_point.x;
    new_point.y = y_new + new_point.y;
    return new_point;
}

/////////////////////////////
//:Vector3
/////////////////////////////

v3 :: [3] f32

ZERO_3D   : v3 : {}
ONE_3D    : v3 : { 1, 1, 1 }
UP_3D     : v3 : { 0, 1, 0 }
RIGHT_3D  : v3 : { 1, 0, 0 }
FRONT_3D  : v3 : { 0, 0, 1 }

/////////////////////////////
//:Vector4
/////////////////////////////

v4 :: [4] f32

ZERO_4D : v4 : { 0, 0, 0, 0 }
ONE_4D  : v4 : { 1, 1, 1, 1 }