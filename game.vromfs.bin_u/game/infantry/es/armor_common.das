module armor_common shared
require ecs


def resupply_armor_for_soldier(eid : EntityId)
  var success = false
  query(eid) <| $ [es] (dm_parts__armorItemEids : EidList;
                        var dm_parts__partsArmor : FloatList&)
    for armorEid in dm_parts__armorItemEids
      query(armorEid) <| $ [es] (item__armorAmount : float;
                                 var item__armoredPartsIds : IntList&)
        for partId in item__armoredPartsIds
          dm_parts__partsArmor[partId] = item__armorAmount 
      query(armorEid) <| $ [es] (item__armorDurabilityMaxAmount : float;
                                 var item__armorDurabilityAmount : float&)
        success ||= (item__armorDurabilityAmount < item__armorDurabilityMaxAmount)
        item__armorDurabilityAmount = item__armorDurabilityMaxAmount
      query(armorEid) <| $ [es] (segmented_armor__segmentsEids : EidList)
        for armorSegmentEid in segmented_armor__segmentsEids
          query(armorSegmentEid) <| $ [es] (item__armorDurabilityMaxAmount : float;
                                            var item__armorDurabilityAmount : float&)
            success ||= (item__armorDurabilityAmount < item__armorDurabilityMaxAmount)
            item__armorDurabilityAmount = item__armorDurabilityMaxAmount
  return success
