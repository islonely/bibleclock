module main

fn test_wrapping_index() {
	arr := [0, 1, 2, 3, 4, 5]

	assert wrapping_index(arr, -1) == arr[arr.len - 1]
	assert wrapping_index(arr, -10) == arr[arr.len - 4]
	assert wrapping_index(arr, 1) == arr[1]
	assert wrapping_index(arr, 237) == arr[3]
}
