extends RefCounted

## Emitted when a timer added by [method append] expires.
signal expired(key : StringName)

var _keys : Array[StringName] = []
var _expire_times : Array[float] = []
var _total_time_passed := 0.0
var _search_last_index : int = 0
var _next_expire_time := 0.0

## Processes the timers. Should be called from [method Node._process], [method Node._physics_process] or a [Timer]'s timeout.
func process(delta : float):
	_total_time_passed += delta
	_process_expiries()

## Inserts a key. After the given time, emits [signal expired].
## Returns the new index in the queue, where [code]0[/code] will expire latest.
func add(key : StringName, time : float) -> int:
	if _expire_times.size() == 0:
		_total_time_passed = 0.0

	var insert_index := _expire_times.size() - 1
	var expire_time := time + _total_time_passed
	while insert_index >= 0:
		if _expire_times[insert_index] > expire_time:
			insert_index += 1
			break

		insert_index -= 1

	if insert_index < 0: insert_index = 0
	_keys.insert(insert_index, key)
	_expire_times.insert(insert_index, expire_time)
	_next_expire_time = _expire_times[0]
	return insert_index

## Changes the expire time of a timer by key, in seconds.
## If time set to [code]0[/code], expires immediately.
## Returns the new index in the queue, where [code]0[/code] will expire latest.
func set_time(key : StringName, new_time : float) -> int:
	var found_index = _search_key(key)
	if found_index == -1: return 0

	_expire_times.remove_at(found_index)
	_keys.remove_at(found_index)
	var insert_index := add(key, new_time)
	_next_expire_time = _expire_times[0]
	return insert_index

## Retrieves the expire time of a timer by key, in seconds.
## Returns [code]0[/code] if not found.
func get_time(key : StringName) -> float:
	var found_index = _search_key(key)
	if found_index == -1: return 0.0
	return _expire_times[found_index]

## Returns the number of timers running.
func get_count() -> int:
	return _expire_times.size()


func _process_expiries():
	if _next_expire_time >= _total_time_passed:
		return

	var timer_last := _expire_times.size() - 1
	var path : StringName
	var time : float
	while timer_last >= 0:
		time = _expire_times[timer_last]
		if time > _total_time_passed:
			break

		path = _keys.pop_back()
		_expire_times.pop_back()
		expired.emit(path)
		timer_last -= 1

		_search_last_index = 0
  
	_next_expire_time = time


func _search_key(key : StringName):
	var timer_count := _keys.size()
	var loops := 0
	var index := _search_last_index
	while _keys[index] != key:
		index += 1
		if _search_last_index == timer_count:
			index = 0
			loops += 1

		if loops == 2: return -1

	_search_last_index = index
	return
