package ecs
import "core:fmt"

test :: proc() {

    A :: struct {
        name : string
    }
    
    B :: struct {
        
    }

    reg : Entity_Registry
    init_registry(&reg)
    e := create_entity()
    add_component(e, A{ name = "alex" })
    add_component(e, B)
    
    fmt.print(get_component(e, A).name)
    remove_component(e, B)
    destroy_entity(e)
    clean_destroyed_entities()
    fmt.print(get_component(e, A).name)
    clean_destroyed_entities()
    fmt.print(get_component(e, A).name)
    clean_destroyed_entities()
    //fmt.print(get(e, A).name)
    finish_registry()
}