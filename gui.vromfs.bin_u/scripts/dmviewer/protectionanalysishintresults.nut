from "%scripts/dagui_library.nut" import *


let enums = require("%sqStdLibs/helpers/enums.nut")

let results = {
  types = []
}

results.template <- {
  id = "" //used from type name
  checkOrder = -1
  criticalDamageTestName = ""
  checkParams = @(_params) false
}

local checkOrder = 0
enums.addTypes(results, {
  RICOCHETED = {
    checkOrder = checkOrder++
    checkParams = @(params) params?.lower?.ricochet == CHECK_PROT_RICOCHET_GUARANTEED &&
                            !params?.lower?.effectiveHit &&
                            !params?.upper?.effectiveHit
    criticalDamageTestName = "ricochet"
    color = "minorTextColor"
    loc = "hitcamera/result/ricochet"
    infoSrc = [ "lower", "upper"]
    params = [ "angle", "headingAngle", "ricochetProb" ]
  }
  POSSIBLEEFFECTIVE = {
    checkOrder = checkOrder++
    checkParams = @(params) (params?.upper?.effectiveHit ?? false)
      || ((params?.lower?.effectiveHit ?? false) && params?.lower?.ricochet == CHECK_PROT_RICOCHET_POSSIBLE)
    criticalDamageTestName = "possibleEffective"
    color = "cardProgressTextBonusColor"
    loc = "protection_analysis/result/possible_effective"
    infoSrc = [ "lower", "upper" ]
    params = [ "angle", "headingAngle", "penetratedArmor", "parts" ]
  }
  EFFECTIVE = {
    checkOrder = checkOrder++
    checkParams = @(params) (params?.lower?.effectiveHit ?? false)
      && params?.lower?.ricochet != CHECK_PROT_RICOCHET_POSSIBLE
    criticalDamageTestName = "effective"
    color = "goodTextColor"
    loc = "protection_analysis/result/effective"
    infoSrc = [ "lower", "upper"]
    params = [ "angle", "headingAngle", "penetratedArmor", "parts" ]
  }
  NOTPENETRATED = {
    checkOrder = checkOrder++
    checkParams = @(params) (params?.max?.effectiveHit ?? false) &&
      ((params?.max?.penetratedArmor?.generic ?? false) ||
        (params?.max?.penetratedArmor?.genericLongRod ?? false) ||
        (params?.max?.penetratedArmor?.explosiveFormedProjectile ?? false) ||
        (params?.max?.penetratedArmor?.cumulative ?? false))
    criticalDamageTestName = "notPenetrate"
    color = "badTextColor"
    loc = "protection_analysis/result/not_penetrated"
    infoSrc = [ "max" ]
    params = [ "angle", "headingAngle", "penetratedArmor", "ricochetProb" ]
  }
  INEFFECTIVE = {
    checkOrder = checkOrder++
    checkParams = @(_params) true
    criticalDamageTestName = "ineffective"
    color = "minorTextColor"
    loc = "protection_analysis/result/ineffective"
    infoSrc = [ "max"]
    params = [ "angle", "headingAngle", "ricochetProb" ]
  }
}, null, "id")
results.types.sort(@(a, b) a.checkOrder <=> b.checkOrder)

results.getResultTypeByParams <- function(params) {
  foreach (t in this.types)
    if (params?.criticalDamageTest == t.criticalDamageTestName || t.checkParams(params))
      return t
  return this.INEFFECTIVE
}

return results
