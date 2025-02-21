package ecs
import "core:fmt"

test :: proc() {

    A :: struct {
        name : string
    }
    
    B :: struct {
        
    }

    reg : Entity_Registry
    init(&reg)
    e := create()
    e0 := create()
    add_component(e, A{ name = "alex" })
    add_component(e, B)
    add_component(e0, A)

    //get_entity_group(A, B)
    fmt.print(get_component(e, A).name)
    group := get_group(A, B)
    remove_component(e, B)
    destroy(e)
    clean_destroyed()
    fmt.print(get_component(e, A).name)
    clean_destroyed()
    fmt.print(get_component(e, A).name)
    clean_destroyed()
    //fmt.print(get(e, A).name)
    finish()
}