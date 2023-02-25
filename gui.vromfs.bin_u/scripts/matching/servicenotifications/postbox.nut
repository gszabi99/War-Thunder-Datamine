//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

::matching_rpc_subscribe("postbox.notify_mail", @(p) ::broadcastEvent("PostboxNewMsg", p))

return {
  addMail = @(data, succCb = null, errCb = null, reqOpt = null)
    ::request_matching("postbox.add_mail", succCb, errCb, data, reqOpt)

  notifyMailRead = @(mailId, succCb = null, errCb = null, reqOpt = null)
    ::request_matching("postbox.notify_read", succCb, errCb, { mail_id = mailId }, reqOpt)
}

