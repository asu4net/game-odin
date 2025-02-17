package ecs

import "base:intrinsics"
import "engine:global/sparse_set"
import "core:container/queue"

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

Un grupo tiene apunta al último elemento válido pertenecienta el grupo de varios data_arrays

*/

Entity_ID           ::      u32
NIL_ENTITY_ID       ::      sparse_set.INVALID_VALUE 
Raw_Component_Array ::      Component_Array(struct{})

MAX_DATA_TYPES :u32: 100 

CLEANUP_INTERVAL    ::      2 // Zero means each frame
MAX_ENTITIES        ::      10000 //TODO: Hacer el sparse set resizeable
MAX_NAME_LENGTH     ::      10

//TODO: Es esto una pool? Mover funcionalidad a un fichero separado
// - antes de mover tener en cuenta el sistema de grupos
// - relacionado: añadir una de common data para las entidades  

Component_Array :: struct($T : typeid) {
    type_index    : u32,
    elements      : [dynamic] T,
    occupied_ids  : sparse_set.Sparse_Set,
}

//name_to_string -> string(data[:len])
Name :: struct {
    data : [MAX_NAME_LENGTH] u8,
    len  : u32
}

name_init :: proc(name : ^Name, s : string) {
    name.len = u32(len(s))
    assert(name.len <= MAX_NAME_LENGTH)
    copy(name.data[:], s)
}

Signature :: bit_set[0..=MAX_DATA_TYPES]

Info :: struct {
    id        : Entity_ID,
    signature : Signature,
    name      : Name,
    valid     : bool,
    //TODO: children list
}

Registry :: struct {
    component_array_map  : map[typeid] Raw_Component_Array,
    last_type_index      : u32,
    avaliable_ids        : queue.Queue(Entity_ID),
    last_id              : Entity_ID,
    pending_destroy      : map[Entity_ID] struct{}, 
    occupied_ids         : sparse_set.Sparse_Set,
    infos                : [dynamic] Info, 
    cycles_since_cleaned : u32
}

registry_initialized :: proc() -> bool {
    return registry != nil
}

init_registry :: proc(instance : ^Registry) {
    assert(!registry_initialized())
    assert(instance != nil)
    registry = instance
    using registry
    component_array_map = make(map[typeid] Raw_Component_Array)
    pending_destroy = make(map[Entity_ID] struct{});
    queue.init(&avaliable_ids)
    sparse_set.init(&occupied_ids, MAX_ENTITIES)
    infos = make([dynamic] Info)
}

finish_registry :: proc() {
    assert(registry_initialized())
    using registry
    for _, &array in component_array_map {
        delete(array.elements)
        sparse_set.finish(&array.occupied_ids)
    }
    delete(component_array_map)
    queue.destroy(&avaliable_ids)
    sparse_set.finish(&occupied_ids)
    delete(infos)
    registry^ = {}
}

create_entity :: proc(name := "") -> (id : Entity_ID) {
    assert(registry_initialized())
    using registry
    
    if queue.len(avaliable_ids) == 0 {
        id = last_id
        last_id += 1
    } else {
        id = queue.front(&avaliable_ids)
        queue.pop_front(&avaliable_ids)
    }

    register_info(id, name)
    return
}

entity_exists :: proc(id : Entity_ID) -> bool {
    assert(registry_initialized())
    return sparse_set.test(&registry.occupied_ids, id)
}

entity_is_valid :: proc(id : Entity_ID) -> bool {
    assert(registry_initialized())
    assert(entity_exists(id))
    return get_entity_info(id).valid
}

entity_name :: proc(id : Entity_ID) -> ^Name {
    assert(registry_initialized())
    assert(entity_exists(id))
    return &get_entity_info(id).name
}

destroy_entity :: proc(id : Entity_ID) {
    assert(registry_initialized())
    assert(entity_is_valid(id))
    assert(id not_in registry.pending_destroy)
    get_entity_info(id).valid = false
    registry.pending_destroy[id] = {}
    //TODO: Para cuando los grupos hay que ver cómo hacer que no se ordene
}

clean_destroyed_entities :: proc() {
    assert(registry_initialized())
    using registry
    
    if cycles_since_cleaned < CLEANUP_INTERVAL {
        cycles_since_cleaned += 1
        return 
    }

    cycles_since_cleaned = 0

    for entity, _  in pending_destroy {
        
        for _, &component_array in component_array_map {
            if sparse_set.test(&component_array.occupied_ids, entity) {
                deleted, last := sparse_set.remove(&component_array.occupied_ids, entity)
                if deleted != last {
                    component_array.elements[deleted] = component_array.elements[last]
                }
            }
        }

        unregister_info(entity)
    }

    clear(&pending_destroy)
}

has_component :: proc(entity : Entity_ID, $T : typeid) -> bool {
    assert(registry_initialized())
    assert(entity_exists(entity))
    using registry
    type_index := component_array_map[typeid_of(T)].type_index
    info := get_entity_info(entity)
    return type_index in info.signature
}

add_component :: proc{ add_component_data, add_component_empty }

add_component_data :: proc(entity : Entity_ID, data : $T) -> ^T {
    #assert(intrinsics.type_is_struct(T))
    assert(registry_initialized())
    assert(entity_exists(entity))
    using registry
    component_array := get_component_array(T) if typeid_of(T) in component_array_map else register_component_type(T)
    assert(!has_component(entity, T))
    get_entity_info(entity).signature += { component_array.type_index } 
    return data_component_append(entity, component_array, data)
}

add_component_empty :: proc(entity : Entity_ID, $T : typeid) -> ^T {
    return add_component_data(entity, T{})
}

remove_component :: proc(entity : Entity_ID, $T : typeid) {
    assert(registry_initialized())
    assert(entity_exists(entity))
    assert(has_component(entity, T))
    component_array := get_component_array(T)
    get_entity_info(entity).signature -= { component_array.type_index }
    data_component_remove(entity, component_array)
}

get_component :: proc(entity : Entity_ID, $T : typeid) -> ^T {
    assert(registry_initialized())
    assert(entity_exists(entity))
    assert(has_component(entity, T))
    return data_component_get(entity, get_component_array(T))
}

register_component_type :: proc($T : typeid) -> (component_array : ^Component_Array(T)) {
    assert(registry_initialized())
    using registry
    assert(last_type_index + 1 <= MAX_DATA_TYPES)
    data_type := typeid_of(T)
    assert(data_type not_in component_array_map)
    raw_data_array := map_insert(&component_array_map, data_type, Raw_Component_Array{})
    component_array = cast(^Component_Array(T)) raw_data_array
    component_array.elements = make([dynamic]T)
    component_array.type_index = last_type_index
    sparse_set.init(&component_array.occupied_ids, MAX_ENTITIES)
    last_type_index += 1
    return
}

//-------------- Internal --------------

@(private="file")
registry : ^Registry

@(private = "file")
register_info :: proc(entity : Entity_ID, name : string) {
    assert(registry_initialized())
    using registry

    info : Info
    name_init(&info.name, name)
    info.id = entity
    info.valid = true

    // Hacemos lo mismo que con el data array :p
    dense_index := sparse_set.insert(&occupied_ids, entity)
    if len(infos) <= cast(int) dense_index {
        append_elem(&infos, info)
    } else {
        infos[dense_index] = info
    }
}

@(private = "file")
unregister_info :: proc(entity : Entity_ID) {
    assert(registry_initialized())
    using registry
    deleted, last := sparse_set.remove(&occupied_ids, entity)
    if deleted != last {
        infos[deleted] = infos[last]
    }
}

@(private = "file")
get_entity_info :: proc(id : Entity_ID) -> ^Info {
    assert(registry_initialized())
    using registry
    assert(entity_exists(id))
    dense_index := sparse_set.search(&occupied_ids, id)
    return &infos[dense_index]
}

@(private = "file")
component_array_initialized :: proc(component_array : ^Component_Array($T)) -> bool {
    assert(component_array != nil)
    using component_array
    return sparse_set.initialized(&occupied_ids)
}

@(private = "file")
get_component_array :: proc($T : typeid) -> ^Component_Array(T) {
    assert(registry_initialized())
    using registry
    data_type := typeid_of(T)
    assert(data_type in component_array_map)
    return auto_cast &component_array_map[data_type]
}

@(private = "file")
data_component_append :: proc(entity : Entity_ID, component_array : ^Component_Array($T), data : T) -> ^T {
    assert(component_array_initialized(component_array))
    using component_array
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
data_component_remove :: proc(entity : Entity_ID, component_array : ^Component_Array($T)) {
    assert(component_array_initialized(component_array))
    using component_array
    deleted, last := sparse_set.remove(&occupied_ids, entity)
    if deleted != last do elements[deleted] = elements[last]
}

@(private = "file")
data_component_get :: proc(entity : Entity_ID, component_array : ^Component_Array($T)) -> ^T {
    assert(component_array_initialized(component_array))
    using component_array
    dense_index := sparse_set.search(&occupied_ids, entity)
    return &elements[dense_index]
}