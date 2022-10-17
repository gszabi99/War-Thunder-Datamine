::StatsSummator <- {
  structTypes = ["array", "table"] //array of field names of elementry
  summableFields = ["players_cnt",  //types.
                    "1", "2", "3",  //arrays are summable by default
                    "4", "5"]
  summableTypes = ["integer", "float"]

  function sum (q1, q2)
  {
    local defVal = null
    foreach (q in [q1, q2])
      if (q != null)
      {
        defVal = typeof q == "array" ? [] : {}
        break
      }

    if (typeof q1 != typeof q2 && q1 != null && q2 != null)
      ::dagor.assertf(false, "Attempt to sum structs of different types")

    if (typeof q1 == "table" || typeof q2 == "table")
      return sumTables(q1 ? q1 : defVal, q2 ? q2 : defVal)
    else if (typeof q1 == "array" || typeof q2 == "array")
      return sumArrays(q1 ? q1 : defVal, q2 ? q2 : defVal)
  }

  function sumArrays(q1, q2)
  {
    let res = []
    for(local i = 0; i < (max(q1.len(), q2.len())); i++)
    {
      let val1 = q1.len() >= i ? q1[i] : null
      let val2 = q2.len() >= i ? q2[i] : null
      local _sum = null
      let isStructs = ::isInArray(typeof val1, structTypes) || ::isInArray(typeof val2, structTypes)
      let summable = !isStructs && (::isInArray(typeof val1, summableTypes) || ::isInArray(typeof val2, summableTypes))

      if (isStructs)
        _sum = sum(val1 ? val1 : null, val2 ? val2 : null)
      else if (summable)
      {
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

  function sumTables(q1, q2)
  {
    let res = {}
    foreach(key, val in q1)
    {
      if (::isInArray(typeof val, structTypes))
        res[key] <- sum(q1[key], ::getTblValue(key, q2, null))
      else if (::isInArray(key, summableFields) && ::isInArray(typeof val, summableTypes))
        res[key] <- val + (key in q2 ? q2[key] : 0)
      else
        res[key] <- val
    }

    foreach(key, val in q2)
    {
      if (key in res)
        continue
      if (::isInArray(typeof val, structTypes))
        res[key] <- sum(val, null)
      else
        res[key] <- val
    }
    return res
  }
}
