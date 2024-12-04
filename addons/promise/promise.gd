# GDPromise v2.0.0
extends RefCounted
class_name Promise


enum Status {
	RESOLVED,
	REJECTED
}


signal settled(status: PromiseResult)
signal resolved(value: Variant)
signal rejected(reason: Rejection)


## Generic rejection reason
const PROMISE_REJECTED := "Promise rejected"
const PROMISE_ANY_EMPTY_ARRAY := "Promise.any() needs at least one Promise"


var is_settled := false
var last_result: PromiseResult = null


func _init(callable: Callable):
	resolved.connect(
		func(value: Variant):
			settled.emit(PromiseResult.new(Status.RESOLVED, value)), 
		CONNECT_ONE_SHOT
	)
	rejected.connect(
		func(rejection: Rejection):
			settled.emit(PromiseResult.new(Status.REJECTED, rejection)), 
		CONNECT_ONE_SHOT
	)
	settled.connect(
		func(result: PromiseResult):
			is_settled = true
			last_result = result,
		CONNECT_ONE_SHOT
	)
	
	callable.call_deferred(
		func(value: Variant = null):
			if not is_settled:
				resolved.emit(value),
		func(rejection: Rejection):
			if not is_settled:
				rejected.emit(rejection)
	)
	
func wait() -> PromiseResult:
	if is_settled:
		return last_result
	var result = await settled
	return result
	
	
func then(resolved_callback: Callable) -> Promise:
	if is_settled and last_result and last_result.status == Promise.Status.RESOLVED:
		resolved_callback.call(last_result.payload)
	else:
		resolved.connect(
			resolved_callback, 
			CONNECT_ONE_SHOT
		)
	return self
	
	
func catch(rejected_callback: Callable) -> Promise:
	if is_settled and last_result and last_result.status == Promise.Status.REJECTED:
		rejected_callback.call(last_result.payload)
	else:
		rejected.connect(
			rejected_callback, 
			CONNECT_ONE_SHOT
		)
	return self


static func resolve(value: Variant = null) -> Promise:
	return Promise.new(func(resolve_func: Callable, _reject_func: Callable):
		resolve_func.call(value)
	)
	
	
static func reject(value: Promise.Rejection) -> Promise:
	return Promise.new(func(_resolve_func: Callable, reject_func: Callable):
		reject_func.call(value)
	)
	
	
static func from(input_signal: Signal) -> Promise:
	return Promise.new(
		func(resolve_func: Callable, _reject_func: Callable):
			var number_of_args := input_signal.get_object().get_signal_list() \
				.filter(func(signal_info: Dictionary) -> bool: return signal_info["name"] == input_signal.get_name()) \
				.map(func(signal_info: Dictionary) -> int: return signal_info["args"].size()) \
				.front() as int
			
			if number_of_args == 0:
				await input_signal
				resolve_func.call(null)
			else:
				# this will return either a value or an array of values
				var result = await input_signal
				resolve_func.call(result)
	)


static func from_many(input_signals: Array[Signal]) -> Array[Promise]:
	var result: Array[Promise] = []
	result.assign(input_signals.map(
		func(input_signal: Signal): 
			return Promise.from(input_signal)
	))
	return result

	
static func all(promises: Array[Promise]) -> Promise:
	return Promise.new(
		func(resolve_func: Callable, reject_func: Callable):
			if promises.size() == 0:
				resolve_func.call([])
				return

			var resolved_promises: Array[bool] = []
			var results := []
			results.resize(promises.size())
			resolved_promises.resize(promises.size())
			resolved_promises.fill(false)
	
			for i in promises.size():
				promises[i].then(
					func(value: Variant):
						results[i] = value
						resolved_promises[i] = true
						if resolved_promises.all(func(is_resolved: bool): return is_resolved):
							resolve_func.call(results)
				).catch(
					func(rejection: Rejection):
						reject_func.call(rejection)
				)
	)
	
	
static func any(promises: Array[Promise]) -> Promise:
	return Promise.new(
		func(resolve_func: Callable, reject_func: Callable):
			if promises.size() == 0:
				reject_func.call(PromiseAnyRejection.new(PROMISE_ANY_EMPTY_ARRAY, []))
				return
			
			var rejected_promises: Array[bool] = []
			var rejections: Array[Rejection] = []
			rejections.resize(promises.size())
			rejected_promises.resize(promises.size())
			rejected_promises.fill(false)
	
			for i in promises.size():
				promises[i].then(
					func(value: Variant): 
						resolve_func.call(value)
				).catch(
					func(rejection: Rejection):
						rejections[i] = rejection
						rejected_promises[i] = true
						if rejected_promises.all(func(value: bool): return value):
							reject_func.call(PromiseAnyRejection.new(PROMISE_REJECTED, rejections))
				)
	)


class PromiseResult:
	var status: Status
	var payload: Variant
	
	func _init(_status: Status, _payload: Variant):
		status = _status
		payload = _payload
		
		
class Rejection:
	var reason: String
	var stack: Array
	
	func _init(_reason: String):
		reason = _reason
		stack = get_stack() if OS.is_debug_build() else []
		
		
	func as_string() -> String:
		return ("%s\n" % reason) + "\n".join(
			stack.map(
				func(dict: Dictionary) -> String: 
					return "At %s:%i:%s" % [dict["source"], dict["line"], dict["function"]]
		))
	

class PromiseAnyRejection extends Rejection:
	var group: Array[Rejection]
	
	func _init(_reason: String, _group: Array[Rejection]):
		super(_reason)
		group = _group
