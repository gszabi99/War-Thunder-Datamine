let { get_cur_circuit_block } = require("blkGetters")

let getCurCircuitUrl = @(urlId, defValue = null)
  get_cur_circuit_block()?[urlId] ?? defValue

return {
  getCurCircuitUrl
}
