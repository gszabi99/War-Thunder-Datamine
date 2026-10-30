from "%scripts/controls/input/combination.nut" import Combination
from "%scripts/dagui_library.nut" import *




let hasMarkupImage = @(input) (input.getMarkupData()?.view?.buttonImage ?? "") != ""
let getSingleShortcutConfig = @(input) hasMarkupImage(input) ? input.getConfig()
  : input.getConfig().__merge({ buttonImage = null })

let getShortcutConfig = @(input) input instanceof Combination
  ? input.getConfig().__merge({
      elements = input.elements.map(@(e) getSingleShortcutConfig(e).__merge({ activationTypeImg = null }))
    })
  : getSingleShortcutConfig(input)

return freeze({
  getShortcutConfig
})
