from "%scripts/dagui_library.nut" import *

let { search } = require("%sqStdLibs/helpers/u.nut")
let { generatorsCollection } = require("%scripts/items/itemsManagerState.nut")


local itemGeneratorClass = null

function registerItemGeneratorClass(generatorClass) {
  if (itemGeneratorClass != null) {
    assert(false, "itemGeneratorClass already register")
    return
  }
  itemGeneratorClass = generatorClass
}

function addItemGenerator(itemDefDesc) {
  if (itemGeneratorClass == null) {
    assert(false, "itemGeneratorClass is not register")
    return
  }
  if (itemDefDesc?.Timestamp != generatorsCollection?[itemDefDesc.itemdefid].timestamp)
    generatorsCollection[itemDefDesc.itemdefid] <- itemGeneratorClass(itemDefDesc)
}

let findItemGeneratorByReceptUid = @(recipeUid)
  search(generatorsCollection, @(gen) search(gen.getRecipes(false),
    @(recipe) recipe.uid == recipeUid
     && (recipe.isDisassemble || !gen.isDelayedxchange())) != null) 

return {
  registerItemGeneratorClass
  addItemGenerator
  findItemGeneratorByReceptUid
}
