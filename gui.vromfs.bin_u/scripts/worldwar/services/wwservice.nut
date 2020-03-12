::ww_service <- {
  function subscribeOperation(operationId, successCallback = null, errorCallback = null, requestOptions = null)
  {
    ::request_matching("worldwar.subscribe_operation_notify", successCallback,
                       errorCallback, { operationId = operationId }, requestOptions)
  }

  function unsubscribeOperation(operationId, successCallback = null, errorCallback = null, requestOptions = null)
  {
    ::request_matching("worldwar.unsubscribe_operation_notify", successCallback,
                       errorCallback, { operationId = operationId }, requestOptions)
  }
}