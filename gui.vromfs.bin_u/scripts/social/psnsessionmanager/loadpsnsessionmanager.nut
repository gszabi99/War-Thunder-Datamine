local { getPreferredVersion } = require("sonyLib/webApi.nut")
if (getPreferredVersion() == 2) {
  require("scripts/social/psnSessionManager/psnSessionManager.nut") // warning disable: -result-not-utilized
  require("scripts/social/psnGameSessionManager/psnGameSessionManager.nut") // warning disable: -result-not-utilized
}
else
  require("scripts/social/psnSessions.nut") // warning disable: -result-not-utilized

//Don't expect result of required module.