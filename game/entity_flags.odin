package game

/////////////////////////////
//:Entity flags
/////////////////////////////

GROUP_FLAGS_SPRITE : Entity_Flag_Set : {
    .VALID,
    .ENABLED,
    .VISIBLE,
    .SPRITE,
}

GROUP_FLAGS_CIRCLE : Entity_Flag_Set : {
    .VALID,
    .ENABLED,
    .VISIBLE,
    .CIRCLE,
}

GROUP_FLAGS_COLLIDER_2D : Entity_Flag_Set : {
    .VALID,
    .ENABLED,
    .VISIBLE,
    .COLLIDER_2D,
}

GROUP_FLAGS_KAMIKAZE : Entity_Flag_Set : {
    .VALID,
    .ENABLED,
    .SPRITE,
    .COLLIDER_2D,
    .KAMIKAZE,
}

GROUP_FLAGS_KAMIKAZE_SAW : Entity_Flag_Set : {
    .VALID,
    .ENABLED,
    .SPRITE,
    .KAMIKAZE_SAW,
}

GROUP_FLAGS_PROJECTILE : Entity_Flag_Set : {
    .VALID,
    .ENABLED,
    .COLLIDER_2D,
    .PROJECTILE,
}