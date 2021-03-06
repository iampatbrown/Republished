import Foundation

// TODO: Maybe make this a Publisher
class RunLoopObserver {
  private let runLoop: CFRunLoop
  private let mode: CFRunLoopMode
  private let observer: CFRunLoopObserver

  init(
    runLoop: CFRunLoop = CFRunLoopGetMain(),
    mode: CFRunLoopMode = .commonModes,
    activity: CFRunLoopActivity = .beforeWaiting,
    repeating: Bool = true,
    priorityIndex: CFIndex = -1,
    action: @escaping () -> Void
  ) {
    self.runLoop = runLoop
    self.mode = mode
    self.observer = CFRunLoopObserverCreateWithHandler(
      kCFAllocatorDefault,
      activity.rawValue,
      repeating,
      priorityIndex
    ) { _, _ in
      action()
    }
    CFRunLoopAddObserver(self.runLoop, self.observer, self.mode)
  }

  deinit {
    CFRunLoopRemoveObserver(self.runLoop, self.observer, self.mode)
  }
}
