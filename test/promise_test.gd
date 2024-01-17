# GdUnit generated TestSuite
class_name PromiseTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from
const __source = 'res://addons/promise/promise.gd'


signal signal_no_params
signal signal_one_param(arg: Variant)


var wrapper: MockWrapper


func before_test():
	wrapper = spy(auto_free(MockWrapper.new()))
	add_child(wrapper)


func test_init() -> void:
	Promise.new(
		func(_resolve: Callable, _reject: Callable):
			wrapper.function_with_no_params()
	)
	verify(wrapper, 1).function_with_no_params()
	
	
func test_then() -> void:
	Promise.new(
		func(resolve: Callable, _reject: Callable):
			resolve.call("test")
	).then(
		func(value: String):
			wrapper.function_with_one_param(value)
	)
	verify(wrapper, 1).function_with_one_param("test")
	
	
func test_then_async() -> void:
	Promise.new(
		func(resolve: Callable, _reject: Callable):
			await await_millis(100)
			resolve.call("test")
	).then(
		func(value: String):
			wrapper.function_with_one_param(value)
	)
	await await_millis(110)
	verify(wrapper, 1).function_with_one_param("test")
	
	
func test_catch() -> void:
	var rejection := Promise.Rejection.new("test")
	Promise.new(
		func(_resolve: Callable, reject: Callable):
			reject.call(rejection)
	).catch(
		func(value: Promise.Rejection):
			wrapper.function_with_one_param(value)
	)
	verify(wrapper, 1).function_with_one_param(rejection)


func test_catch_async() -> void:
	var rejection := Promise.Rejection.new("test")
	Promise.new(
		func(_resolve: Callable, reject: Callable):
			await await_millis(100)
			reject.call(rejection)
	).catch(
		func(value: Promise.Rejection):
			wrapper.function_with_one_param(value)
	)
	await await_millis(110)
	verify(wrapper, 1).function_with_one_param(rejection)


func test_await_syntax_resolve() -> void:
	var promise := Promise.new(
		func(resolve: Callable, _reject: Callable):
			resolve.call("test")
	)
	var result = await promise.settled
	assert_int(result.status).is_equal(Promise.Status.RESOLVED)
	assert_str(result.payload).is_equal("test")
	
	
func test_await_syntax_resolve_async() -> void:
	var promise := Promise.new(
		func(resolve: Callable, _reject: Callable):
			await await_millis(100)
			resolve.call("test")
	)
	var result = await promise.settled
	assert_int(result.status).is_equal(Promise.Status.RESOLVED)
	assert_str(result.payload).is_equal("test")
	
	
func test_await_syntax_reject() -> void:
	var rejection := Promise.Rejection.new("test")
	var promise := Promise.new(
		func(_resolve: Callable, reject: Callable):
			reject.call(rejection)
	)
	var result = await promise.settled
	assert_int(result.status).is_equal(Promise.Status.REJECTED)
	assert_object(result.payload).is_instanceof(Promise.Rejection).is_same(rejection)
	
	
func test_await_syntax_reject_async() -> void:
	var rejection := Promise.Rejection.new("test")
	var promise := Promise.new(
		func(_resolve: Callable, reject: Callable):
			await await_millis(100)
			reject.call(rejection)
	)
	var result = await promise.settled
	assert_int(result.status).is_equal(Promise.Status.REJECTED)
	assert_object(result.payload).is_instanceof(Promise.Rejection).is_same(rejection)
	
	
func test_await_then() -> void:
	var promise := Promise.new(
		func(resolve: Callable, _reject: Callable):
			resolve.call("test")
	)
	await promise.then(func(value: String): wrapper.function_with_one_param(value)).settled
	verify(wrapper, 1).function_with_one_param("test")
	
	
func test_await_then_async() -> void:
	var promise := Promise.new(
		func(resolve: Callable, _reject: Callable):
			await await_millis(100)
			resolve.call("test")
	)
	await promise.then(func(value: String): wrapper.function_with_one_param(value)).settled
	verify(wrapper, 1).function_with_one_param("test")
	
	
func test_await_catch() -> void:
	var rejection := Promise.Rejection.new("test")
	var promise := Promise.new(
		func(_resolve: Callable, reject: Callable):
			reject.call(rejection)
	)
	await promise.catch(func(error: Promise.Rejection): wrapper.function_with_one_param(error)).settled
	verify(wrapper, 1).function_with_one_param(rejection)
	
	
func test_await_catch_async() -> void:
	var rejection := Promise.Rejection.new("test")
	var promise := Promise.new(
		func(_resolve: Callable, reject: Callable):
			await await_millis(100)
			reject.call(rejection)
	)
	await promise.catch(func(error: Promise.Rejection): wrapper.function_with_one_param(error)).settled
	verify(wrapper, 1).function_with_one_param(rejection)
	
	
func test_from_signal_no_params() -> void:
	Promise.from(signal_no_params).then(func(value): wrapper.function_with_one_param(value))
	signal_no_params.emit()
	verify(wrapper, 1).function_with_one_param(null)
	
	
func test_from_signal_one_param() -> void:
	Promise.from(signal_one_param).then(func(value: String): wrapper.function_with_one_param(value))
	signal_one_param.emit("test")
	verify(wrapper, 1).function_with_one_param("test")
	
	
func test_all_resolve() -> void:
	var promise1 := Promise.new(
		func(resolve: Callable, _reject: Callable):
			await await_millis(100)
			resolve.call("slow")
	)
	var promise2 := Promise.new(
		func(resolve: Callable, _reject: Callable):
			await await_millis(20)
			resolve.call("quick")
	)
	var result = await Promise.all([
		promise1,
		promise2
	]).settled
	assert_int(result.status).is_equal(Promise.Status.RESOLVED)
	assert_array(result.payload).has_size(2).contains_exactly(["slow", "quick"])
	
	
func test_all_reject() -> void:
	var rejection1 := Promise.Rejection.new("test1")
	var rejection2 := Promise.Rejection.new("test2")
	var promise1 := Promise.new(
		func(_resolve: Callable, reject: Callable):
			await await_millis(1000)
			reject.call(rejection1)
	)
	var promise2 := Promise.new(
		func(_resolve: Callable, reject: Callable):
			await await_millis(100)
			reject.call(rejection2)
	)
	var result = await Promise.all([
		promise1,
		promise2
	]).settled
	assert_int(result.status).is_equal(Promise.Status.REJECTED)
	assert_object(result.payload).is_instanceof(Promise.Rejection).is_same(rejection2)
	
	
func test_all_empty_array() -> void:
	var result = await Promise.all([]).settled
	assert_int(result.status).is_equal(Promise.Status.RESOLVED)
	assert_array(result.payload).is_empty()
	
	
func test_all_one_rejected() -> void:
	var rejection := Promise.Rejection.new("test2")
	var promise1 := Promise.new(
		func(resolve: Callable, _reject: Callable):
			await await_millis(1000)
			resolve.call("slow")
	)
	var promise2 := Promise.new(
		func(_resolve: Callable, reject: Callable):
			await await_millis(100)
			reject.call(rejection)
	)
	var result = await Promise.all([
		promise1,
		promise2
	]).settled
	assert_int(result.status).is_equal(Promise.Status.REJECTED)
	assert_object(result.payload).is_instanceof(Promise.Rejection).is_same(rejection)
	
	
func test_any_resolve() -> void:
	var promise1 := Promise.new(
		func(resolve: Callable, _reject: Callable):
			await await_millis(1000)
			resolve.call("slow")
	)
	var promise2 := Promise.new(
		func(resolve: Callable, _reject: Callable):
			await await_millis(100)
			resolve.call("quick")
	)
	var result = await Promise.any([
		promise1,
		promise2
	]).settled
	assert_int(result.status).is_equal(Promise.Status.RESOLVED)
	assert_str(result.payload).is_equal("quick")


func test_any_empty_array() -> void:
	var result = await Promise.any([]).settled
	assert_int(result.status).is_equal(Promise.Status.REJECTED)
	assert_object(result.payload).is_instanceof(Promise.PromiseAnyRejection)
	assert_str(result.payload.reason).is_equal(Promise.PROMISE_ANY_EMPTY_ARRAY)
	assert_array(result.payload.group).is_empty()

	
func test_any_one_resolved() -> void:
	var rejection := Promise.Rejection.new("test1")
	var promise1 := Promise.new(
		func(resolve: Callable, _reject: Callable):
			await await_millis(1000)
			resolve.call("slow")
	)
	var promise2 := Promise.new(
		func(_resolve: Callable, reject: Callable):
			await await_millis(100)
			reject.call(rejection)
	)
	var result = await Promise.any([
		promise1,
		promise2
	]).settled
	assert_int(result.status).is_equal(Promise.Status.RESOLVED)
	assert_str(result.payload).is_equal("slow")
	
	
func test_any_reject() -> void:
	var rejection1 := Promise.Rejection.new("test1")
	var rejection2 := Promise.Rejection.new("test2")
	var promise1 := Promise.new(
		func(_resolve: Callable, reject: Callable):
			await await_millis(300)
			reject.call(rejection1)
	)
	var promise2 := Promise.new(
		func(_resolve: Callable, reject: Callable):
			await await_millis(100)
			reject.call(rejection2)
	)
	var result = await Promise.any([
		promise1,
		promise2
	]).settled
	assert_int(result.status).is_equal(Promise.Status.REJECTED)
	assert_object(result.payload).is_instanceof(Promise.PromiseAnyRejection)
	assert_array(result.payload.group).has_size(2).contains_exactly([rejection1, rejection2])


class MockWrapper extends Node:
	func function_with_no_params():
		pass
		
		
	func function_with_one_param(_arg: Variant):
		pass
