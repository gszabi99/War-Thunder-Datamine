let { get_cur_circuit_block } = require("blkGetters")

let getCurCircuitOverride = @(urlId, defValue = null)
  get_cur_circuit_block()?[urlId] ?? defValue

return {
  getCurCircuitOverride
}
