from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv

let { guiStartProfile } = require("%scripts/user/profileHandler.nut")

addListenersWithoutEnv({
  ShowCollection = @(p) guiStartProfile({ initialSheet = "Collections", selectedDecoratorId = p.selectedDecoratorId })
})