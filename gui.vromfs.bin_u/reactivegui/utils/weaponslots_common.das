module weaponslots_common public

require app
require FlightModelWrap
require hud
require math
require strings
require Unit
require Weapon
require WTCamera
require DagorSystem

struct WeaponSlot
  idx : int = -1
  slot : int = -1
  name : string = ""
  locName : string = ""
  maxAmmo : int = -1
  curAmmo : int = -1
  jettisoned : bool = false
  trigger : int = -1
  selected : bool = false
  nextToShoot : bool = false


class WeaponSlots
  private hero : Unit? = null
  private app : AcesApp? = null
  private fmw : FlightModelWrap? = null
  private wc : WeaponController? = null

  private selectedWeapon : Weapon const? = null
  private sightMode : int = int(CockpitSightMode HUD_SIGHT_MODE_MAX)
  private isWeaponSelectorOn : bool = false
  private chosenShellProps : BaseShellProperties const? = null
  private haveSecondaryWeap : bool = false
  private selectedWeapSlot : int = -1
  @safe_when_uninitialized private secondaryWeapons : WeaponsConstSpan
  @safe_when_uninitialized private allWeapons : WeaponsConstSpan

  def WeaponSlots(var hero : Unit?; var app : AcesApp?; var fmw : FlightModelWrap?; var wc : WeaponController?)
    self.hero = hero
    self.app = app
    self.fmw = fmw
    self.wc = wc
    update()


  def getWeaponSlot(idx : int) : WeaponSlot
    if (!update() || idx >= length())
      return WeaponSlot()

    let weapon = allWeapons[idx]
    if (weapon == null)
      return WeaponSlot()

    var ws = WeaponSlot()
    ws.idx = idx
    ws.slot = hero.slotIdByWeaponId[idx]
    ws.curAmmo = weapon.countBullets
    ws.maxAmmo = weapon.fullBullets
    ws.trigger = weapon.trigger_no
    ws.nextToShoot = ws.slot == selectedWeapSlot
    if (weapon.prop.shellProps != null)
      ws.name = get_weapon_name(*weapon.prop.shellProps)
      ws.locName = "{replace(ws.name, "_default", "")}"
      ws.selected = ws.curAmmo > 0 && isShellEqualsForWeapSelector(weapon.prop.shellProps, chosenShellProps)
    return ws


  def length() : int
    return hero.slotIdByWeaponId.length()


  def getSelectedWeaponSlot() : int
    if (selectedWeapon != null)
      return hero.slotIdByWeaponId[selectedWeapon.weaponIdx]
    else
      return -1


  def private update() : bool
    if (!wc.Weapons.haveSecondaryWeap && fmw.numExternalFuelTanksInitial <= 0)
      return false

    sightMode = fmw.sightMode
    isWeaponSelectorOn = app.flightControlMode.isWeaponSelectorOn
    secondaryWeapons = wc.Weapons.getSecondaryWeapons()
    allWeapons = wc.Weapons.getAllWeapons()
    haveSecondaryWeap = wc.Weapons.haveSecondaryWeap
    updateSelectedWeapon()
    updateChosenShellProps()
    updateSelectedWeapSlot()
    return true


  def private updateSelectedWeapon()
    if (sightMode != int(CockpitSightMode HUD_SIGHT_MODE_GROUND_CANNONS)
      && sightMode != int(CockpitSightMode HUD_SIGHT_MODE_AIR_CANNONS)
      && haveSecondaryWeap)
      if (isWeaponSelectorOn)
        selectedWeapon = secondaryWeapons[0]
      else
        var checkedTrigger = -1
        if (sightMode == int(CockpitSightMode HUD_SIGHT_MODE_AIR_TARGET))
          checkedTrigger = int(WeaponTriggerType AAM_TRIGGER)
        elif (sightMode == int(CockpitSightMode HUD_SIGHT_MODE_GROUND_ROCKET))
          checkedTrigger = int(WeaponTriggerType ROCKETS_TRIGGER)
        elif (*fmw |> getNumGunBullets(int(WeaponTriggerType BOMBS_TRIGGER)) > 0)
          checkedTrigger = int(WeaponTriggerType BOMBS_TRIGGER)
        else
          checkedTrigger = int(WeaponTriggerType GUIDED_BOMBS_TRIGGER)
        for i in 0 .. wc.Weapons[checkedTrigger].length()
          if (wc.Weapons[checkedTrigger][i] != null
            && *wc.Weapons[checkedTrigger][i] |> haveBullets(true))
            selectedWeapon = wc.Weapons[checkedTrigger][i]
            break


  def private updateChosenShellProps
    if (isWeaponSelectorOn && haveSecondaryWeap)
      if (sightMode != int(CockpitSightMode HUD_SIGHT_MODE_GROUND_CANNONS))
        if (!secondaryWeapons.empty())
          chosenShellProps = secondaryWeapons[0].prop.shellProps
    else
      var nextWeaponTrigger = -1
      if (sightMode == int(CockpitSightMode HUD_SIGHT_MODE_AIR_TARGET))
        nextWeaponTrigger = int(WeaponTriggerType AAM_TRIGGER)
      elif (sightMode == int(CockpitSightMode HUD_SIGHT_MODE_GROUND_CANNONS))
        nextWeaponTrigger = -1
      elif (sightMode == int(CockpitSightMode HUD_SIGHT_MODE_GROUND_ROCKET))
        nextWeaponTrigger = int(WeaponTriggerType ROCKETS_TRIGGER)
      elif (sightMode == int(CockpitSightMode HUD_SIGHT_MODE_GROUND_BOMBS_AUTO))
        nextWeaponTrigger = int(WeaponTriggerType BOMBS_TRIGGER)

      if (nextWeaponTrigger >= 0)
        let triggerWeapons = wc.Weapons[nextWeaponTrigger]
        for i in 0 .. triggerWeapons.length()
          let nextWeapon = triggerWeapons[i]
          if (*nextWeapon |> haveBullets(true))
            chosenShellProps = nextWeapon.prop.shellProps


  def private mod(x : int; m : int) {
      return (x % m + m) % m;
  }


  def private updateSelectedWeapSlot()
    // if (hero.slotIdByWeaponId.length() <= 0)
    //   return

    // var numOfBulletsLeft = 0
    // for i in 0 .. secondaryWeapons.length()
    //   numOfBulletsLeft += *secondaryWeapons[i] |> countBullets(true)

    // let curShell = wc.Weapons.haveSecondaryWeap ? numOfBulletsLeft : 0
    // if (wc.Weapons.haveSecondaryWeap && isWeaponSelectorOn && secondaryWeapons.length() > 0)
    //   let idx = abs(mod(secondaryWeapons.length() - curShell, secondaryWeapons.length()))
    //   let wIdx = (secondaryWeapons.length() > idx && secondaryWeapons[idx] != null) ? secondaryWeapons[idx].weaponIdx : -1
    //   selectedWeapSlot = wIdx > -1 && wIdx < hero.slotIdByWeaponId.length() ? hero.slotIdByWeaponId[wIdx] : -1
    // elif (selectedWeapon != null && wc.Weapons[selectedWeapon.trigger_no].length() > 0)
    //   let idx = abs(mod(wc.Weapons[selectedWeapon.trigger_no].length() - curShell, wc.Weapons[selectedWeapon.trigger_no].length()))
    //   let wIdx = (wc.Weapons[selectedWeapon.trigger_no].length() > idx && wc.Weapons[selectedWeapon.trigger_no][idx] != null) ? wc.Weapons[selectedWeapon.trigger_no][idx].weaponIdx : -1
    //   selectedWeapSlot = wIdx > -1 && wIdx < hero.slotIdByWeaponId.length() ? hero.slotIdByWeaponId[wIdx] : -1
    // else
    //   selectedWeapSlot = -1
    if hero.slotIdByWeaponId.length() > 0 && wc.Weapons.haveSecondaryWeap
      var nts : Weapon const? = null
      if isWeaponSelectorOn && secondaryWeapons.length() > 0
        nts = *wc->getNextGun(secondaryWeapons[0].trigger_no, true, true)
      elif selectedWeapon != null && wc.Weapons[selectedWeapon.trigger_no].length() > 0
        nts = *wc->getNextGun(selectedWeapon.trigger_no, true, true)
      selectedWeapSlot = nts != null && nts.weaponIdx < hero.slotIdByWeaponId.length() ? hero.slotIdByWeaponId[nts.weaponIdx] : -1;
def private empty(self : WeaponsConstSpan&) : bool
  return self.length() <= 0


def private empty(self : WeaponsSpan&) : bool
  return self.length() <= 0
