from "blkGetters" import get_cur_circuit_block

let getCurCircuitOverride = @(urlId, defValue = null)
  get_cur_circuit_block()?[urlId] ?? defValue

return {
  getCurCircuitOverride
}
