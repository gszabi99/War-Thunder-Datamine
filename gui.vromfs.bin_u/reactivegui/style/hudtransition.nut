local makeTransition = function (duration) {
  return {
    prop = AnimProp.opacity
    duration = duration
    easing = OutCubic
  }
}


local export = class {
  make = makeTransition
  fast = 0.2
  slow = 15.0
  _call = @(self) makeTransition(fast)
}()


return export
