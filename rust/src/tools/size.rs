pub fn size_of_vec<T>(vec: &Vec<T>) -> usize {
    let element_size = std::mem::size_of::<T>();
    let metadata_size = std::mem::size_of::<Vec<T>>();
    vec.len() * element_size + metadata_size
}
