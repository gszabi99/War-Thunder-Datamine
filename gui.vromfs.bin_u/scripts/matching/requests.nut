from "%scripts/matching/api.nut" import request_matching
from "%scripts/dagui_library.nut" import *

function request_nick_by_uid_batch(user_ids, cb = null) {
  request_matching("mproxy.nick_server_request", cb, null,
    { ids = user_ids }, { showError = false })
}

return freeze({
  request_nick_by_uid_batch = request_nick_by_uid_batch
})