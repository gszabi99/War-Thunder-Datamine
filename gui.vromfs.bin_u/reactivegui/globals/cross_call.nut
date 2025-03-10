
#allow-root-table
let perform_cross_call = getroottable()["perform_cross_call"]

let cross_call = class {
  path = null

  constructor () {
    this.path = []
  }

  function _get(idx) {
    this.path.append(idx)
    return this
  }

  function _call(_self, ...) {
    let args = [this]
    args.append(this.path)
    args.extend(vargv)
    let result = perform_cross_call.acall(args)
    this.path.clear()
    return result
  }
}()

return cross_call
