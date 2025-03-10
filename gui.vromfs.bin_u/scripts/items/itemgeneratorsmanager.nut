from "%scripts/dagui_library.nut" import *

let { search } = require("%sqStdLibs/helpers/u.nut")

local itemGeneratorClass = null

let collection = {}

function registerItemGeneratorClass(generatorClass) {
  if (itemGeneratorClass != null) {
    assert(false, "itemGeneratorClass already register")
    return
  }
  itemGeneratorClass = generatorClass
}

function getItemGenerator(itemdefId) {
  ::ItemsManager.findItemById(itemdefId) 
  return collection?[itemdefId]
}

function addItemGenerator(itemDefDesc) {
  if (itemGeneratorClass == null) {
    assert(false, "itemGeneratorClass is not register")
    return
  }
  if (itemDefDesc?.Timestamp != collection?[itemDefDesc.itemdefid].timestamp)
    collection[itemDefDesc.itemdefid] <- itemGeneratorClass(itemDefDesc)
}

let findItemGeneratorByReceptUid = @(recipeUid)
  search(collection, @(gen) search(gen.getRecipes(false),
    @(recipe) recipe.uid == recipeUid
     && (recipe.isDisassemble || !gen.isDelayedxchange())) != null) 

return {
  registerItemGeneratorClass
  getItemGenerator
  addItemGenerator
  findItemGeneratorByReceptUid
}
