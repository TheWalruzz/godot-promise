# GdPromise - JS-like Promise implementation for Godot 4

In most use cases, Godot's signal handlers are enough for any asynchronous task that needs to be done in reaction to something.
However, signal syntax can be quite elaborate and verbose in more complex situations and can be confusing to people new to Godot. 
Also, signals can't do any error handling by themselves - they're just simple data busses, which might not be ideal for some use cases.

JS-like Promise-based approach presents a more high-level, action-based approach to asynchronous processing, while also presenting a way to handle any errors in case something went wrong in the Promise.

This addon is an implementation of this functionality in GDScript, allowing async operations in a simpler way, familiar to many people.

## Important changes in version 2.0.0

In order to make it possible for Promises to keep their values after resolving/rejecting, a new recommended way for awaiting Promises was created.

While this will still work for existing projects, awaiting for `settled` signal is now deprecated and should be replaced with `wait()` (see `Using await and Promise.PromiseResult` section below)

## Installation
* Copy `addons/promise/` to your `addons` directory.
* It's done!

## Basic usage
Like in JS, Promise can be created by instantiating a new object with a Callable passed.

```gdscript
var promise := Promise.new(
	func(resolve: Callable, reject: Callable):
		# put your code here and call resolve.call() or reject.call() at some point
		pass
)
```

`resolve` callable can be called without any arguments - resolved value will be treated as `null` in that case.

When Promise is created, passed Callable will be called in a deferred mode, i.e. it will be executed at the end of a current frame. This allows different callbacks to get connected properly regardless if Callable is run asynchronously or not.

### Resolution/rejection handling
There are three ways to handle success or failure:

#### Using `then()` and `catch()`
Similar to original Promises, you can add resolve/reject callbacks via `then()` and `catch()`. This will not pause the execution of the code.

```gdscript
Promise.new(
	func(resolve: Callable, reject: Callable):
		await get_tree().create_timer(1.0).timeout
		if randi_range(0, 10) > 5:
			# resolve() expects Variant value, so any type can be passed
			resolve.call("I'm bigger than 5!")
		else:
			# This implementation's error handling is done via Promise.Rejection class.
			# It's a simple data wrapper that contains `reason: String` and `stack: Array` (This is a standard get_stack() trace that won't work in non-debug builds).
			# You can always extend it to give more meaning type-wise.
			reject.call(Promise.Rejection.new("Lesser or equal to 5"))
).then(
	func(value: String):
		print(value)
).catch(
	func(rejection: Promise.Rejection):
		print(rejection.reason)
)
```

##### Note about `then()` chaining
At this moment, chaining multiple `then()` calls with Callables that return next Promise in the sequence is not supported. 
This effectively means that Promise doesn't behave the same as in JS, as the value returned by the callback in `then()` is completely ignored.
However, this kind of sequentiality can be worked around by using either nested `then()` calls or by using `await` keyword as described in the section below.

#### Using `await` and `Promise.PromiseResult`
If you want to wait until Promise settles (i.e. when Promise is either resolved or rejected), all you need to do is to `await` on a `wait()` function added at the end of the function chain.
Modifying previous example:
	
```gdscript
var result := await Promise.new(
	func(resolve: Callable, reject: Callable):
		await get_tree().create_timer(1.0).timeout
		if randi_range(0, 10) > 5:
			resolve.call("I'm bigger than 5!")
		else:
			reject.call(Promise.Rejection.new("Lesser or equal to 5"))
).wait()
prints(result.status, result.payload)
```

`result` contains `status: enum Promise.Status` (either `Promise.Status.RESOLVED` or `Promise.Status.REJECTED`) and `payload: Variant` (the value passed to `resolve()` or `Promise.Rejection` object).

Since GDScript doesn't have dedicated try-catch functionality, you can handle the result in if statements after the Promise settles:
	
```gdscript
	var result := await Promise.new(...).wait()
	if result.status == Promise.Status.RESOLVED:
		# do stuff
	else:
		# do error handling
```

To address the issue with sequential chaining of `then()` calls, you can wait for the returned Promise when the first Promise resolves and then use the Promise from the returned result:

```gdscript
var first_result := await Promise.new(
	func(resolve: Callable, reject: Callable):
		await get_tree().create_timer(1.0).timeout
		resolve.call(Promise.new(
			func(inner_resolve: Callable, inner_reject: Callable):
				# some other Promise...
		))
).wait()
if first_result.status == Promise.Status.RESOLVED:
	var second_result := await result1.payload.wait()
	# handle the result
```

Also, it is worth noting that you can await for `settled`, `resolved` and `rejected` signals specifically (but you should use `wait()` unless you know what you're doing).

### `await` with `then()`/`catch()`
In case you want to handle Promises in a functional way, but still retain the ability to `await` for their settlement, 
you can just put `wait()` after setting `then()` and `catch()` handlers.

```gdscript
var promise := Promise.new(
	func(resolve: Callable, reject: Callable):
		await get_tree().create_timer(1.0).timeout
		resolve.call("slow")
)
await promise.then(
	func(value: String):
		prints("Value: ", value)
).catch(
	func(rejection: Promise.Rejection):
		push_error(rejection.reason)
).wait()
# execution will pause until the Promise is settled and one of the passed callbacks is called.
```

## Utilities
This library also provides the implementation of `Promise.all()`, `Promise.any()`, `Promise.resolve()` and `Promise.reject()`.

### Promise.all()
This static method returns a Promise that resolves when all passed Promises resolve and rejects when at least one of them rejects.

```gdscript
var promise1 := Promise.new(
	func(resolve: Callable, reject: Callable):
		await get_tree().create_timer(1.0).timeout
		resolve.call("slow")
)
var promise2 := Promise.new(
	func(resolve: Callable, reject: Callable):
		await get_tree().create_timer(0.1).timeout
		resolve.call("quick")
)
var result := await Promise.all([promise1, promise2]).wait()
if result.status == Promise.Status.RESOLVED:
	print(result.payload) # ["slow", "quick"]
```

```gdscript
var promise1 := Promise.new(
	func(resolve: Callable, reject: Callable):
		await get_tree().create_timer(1.0).timeout
		reject.call(Promise.Rejection.new("Failed!"))
)
var promise2 := Promise.new(
	func(resolve: Callable, reject: Callable):
		await get_tree().create_timer(0.1).timeout
		resolve.call("quick")
)
var result := await Promise.all([promise1, promise2]).wait()
if result.status == Promise.Status.REJECTED:
	print(result.payload.reason) # "Failed!" - the Promise.Rejection that was thrown is passed
```

### Promise.any()
This static method returns a Promise that resolves when any of passed Promises resolves and rejects when all of them reject.

When one of them resolves:

```gdscript
var promise1 := Promise.new(
	func(resolve: Callable, reject: Callable):
		await get_tree().create_timer(1.0).timeout
		resolve.call("slow")
)
var promise2 := Promise.new(
	func(resolve: Callable, reject: Callable):
		await get_tree().create_timer(0.1).timeout
		resolve.call("quick")
)
var result := await Promise.any([promise1, promise2]).wait()
if result.status == Promise.Status.RESOLVED:
	print(result.payload) # "quick"
```

When all were rejected:

```gdscript
var promise1 := Promise.new(
	func(resolve: Callable, reject: Callable):
		await get_tree().create_timer(1.0).timeout
		reject.call(Promise.Rejection.new("Nope"))
)
var promise2 := Promise.new(
	func(resolve: Callable, reject: Callable):
		await get_tree().create_timer(0.1).timeout
		resolve.call(Promise.Rejection.new("Nope, but quicker"))
)
var result := await Promise.any([promise1, promise2]).wait()
if result.status == Promise.Status.REJECTED:
	# Promise.any() rejects with a special Promise.Rejection type: PromiseAnyRejection
	# It contains group property which stores all rejections.
	print(result.payload.group) # prints the array with rejections "Nope" and "Nope, but quicker"
```

### Promise.resolve()
This static method allows creation of a Promise that will immediately resolve to a specified value.

```gdscript
var result = await Promise.resolve("Hello!").wait()
print(result.payload) # "Hello!"
```

### Promise.reject()
This static method allows creation of a Promise that will immediately reject with a specified `Promise.Rejection`.

```gdscript
var result = await Promise.reject(Promise.Rejection.new("Error!")).wait()
print(result.payload.reason) # "Error!"
```

## Promisifying signals
Promise class contains small utilities to convert signals into Promises.

Using `from()` and `from_many()`, you can convert a signal or array of signals into a Promise and array of Promises, respectively.

```gdscript
signal value_changed(value: Variant)

var result := await Promise.from(value_changed).wait()
# result.payload is the first value emitted by signal
```

```gdscript
signal first_signal(value: Variant)
signal second_signal(value: Variant)

var result := await Promise.all(Promise.from_many([first_signal, second_signal])).wait()
# result.payload is an array of resolved values, in order of signals in the input array.
```

Note: promisified signals will never reject, since they do not implement any error handling by design.
Note 2: If signal has more arguments than one, the resolved value will be an array of values. Also, signals without any arguments will resolve to null.

# Unit tests
This library uses gdUnit4 as the unit test framework, but it is not provided in this repo. In order to run the tests, it needs to be installed manually (more information here: https://mikeschulze.github.io/gdUnit4/first_steps/install/). After that, tests can be run from the editor.

# License
Distributed under the [MIT License](https://github.com/TheWalruzz/godot-promise/blob/main/LICENSE).
