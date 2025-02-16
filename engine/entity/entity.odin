package entity

import "base:intrinsics"
import "engine:global/sparse_set"
import "core:container/queue"
import "core:fmt"

/*

///////////////////////
//: Sistema de grupos
///////////////////////

- para esta parte del proyecto usar bump allocators, o el equivalente en odin

-------------- entity.Data (A) --------------

[ A1 | A2 | A3 | A4 | A5 | A6 ]
   ^           ^         
   |           |         
 Start        End  (Grupo de (A, B, C))
 
-------------- entity.Data (B) --------------

 [ B1 | B2 | B3 | B4 | B5 | B6 ]
   ^           ^         
   |           |         
 Start        End  (Grupo de (A, B, C))

-------------- entity.Data (C) --------------

 [ C1 | C2 | C3 ]
   ^       ^         
   |       |         
 Start    End  (Grupo de (A, B, C))

-------------- Sparse Set (entity → index en packed array) --------------

Entity 10 -> index 0 (A, B, C)
Entity 20 -> index 1 (A, B, C)
Entity 30 -> index 2 (A, B, C)
Entity 40 -> index 3 (A, B)
Entity 50 -> index 4 (A, B)
Entity 60 -> index 5 (A, B)

-------------- Mapa de Grupos --------------

Grupo (A, B) → { Start: 3, End: 5 }
Grupo (A, B, C) → { Start: 0, End: 2 }

*/

Entity_ID      :: u32
NIL_ENTITY_ID  :: sparse_set.INVALID_VALUE 
MAX_ENTITIES   :: 10000 //TODO: Hacer el sparse set resizeable
Raw_Data_Array :: Data_Array(struct{})

//TODO: Es esto una pool? Mover funcionalidad a un fichero separado
// - antes de mover tener en cuenta el sistema de grupos
// - relacionado: añadir una de common data para las entidades  

Data_Array :: struct($T : typeid) {
    element_type  : typeid,
    elements      : [dynamic] T,
    occupied_ids  : sparse_set.Sparse_Set,
}

Registry :: struct {
    data_array_map : map[typeid] Raw_Data_Array,
    avaliable_ids  : queue.Queue(Entity_ID),
    last_id        : Entity_ID
}

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
    remove(e, A)
    finish()
}

initialized :: proc() -> bool {
    return registry != nil
}

init :: proc(instance : ^Registry) {
    assert(!initialized())
    assert(instance != nil)
    registry = instance
    using registry

    data_array_map = make(map[typeid] Raw_Data_Array)
    queue.init(&avaliable_ids)
}

finish :: proc() {
    assert(initialized())
    using registry
    for _, &array in data_array_map {
        delete(array.elements)
        sparse_set.finish(&array.occupied_ids)
    }
    delete(data_array_map)
    queue.destroy(&avaliable_ids)
}

create :: proc() -> (id : Entity_ID) {
    assert(initialized())
    using registry
    
    if queue.len(avaliable_ids) == 0 {
        id = last_id
        last_id += 1
    } else {
        id = queue.front(&avaliable_ids)
        queue.pop_front(&avaliable_ids)
    }
    return
}

has :: proc(entity : Entity_ID, $T : typeid) -> bool {
    assert(initialized())
    using registry
    data_type := typeid_of(T)
    if data_type in data_array_map {
        data_array := data_array_map[data_type]
        return sparse_set.test(&data_array.occupied_ids, entity)   
    }
    return false
}

add :: proc{ add_data, add_empty }

add_data :: proc(entity : Entity_ID, data : $T) -> ^T {
    #assert(intrinsics.type_is_struct(T))
    assert(initialized())
    assert(!has(entity, T))
    using registry
    data_array := get_data_array(T) if typeid_of(T) in data_array_map else register(T)
    return data_array_append(entity, data_array, data)
}

add_empty :: proc(entity : Entity_ID, $T : typeid) -> ^T {
    return add_data(entity, T{})
}

remove :: proc(entity : Entity_ID, $T : typeid) {
    assert(initialized())
    assert(has(entity, T))
    data_array_remove(entity, get_data_array(T))
}

get :: proc(entity : Entity_ID, $T : typeid) -> ^T {
    assert(initialized())
    assert(has(entity, T))
    return data_array_get(entity, get_data_array(T))
}

register :: proc($T : typeid) -> (data_array : ^Data_Array(T)) {
    assert(initialized())
    using registry
    data_type := typeid_of(T)
    assert(data_type not_in data_array_map)
    raw_data_array := map_insert(&data_array_map, data_type, Raw_Data_Array{})
    data_array = cast(^Data_Array(T)) raw_data_array
    data_array.elements = make([dynamic]T)
    data_array.element_type = data_type
    sparse_set.init(&data_array.occupied_ids, MAX_ENTITIES)
    return
}

//-------------- Internal --------------

@(private="file")
registry : ^Registry

@(private = "file")
data_array_initialized :: proc(data_array : ^Data_Array($T)) -> bool {
    assert(data_array != nil)
    using data_array
    return sparse_set.initialized(&occupied_ids)
}

@(private = "file")
get_data_array :: proc($T : typeid) -> ^Data_Array(T) {
    assert(initialized())
    using registry
    data_type := typeid_of(T)
    assert(data_type in data_array_map)
    return auto_cast &data_array_map[data_type]
}

@(private = "file")
data_array_append :: proc(entity : Entity_ID, data_array : ^Data_Array($T), data : T) -> ^T {
    assert(data_array_initialized(data_array))
    using data_array
    dense_index := sparse_set.insert(&occupied_ids, entity)
    if len(elements) <= cast(int) dense_index {
        append_elem(&elements, data)
    } else {
        elements[dense_index] = data
    }
    return &elements[dense_index]
}

// TODO: Revisar cómo aplica el tema del borrado con delay a los componentes
@(private = "file")
data_array_remove :: proc(entity : Entity_ID, data_array : ^Data_Array($T)) {
    assert(data_array_initialized(data_array))
    using data_array
    deleted, last := sparse_set.remove(&occupied_ids, entity)
    if deleted != last do elements[deleted] = elements[last]
}

@(private = "file")
data_array_get :: proc(entity : Entity_ID, data_array : ^Data_Array($T)) -> ^T {
    assert(data_array_initialized(data_array))
    using data_array
    dense_index := sparse_set.search(&occupied_ids, entity)
    return &elements[dense_index]
}