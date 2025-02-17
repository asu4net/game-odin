#+private 
package ecs
import "engine:global/sparse_set"

Raw_Component_Array :: Component_Array(struct{})

Component_Registry :: struct {
    component_array_map  : map[typeid] Raw_Component_Array,
    last_type_index      : u32,
}

init_component_registry :: proc(reg : ^Component_Registry) {
    assert(reg != nil)
    using reg
    component_array_map = make(map[typeid] Raw_Component_Array)
}

finish_component_registry :: proc(reg : ^Component_Registry) {
    assert(reg != nil)
    using reg
    for _, &array in component_array_map {
        delete(array.elements)
        sparse_set.finish(&array.occupied_ids)
    }
    delete(component_array_map)
    reg^ = {}
}

is_component_type_registered :: proc(reg : ^Component_Registry, $T : typeid) -> bool {
    assert(reg != nil)
    using reg
    data_type := typeid_of(T)
    return data_type in component_array_map
}

get_component_type_index :: proc(reg : ^Component_Registry, $T : typeid) -> u32 {
    assert(reg != nil)
    using reg
    data_type := typeid_of(T)
    assert(data_type in component_array_map)
    return component_array_map[data_type].type_index
}

register_component_type :: proc(reg : ^Component_Registry, $T : typeid) -> (component_array : ^Component_Array(T)) {
    assert(reg != nil)
    using reg
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

add_component_data :: proc(reg : ^Component_Registry, entity : Entity_ID, data : $T) -> (data_ptr : ^T, type_index : u32) {
    assert(reg != nil)
    using reg
    component_array := get_component_array(reg, T) if is_component_type_registered(reg, T) else register_component_type(reg, T)
    assert(!sparse_set.test(&component_array.occupied_ids, entity)) // assert not has component
    data_ptr = add_component_data_to_array(entity, component_array, data)
    type_index = component_array.type_index
    return
}

remove_component_data :: proc(reg : ^Component_Registry, entity : Entity_ID, $T : typeid) -> (type_index : u32) {
    assert(reg != nil)
    using reg
    assert(is_component_type_registered(reg, T))
    component_array := get_component_array(reg, T)
    assert(sparse_set.test(&component_array.occupied_ids, entity)) // assert has component
    remove_component_data_from_array(entity, component_array)
    type_index = component_array.type_index
    return
}

remove_all_component_data :: proc(reg : ^Component_Registry, entity : Entity_ID) {
    assert(reg != nil)
    using reg
    for _, &component_array in component_array_map {
        if sparse_set.test(&component_array.occupied_ids, entity) {
            deleted, last := sparse_set.remove(&component_array.occupied_ids, entity)
            //TODO: does this actually work? Since the arrays are generic
            if deleted != last do component_array.elements[deleted] = component_array.elements[last]
        }
    }
}

get_component_data :: proc(reg : ^Component_Registry, entity : Entity_ID, $T : typeid) -> ^T {
    assert(reg != nil)
    using reg
    assert(is_component_type_registered(reg, T))
    component_array := get_component_array(reg, T)
    assert(sparse_set.test(&component_array.occupied_ids, entity)) // assert has component
    return get_component_data_from_array(entity, component_array)
}

//-------------- Internal --------------

@(private="file")
Component_Array :: struct($T : typeid) {
    type_index    : u32,
    elements      : [dynamic] T,
    occupied_ids  : sparse_set.Sparse_Set,
}

@(private="file")
get_component_array :: proc(reg : ^Component_Registry, $T : typeid) -> ^Component_Array(T) {
    assert(reg != nil)
    using reg
    data_type := typeid_of(T)
    assert(data_type in component_array_map)
    return auto_cast &component_array_map[data_type]
}

@(private="file")
component_array_initialized :: proc(component_array : ^Component_Array($T)) -> bool {
    assert(component_array != nil)
    using component_array
    return sparse_set.initialized(&occupied_ids)
}

@(private="file")
add_component_data_to_array :: proc(entity : Entity_ID, component_array : ^Component_Array($T), data : T) -> ^T {
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
@(private="file")
remove_component_data_from_array :: proc(entity : Entity_ID, component_array : ^Component_Array($T)) {
    assert(component_array_initialized(component_array))
    using component_array
    deleted, last := sparse_set.remove(&occupied_ids, entity)
    if deleted != last do elements[deleted] = elements[last]
}

@(private="file")
get_component_data_from_array :: proc(entity : Entity_ID, component_array : ^Component_Array($T)) -> ^T {
    assert(component_array_initialized(component_array))
    using component_array
    dense_index := sparse_set.search(&occupied_ids, entity)
    return &elements[dense_index]
}