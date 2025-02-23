package game
import "engine:global/vector"
import "engine:global/matrix4"
import "engine:global/transform"
import "engine:graphics"
import "engine:ecs"

v2                :: vector.v2
v3                :: vector.v3
v4                :: vector.v4
m4                :: matrix4.m4
ZERO_2D           :: vector.ZERO_2D
ONE_2D            :: vector.ONE_2D
UP_2D             :: vector.UP_2D
RIGHT_2D          :: vector.RIGHT_2D
ZERO_3D           :: vector.ZERO_3D
ONE_3D            :: vector.ONE_3D
UP_3D             :: vector.UP_3D
RIGHT_3D          :: vector.RIGHT_3D
FRONT_3D          :: vector.FRONT_3D
ZERO_4D           :: vector.ZERO_4D          
ONE_4D            :: vector.ONE_4D
Rect              :: graphics.Rect
Texture2D         :: graphics.Texture2D
Blending_Mode     :: graphics.Blending_Mode
Transform         :: transform.Transform
DEFAULT_TRANSFORM :: transform.DEFAULT_TRANSFORM
get_matrix        :: transform.get_matrix

// Entity
Entity            :: ecs.Entity
add               :: ecs.add
get               :: ecs.get
has               :: ecs.has
create            :: ecs.create
destroy           :: ecs.destroy
get_group         :: ecs.get_group
get_position      :: ecs.get_position
get_rotation      :: ecs.get_rotation
get_scale         :: ecs.get_scale
get_tint          :: ecs.get_tint
set_position      :: ecs.set_position
set_rotation      :: ecs.set_rotation
set_scale         :: ecs.set_scale
set_tint          :: ecs.set_tint
is_enabled        :: ecs.is_enabled
set_enabled       :: ecs.set_enabled
is_valid          :: ecs.is_valid
exists            :: ecs.exists