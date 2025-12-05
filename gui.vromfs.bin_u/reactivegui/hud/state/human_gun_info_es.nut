from "%rGui/globals/ui_library.nut" import *
from "dagor.math" import Point2
import "%sqstd/ecs.nut" as ecs

let { mkFrameIncrementObservable } = require("%rGui/globals/ec_to_watched.nut")
let { controlledHeroEid } = require("%appGlobals/controlledHeroEid.nut")

let humanCurGunSlotIdx = Watched(-1)

enum WeaponSlots {
  EWS_PRIMARY
  EWS_SECONDARY
  EWS_TERTIARY
  EWS_MELEE
  EWS_GRENADE
  EWS_SPECIAL
  EWS_NUM
}

let weaponSlotsRaw = array(WeaponSlots.EWS_NUM)
let weaponSlots = array(WeaponSlots.EWS_NUM)
foreach (idx, _v in weaponSlotsRaw) {
  weaponSlotsRaw[idx] = mkFrameIncrementObservable(null)
  weaponSlots[idx] = weaponSlotsRaw[idx].state
}

let weaponSlotsStatic = array(WeaponSlots.EWS_NUM, null)
let { weaponSlotsGen, weaponSlotsGenSetValue } = mkFrameIncrementObservable(0, "weaponSlotsGen")
let { heroModsByWeaponSlotRaw, heroModsByWeaponSlotRawModify } = mkFrameIncrementObservable(array(WeaponSlots.EWS_NUM), "heroModsByWeaponSlotRaw")


let anyItemComps = {
  comps_rq = ["watchedPlayerItem"]
  comps_ro = [
    ["weaponMod", ecs.TYPE_TAG, null],
    ["animchar__res", ecs.TYPE_STRING, ""],
    ["item__weapTemplate", ecs.TYPE_STRING, ""],
    ["gun__maxAmmo", ecs.TYPE_INT, 0],
    ["gun__owner", ecs.TYPE_EID, ecs.INVALID_ENTITY_ID],
    ["item__ownerEid", ecs.TYPE_EID, ecs.INVALID_ENTITY_ID]
  ]
}

let mkItemDescFromComp = @(eid, comp) {
  eid
  haveAmmo = comp["gun__firingModeName"] != ""
  maxAmmo = comp["gun__maxAmmo"]
  iconTemplate = comp["item__weapTemplate"]
  animchar = comp["animchar__res"]
  weaponMod = comp["weaponMod"] != null
  ownerEid = comp["gun__owner"]
  itemOwnerEid = comp["item__ownerEid"]
}

ecs.register_es("human_curgunslot_ui_es",
  {
    [["onInit", ecs.EventComponentChanged]] = function(_, eid, comp) {
      if (controlledHeroEid.get() != eid)
        return

      humanCurGunSlotIdx.set(comp.human_weap__currentGunSlot)
    }
    onDestroy = function(eid, _) {
      if (controlledHeroEid.get() != eid)
        return
      humanCurGunSlotIdx.set(-1)
    }
  },
  {
    comps_rq = ["watchedByPlr"]
    comps_track = [
      ["human_weap__currentGunSlot", ecs.TYPE_INT, -1],
    ]
  }
)


let launcherQuery = ecs.SqQuery("launcherQuery", {
  comps_ro = [["drone_launcher__nextUseAtTime", ecs.TYPE_FLOAT, 0.0]]
})
function getLauncherNextUseAtTime(eid) {
  local nextUseAtTime = 0.0
  launcherQuery(eid, function(_, comp) {
    nextUseAtTime = comp.drone_launcher__nextUseAtTime
  })
  return nextUseAtTime
}


ecs.register_es("hero_ui_weapons_es",
  {
    [["onInit", ecs.EventComponentChanged]] = function(_, eid, comp){
      let idx = comp["slot_attach__weaponSlotIdx"]
      if (idx != WeaponSlots.EWS_SPECIAL && comp["multiple_guns_slot_gun_hidden"] != null)
        return

      if (idx < 0 || idx >= WeaponSlots.EWS_NUM)
        return

      let weaponMod = comp["weaponMod"] != null
      if (weaponMod) {
        let modCurAmmo = comp["gun__ammo"]
        let modTotalAmmo = comp["gun__totalAmmo"]
        let isModActive = comp["weapon_mod__active"]
        let attachedItemModSlotName = comp["gunAttachable__gunSlotName"] ?? ""
        let modsDesc = mkItemDescFromComp(eid, comp)
        heroModsByWeaponSlotRawModify(function(v) {
          if (v[idx] == null)
            v[idx] = {}
          v[idx][eid] <- {
            modCurAmmo
            modTotalAmmo
            isWeapon = comp?.subsidiaryGun != null
            isModActive
            attachedItemModSlotName
            isVariableScope = comp["gunmod__variableScope"]
          }.__update(modsDesc)
          return v
        })
        return
      }

      if (comp.gun__owner != controlledHeroEid.get()
        && comp.item__ownerEid != controlledHeroEid.get())
        return

      let staticDesc = mkItemDescFromComp(eid, comp)
      let desc = {
        isReloading = comp["gun_anim__reloadProgress"] > 0.0
        additionalAmmo = comp?["gun__additionalAmmo"] ?? 0
        eid
        subsidiaryGunEid = comp["subsidiaryGunEid"]
        firingMode = comp["gun__firingModeName"]
        firingModesList = comp["gun__firingModeNames"]?.getAll() ?? []
        curAmmo = comp["gun__ammo"]
        totalAmmo = comp["gun__totalAmmo"]
        curAmmoHolderIndex = comp["gun__curAmmoHolderIndex"]
        ammoByHolders = comp["gun__ammoByHolders"]?.getAll() ?? []
        iconByHolders = comp["gun__iconByHolders"]?.getAll() ?? []
        guidanceState = comp["gun__guidanceState"]
        isModActive = comp["weapon_mod__active"]
        launcherEid = comp["tactical_phone__droneLauncher"]
      }
      weaponSlotsStatic[idx] = staticDesc
      weaponSlotsRaw[idx].setValue(desc)
      weaponSlotsGenSetValue(weaponSlotsGen.get()+1)
    }
    onDestroy = function(eid, comp) {
      if (comp["multiple_guns_slot_gun_hidden"] != null)
        return

      let idx = comp["slot_attach__weaponSlotIdx"]
      if (idx < 0 || idx > WeaponSlots.EWS_NUM)
        return

      let weaponMod = comp["weaponMod"] != null
      if (weaponMod) {
        heroModsByWeaponSlotRawModify(function(v) {
            if (eid not in v?[idx])
              return v
            v[idx].$rawdelete(eid)
            return v
          })
        return
      }

      if (comp.gun__owner != controlledHeroEid.get()
        && comp.item__ownerEid != controlledHeroEid.get())
        return

      weaponSlotsStatic[idx] = null
      weaponSlotsRaw[idx].setValue(null)
      weaponSlotsGenSetValue(weaponSlotsGen.get() + 1)
    }
  },
  {
    comps_rq = anyItemComps.comps_rq,
    comps_no = ["binocular", "flask", "grenade_thrower"]
    comps_ro = [
      ["weaponMod", ecs.TYPE_TAG, null],
      ["slot_attach__weaponSlotIdx", ecs.TYPE_INT, null],
      ["multiple_guns_slot_gun_hidden", ecs.TYPE_TAG, null],
      ["gunAttachable__gunSlotName", ecs.TYPE_STRING, ""],
      ["gunmod__variableScope", ecs.TYPE_BOOL, false]
    ].extend(anyItemComps.comps_ro)
    comps_track = [
      ["slot_attach__weaponSlotIdx", ecs.TYPE_INT],
      ["gun_anim__reloadProgress", ecs.TYPE_FLOAT, 0.0],
      ["gun__ammo", ecs.TYPE_INT, 0],
      ["gun__additionalAmmo", ecs.TYPE_INT, null],
      ["gun__firingModeName", ecs.TYPE_STRING, ""],
      ["gun__firingModeNames", ecs.TYPE_ARRAY, []],
      ["gun__guidanceState", ecs.TYPE_INT, null],
      ["subsidiaryGunEid", ecs.TYPE_EID, ecs.INVALID_ENTITY_ID],
      ["gun__totalAmmo", ecs.TYPE_INT, 0],
      ["gun__curAmmoHolderIndex", ecs.TYPE_INT, 0],
      ["gun__ammoByHolders", ecs.TYPE_INT_LIST, null],
      ["gun__iconByHolders", ecs.TYPE_STRING_LIST, null],
      ["subsidiaryGun", ecs.TYPE_TAG, null],
      ["weapon_mod__active", ecs.TYPE_BOOL, false],
      ["tactical_phone__droneLauncher", ecs.TYPE_EID, 0]
    ]
  }
)

let heroModsByWeaponSlot = Computed(function(){
  let res = array(WeaponSlots.EWS_NUM)
  foreach (slotNum, modsByEids in heroModsByWeaponSlotRaw.get()) {
    let mods = {}
    let iconAttachments = []
    local modWeapon
    foreach (mod in (modsByEids ?? [])){
      let {animchar=null, isWeapon=false, attachedItemModSlotName=null} = mod
      if (attachedItemModSlotName==null)
        continue
      mods[attachedItemModSlotName] <- mod
      if (isWeapon) {
        iconAttachments.append({
          animchar
          slot = attachedItemModSlotName
          active = true
        })
        modWeapon = mods[attachedItemModSlotName]
      }
    }
    if (mods.len()>0)
      res[slotNum] = {mods, iconAttachments, modWeapon}
  }
  return res
})

let humanCurGunInfo = Computed(function() {
  weaponSlotsGen.get()  
  return weaponSlots?[humanCurGunSlotIdx.get()].get()
})

let humanCurGunModeInfo = Computed(function() {
  weaponSlotsGen.get()  
  return heroModsByWeaponSlot.get()?[humanCurGunSlotIdx.get()]
})

let humanCurGunStaticInfo = Computed(function() {
  weaponSlotsGen.get()  
  return weaponSlotsStatic?[humanCurGunSlotIdx.get()]
})

return {
  humanCurGunStaticInfo
  humanCurGunInfo
  humanCurGunModeInfo
  getLauncherNextUseAtTime
}
