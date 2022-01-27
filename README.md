# Republished

A collection of tools for working with observable objects in SwiftUI. 

* [Motivation](#motivation)
* [Tools](#tools)
* [Examples](#examples)
* [Installation](#installation)


## Motivation

Using an `ObservableObject` is a great way to connect your app's data model to your views. A property marked with the `@Published` attribute publishes changes during the willSet block causing the observable object's `ObjectWillChangePublisher` to emit. This is the primary mechanism SwiftUI uses to monitor changes to your data model.

A problem can occur when trying to compose multiple observable objects. For example, let's say we have a counter feature:

```swift
class CounterModel: ObservableObject {
  @Published var value = 0
}

struct CounterView: View {
  @ObservedObject var counter: CounterModel

  var body: some View {
    HStack {
      Button("-") { self.counter.value -= 1 }
      Text("\(self.counter.value)")
      Button("+") { self.counter.value += 1 }
    }
  }
}
```

and wanted to create an app with two counters and a total value, it might seem reasonable to do the following:

```swift
class AppModel: ObservableObject {
  @Published var first = CounterModel()
  @Published var second = CounterModel()

  var totalValue: Int { 
    self.first.value + self.second.value
  }
}

struct AppView: View {
  @StateObject var appModel = AppModel()

  var body: some View {
    VStack {
      CounterView(counter: appModel.first)
      CounterView(counter: appModel.second)
      Divider()
      Text("\(appModel.totalValue)")
    }
  }
}
```

However, this doesn't work how you might expect. The `totalValue` never changes, even though the counters are marked with the `@Published` attribute. This is because `CounterModel` is a class, so the `objectWillChange` publisher on `AppModel` will only emit when the counter instance changes, not when the counter value changes. 

There are multiple approach to observing changes to nested observable objects. This library offers one possible way by introducing the `@Republished` attribute. It also explores some additional ideas related to composing observable objects, such as dependency injection with the `@Dependency` attribute and working with a subset of an objects properties using `@ScopedValue`/`@ScopedBinding`.

## Tools

### Republished

A type that republishes changes of observable objects:

```swift
class AppModel: ObservableObject {
  @Republished var counter = CounterModel()
}
```

also works with optional observable objects and collections of observable objects:

```swift
class AppModel: ObservableObject {
  @Republished var optionalCounter: CounterModel?

  @Republished var counters: [CounterModel] = [
    CounterModel(),
    CounterModel(),
  ]
}
```

Republished objects with properties using the `@Dependency` attribute automatically inherit dependencies from their parent. This can be disabled like so:

```swift
class AppModel: ObservableObject {
  @Republished(inheritDependencies: false) var counter = CounterModel()
}
```

### synchronize(\_:\_:)

Synchronizes published properties:

```swift
class AppModel: ObservableObject {
  let first: CounterModel
  let second: CounterModel

  @Published var value = 0

  var cancellable: AnyCancellable?

  init(first: CounterModel, second: CounterModel) {
    self.first = first
    self.second = second
    
    self.cancellable = synchronize(
      &first.$value,
      &second.$value,
      &self.$value
    )
  }
}
```

### ScopedValue

A property wrapper type for observing a property on an environment object supplied by a parent or ancestor view.

```swift
struct CountView: View {
  @ScopedValue(\CounterModel.value) var count
  
  var body: some View {
    Text("Count: \(self.count)")
  }
}
```

### ScopedBinding

A property wrapper type that can read and write a value on an environment object supplied by a parent or ancestor view.

```swift
struct CounterView: View {
  @ScopedBinding(\CounterModel.value) var count

  var body: some View {
    HStack {
      Button("-") { self.count -= 1 }
      Text("\(self.count)")
      Button("+") { self.count += 1 }
    }
  }
}
```

### ScopedAction

A property wrapper type that can call a function on an environment object supplied by a parent or ancestor view.

```swift
struct CounterView: View {
  @ScopedValue(\CounterModel.value) var count
  @ScopedAction(CounterModel.decrement) var decrementCount
  @ScopedAction(CounterModel.increment) var incrementCount

  var body: some View {
    HStack {
      Button("-") { self.decrementCount() }
      Text("\(self.count)")
      Button("+") { self.incrementCount() }
    }
  }
}
```

### UnobservedEnvironmentObject

A property wrapper type for accessing an object supplied by a parent or ancestor view without observing changes.

```swift
struct CounterView: View {
  @ScopedValue(\CounterModel.value) var count
  @UnobservedEnvironmentObject var counter: CounterModel

  var body: some View {
    HStack {
      Button("-") { self.counter.decrement() }
      Text("\(self.count)")
      Button("+") { self.counter.increment() }
    }
  }
}
```

## Examples

## Installation

You can add Republished to an Xcode project by adding it as a package dependency.

> https://github.com/iampatbrown/Republished
