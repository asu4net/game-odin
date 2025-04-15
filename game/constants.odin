package game
import "engine:global/color"

GAME_TITLE :: "Blessed Bullets"

/////////////////////////////
//:Numbers
/////////////////////////////

// Window
WINDOW_WIDTH                :: 720
WINDOW_HEIGHT               :: 1280

// Player
PLAYER_SPEED                :: 4.0
PLAYER_FIRERATE             :: 0.1
PLAYER_DAMAGE               :: 10

PLAYER_BULLET_LV1_SPEED     :: 8.0

AMMO_LV1                    :: 0
AMMO_LV2                    :: 30
AMMO_LV3                    :: 100

// Ammo pickup
AMMO_RADIUS                 :: 0.05
AMMO_COLLISION_RADIUS       :: 0.1
AMMO_AMOUNT_PICK_UP         :: 10

// Camera
CAMERA_SIZE                 :: 3.0 * 1.7

// Entity
MAX_ENTITIES                :: 3000
ENTITY_CLEANUP_INTERVAL     :: 2 // Zero means each frame 

// Particle
MAX_PARTICLES               :: 10000
MAX_EMITTERS                :: 500
MAX_SPRITES_PER_EMITTER     :: 5
DEFAULT_PARTICLE_SPRITE     :: Texture_Name.None
PARTICLE_VELOCITY           :: ONE_3D
PARTICLE_COLOR              :: color.LIGHT_GREEN
PARTICLE_LIFETIME           :: 1      
PARTICLE_SPAWN_TIME         :: 0.01

// Flipbook
MAX_FLIPBOOK_KEYS :: 10

// Kamikaze
KAMIKAZE_WAVE_0_AMOUNT :: 5   // not implemented
KAMIKAZE_SPEED_MIN     :: 0   // min speed
KAMIKAZE_SPEED_MAX     :: 7   // max speed
KAMIKAZE_ACC           :: 0.7 // time to accelerate at max speed
KAMIKAZE_LIFE          :: 300
KAMIKAZE_SCORE         :: 10  // not implemented
KAMIKAZE_ATTACK_CD     :: 1
KAMIKAZE_SAW_SPEED     :: 360 * 2 // degrees per sec

// Homing Missile
HOMING_MISSILE_RADIUS             :: 0.15
HOMING_MISSILE_DISTANCE_TO_ATTACK :: 2
HOMING_MISSILE_WAIT_TIME          :: 0.5
HOMING_MISSILE_BLINK_TIME         :: 0.5
HOMING_MISSILE_APPROACH_SPEED     :: 2
HOMING_MISSILE_ATTACK_SPEED       :: 4
HOMING_MISSILE_LIFE               :: 100
HOMING_MISSILE_LINE_START_COLOR   :: color.RED
HOMING_MISSILE_LINE_END_COLOR     :: color.WHITE


/////////////////////////////
//:Names
/////////////////////////////

NAME_PLAYER          :: "Player"
NAME_KAMIKAZE        :: "KamikazePrefab"
NAME_KAMIKAZE_SAW    :: "KamikazeSawPrefab"
NAME_HOMING_MISSILE  :: "HomingMissilePrefab"
NAME_POINTER_LINE    :: "PointerLinePrefab"

/////////////////////////////
//:Debug
/////////////////////////////

DEBUG_AI_MOVEMENT_ENABLED      :: true
DEBUG_DRAW_COLLIDERS           :: false
DEBUG_PRINT_CREATED_ENTITIES   :: false
DEBUG_PRINT_DESTROYED_ENTITIES :: false
DEBUG_PRINT_DAMAGE             :: true