from "%scripts/matching/api.nut" import matchingRpcSubscribe, request_matching
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%scripts/dagui_library.nut" import *

matchingRpcSubscribe("postbox.notify_mail", @(p) broadcastEvent("PostboxNewMsg", p))

return freeze({
  addMail = @(data, succCb = null, errCb = null, reqOpt = null)
    request_matching("postbox.add_mail", succCb, errCb, data, reqOpt)

  notifyMailRead = @(mailId, succCb = null, errCb = null, reqOpt = null)
    request_matching("postbox.notify_read", succCb, errCb, { mail_id = mailId }, reqOpt)
})
