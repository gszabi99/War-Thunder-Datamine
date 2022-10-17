let { Watched, Computed } = require("frp")

let xboxUids = Watched({
  uid2xbox = {}
  xbox2uid = {}
})

let friendsUids = Watched({})

let uid2xbox = Computed(@() xboxUids.value.uid2xbox)
let xbox2uid = Computed(@() xboxUids.value.xbox2uid)


let function updateUidsMapping(xbox2UidNewList) {
  let res = clone xboxUids.value
  res.xbox2uid = res.xbox2uid.__merge(xbox2UidNewList)
  let newUid2xbox = {}
  foreach (k,v in xbox2UidNewList)
    newUid2xbox[v] <- k
  res.uid2xbox = res.uid2xbox.__merge(newUid2xbox)
  xboxUids.update(res)
}


return {
  uid2xbox
  xbox2uid
  updateUidsMapping
  friendsUids
}