package game

Player :: struct {
    handle  : Entity_Handle,
    texture : Texture2D,
}

player_init :: proc(player : ^Player) {
    texture_2d_init(&player.texture, "assets/player.png")
    handle, entity := entity_create("Player", {
        .SPRITE
    })
    player.handle = handle
    entity.texture = &player.texture
}

player_finish :: proc(player : ^Player) {
    texture_2d_finish(&player.texture)
    entity_destroy(player.handle)
}

player_update :: proc(player : ^Player) {
    // here the input
}