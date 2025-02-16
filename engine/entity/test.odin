package entity
import "core:fmt"

test :: proc() {

    A :: struct {
        name : string
    }
    
    B :: struct {
        
    }

    reg : Registry
    init(&reg)
    e := create()
    add(e, A{ name = "alex" })
    add(e, B)
    fmt.print(get(e, A).name)
    remove(e, B)
    destroy(e)
    clean_destroyed()
    fmt.print(get(e, A).name)
    clean_destroyed()
    fmt.print(get(e, A).name)
    clean_destroyed()
    //fmt.print(get(e, A).name)
    finish()
}