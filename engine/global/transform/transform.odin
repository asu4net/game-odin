package transform
import "engine:global/vector"
import "engine:global/matrix4"

/////////////////////////////
//:Transform
/////////////////////////////

Transform :: struct {
    position : vector.v3,
    rotation : vector.v3,
    scale    : vector.v3
}

DEFAULT_TRANSFORM : Transform : {
    vector.ZERO_3D, vector.ZERO_3D, vector.ONE_3D
}

get_matrix :: proc(transform : Transform) -> matrix4.m4 {
    return matrix4.transform(transform.position, transform.rotation, transform.scale)
}