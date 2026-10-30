from "%scripts/user/profileHandler.nut" import guiStartProfile
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv

addListenersWithoutEnv({
  ShowCollection = @(p) guiStartProfile({ initialSheet = "Collections", selectedDecoratorId = p.selectedDecoratorId })
})