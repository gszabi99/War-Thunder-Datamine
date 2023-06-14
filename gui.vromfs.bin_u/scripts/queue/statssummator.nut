//checked for plus_string
from "%scripts/dagui_library.nut" import *


::StatsSummator <- {
  structTypes = ["array", "table"] //array of field names of elementry
  summableFields = ["players_cnt",  //types.
                    "1", "2", "3",  //arrays are summable by default
                    "4", "5"]
  summableTypes = ["integer", "float"]

  function sum (q1, q2) {
    local defVal = null
    foreach (q in [q1, q2])
      if (q != null) {
        defVal = type(q) == "array" ? [] : {}
        break
      }

    if (type(q1) != type(q2) && q1 != null && q2 != null)
      assert(false, "Attempt to sum structs of different types")

    if (type(q1) == "table" || type(q2) == "table")
      return this.sumTables(q1 ? q1 : defVal, q2 ? q2 : defVal)
    else if (type(q1) == "array" || type(q2) == "array")
      return this.sumArrays(q1 ? q1 : defVal, q2 ? q2 : defVal)
  }

  function sumArrays(q1, q2) {
    let res = []
    for (local i = 0; i < (max(q1.len(), q2.len())); i++) {
      let val1 = q1.len() >= i ? q1[i] : null
      let val2 = q2.len() >= i ? q2[i] : null
      local _sum = null
      let isStructs = isInArray(type(val1), this.structTypes) || isInArray(type(val2), this.structTypes)
      let summable = !isStructs && (isInArray(type(val1), this.summableTypes) || isInArray(type(val2), this.summableTypes))

      if (isStructs)
        _sum = this.sum(val1 ? val1 : null, val2 ? val2 : null)
      else if (summable) {
        //for save data type inchanged
        if (val1 == null)
          _sum = val2 + 0
        else
          _sum = val1 + (val2 == null ? 0 : val2)
      }
      else
        _sum = val1
      res.insert(i, _sum)
    }
    return res
  }

  function sumTables(q1, q2) {
    let res = {}
    foreach (key, val in q1) {
      if (isInArray(type(val), this.structTypes))
        res[key] <- this.sum(q1[key], getTblValue(key, q2, null))
      else if (isInArray(key, this.summableFields) && isInArray(type(val), this.summableTypes))
        res[key] <- val + (key in q2 ? q2[key] : 0)
      else
        res[key] <- val
    }

    foreach (key, val in q2) {
      if (key in res)
        continue
      if (isInArray(type(val), this.structTypes))
        res[key] <- this.sum(val, null)
      else
        res[key] <- val
    }
    return res
  }
}
