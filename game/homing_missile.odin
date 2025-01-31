package game

HomingState :: enum {
    IDLE,
    ATTACK,
}

HomingEnemy :: struct {
    speed         : f32,
    state         : HomingState,
    idle_time     : f32,
    attack_target : v3, 
    cooldown      : f32 
}