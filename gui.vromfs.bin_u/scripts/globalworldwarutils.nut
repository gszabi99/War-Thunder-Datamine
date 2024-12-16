from "%scripts/dagui_library.nut" import *

let {
  inviteToWwOperation = @() null,
  updateOperationPreviewAndDo = @() null,
  openOperationsOrQueues = @() null,
  isLastFlightWasWwBattle = Watched(false),
  openMainWnd = @() null,
  openOperationRewardPopup = @() null,
  joinOperationById = @() null,
  checkPlayWorldwarAccess = @() null,
  defaultDiffCode = DIFFICULTY_REALISTIC,
} = require_optional("%scripts/worldWar/worldWarUtils.nut")

return {
  inviteToWwOperation
  updateOperationPreviewAndDo
  openOperationsOrQueues
  isLastFlightWasWwBattle
  openWWMainWnd = openMainWnd
  openOperationRewardPopup
  joinOperationById
  checkPlayWorldwarAccess
  defaultDiffCode
}
