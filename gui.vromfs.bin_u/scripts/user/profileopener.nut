let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { guiStartProfile } = require("%scripts/user/profileHandler.nut")

addListenersWithoutEnv({
  ShowCollection = @(p) guiStartProfile({ initialSheet = "Collections", selectedDecoratorId = p.selectedDecoratorId })
})