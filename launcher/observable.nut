let Observable = class{
  value=null
  subscribers=null
  function subscribe(func){
    this.subscribers.append(func)
  }
  function unsubscribe(func){
    let idx = this.subscribers.findindex(@(v) v==func)
    if (idx != null)
      this.subscribers.remove(idx)
  }
  function update(v){
    if (v==this.value)
      return
    this.value = v
    foreach (f in (clone this.subscribers))
      f(this.value)
  }
  function trigger(){
    foreach (f in (clone this.subscribers))
      f(this.value)
  }

  function mutate(cb){
    cb(this.value)
    foreach (f in (clone this.subscribers))
      f(this.value)
  }
  constructor(v=null){
    this.value=v
    this.subscribers = []
  }
}

return Observable
