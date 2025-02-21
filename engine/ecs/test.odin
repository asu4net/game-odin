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

    // think of removing the _component. too long func
    
    add :: add_component

    add(e, A{ name = "alex" })
    add(e, B)
    add(e0, A)

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