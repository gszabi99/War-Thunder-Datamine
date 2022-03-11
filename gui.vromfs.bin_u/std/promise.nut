/*
  Promise
  copypasted from some JS code
*/

const P_PENDING = "pending"
const P_FULFILLED = "fulfilled"
const P_REJECTED = "rejected"

local Promise

Promise = class {
  _state = null
  resolve = null
  reject = null

  constructor(handler) {
    local state = {
      status = P_PENDING
      onFulfilledCallbacks = []
      onRejectedCallbacks = []
      value = null
    }
    _state = state
    resolve = function (v) {
      if (state.status == P_PENDING) {
        state.status = P_FULFILLED
        state.value = v
        state.onFulfilledCallbacks.each(@(fn) fn())
        state.onFulfilledCallbacks.clear()
        state.onRejectedCallbacks.clear()
      }
    }

    reject = function (v) {
      if (state.status == P_PENDING) {
        state.status = P_REJECTED
        state.value = v
        state.onRejectedCallbacks.each(@(fn) fn())
        state.onFulfilledCallbacks.clear()
        state.onRejectedCallbacks.clear()
      }
    }

    try {
      handler(resolve, reject)
    }
    catch (err) {
      reject(err)
    }
  }

  function then(onFulfilled, onRejected=@(...) null) {
      local state = _state
      return Promise(function(resolve, reject) { // -disable-warning: -ident-hides-ident
          if (state.status == P_PENDING) {
              state.onFulfilledCallbacks.append(function() {
                  try {
                      local fulfilledFromLastPromise = onFulfilled(state.value)
                      if (fulfilledFromLastPromise instanceof Promise) {
                          fulfilledFromLastPromise.then(resolve, reject)
                      } else {
                          resolve(fulfilledFromLastPromise)
                      }
                  } catch (err) {
                      reject(err)
                  }
              })
              state.onRejectedCallbacks.append(function() {
                  try {
                      local rejectedFromLastPromise = onRejected(state.value)
                      if (rejectedFromLastPromise instanceof Promise) {
                          rejectedFromLastPromise.then(resolve, reject)
                      } else {
                          reject(rejectedFromLastPromise)
                      }
                  } catch (err) {
                      reject(err)
                  }
              })
          }

          if (state.status == P_FULFILLED) {
              try {
                  local fulfilledFromLastPromise = onFulfilled(state.value)
                  if (fulfilledFromLastPromise instanceof Promise) {
                      fulfilledFromLastPromise.then(resolve, reject)
                  } else {
                      resolve(fulfilledFromLastPromise)
                  }
              } catch (err) {
                  reject(err)
              }

          }

          if (state.status == P_REJECTED) {
              try {
                  local rejectedFromLastPromise = onRejected(state.value)
                  if (rejectedFromLastPromise instanceof Promise) {
                      rejectedFromLastPromise.then(resolve, reject)
                  } else {
                      reject(rejectedFromLastPromise)
                  }
              } catch (err) {
                  reject(err)
              }
          }
      })

  }
}

return Promise