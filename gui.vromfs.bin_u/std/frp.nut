local function subscribe(list, func){
  foreach(idx, observable in list)
    observable.subscribe(func)
}

return {
  subscribe
}
