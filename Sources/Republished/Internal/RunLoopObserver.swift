import Foundation

class RunLoopObserver {
  let runLoop: CFRunLoop
  let runLoopObserver: CFRunLoopObserver

  init(
    runLoop: CFRunLoop = CFRunLoopGetMain(),
    activity: CFRunLoopActivity = .beforeWaiting,
    repeating: Bool = true,
    priorityIndex: CFIndex = -1,
    action: @escaping () -> Void
  ) {
    self.runLoop = runLoop
    self.runLoopObserver = CFRunLoopObserverCreateWithHandler(
      kCFAllocatorDefault,
      activity.rawValue,
      repeating,
      priorityIndex
    ) { _, _ in
      action()
    }
    CFRunLoopAddObserver(self.runLoop, self.runLoopObserver, .commonModes)
  }

  deinit {
    CFRunLoopRemoveObserver(self.runLoop, self.runLoopObserver, .commonModes)
  }
}
