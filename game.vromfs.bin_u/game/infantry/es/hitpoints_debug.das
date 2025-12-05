options no_aot
require ecs
require ecs.common
require DagorConsole
require %appGame.infantry.es.hitpoints_common
require %appGame.infantry.es.net_console_macro
require %appGame.infantry.es.armor_common


def private set_hp_for_eid(eid : EntityId; value : float)
  query(eid) <| $ [es] (var hitpoints__hp : float&)
    hitpoints__hp = value

def private clear_bleeding_for_eid(eid : EntityId)
  query(eid) <| $ [es] (var hitpoints__dotDamage : FloatList&;
                        var hitpoints__totalDotAmount : float&)
    var amount = 1e10
    decrease_damage_over_time_amount(amount, hitpoints__dotDamage, hitpoints__totalDotAmount)

[net_console_cmd(name="hitpoints.set_hero_hp")]
def set_hero_hp(value : float; @net_hero eid : EntityId)
  set_hp_for_eid(eid, value)

[net_console_cmd(name="hitpoints.set_bleeding")]
def set_bleeding(bleeding_damage : float; @net_hero eid : EntityId)
  query(eid) <| $ [es] (hitpoints__dotBaseSpeed : float;
                        hitpoints__dotSpeedThreshold : float;
                        var hitpoints__dotDamage : FloatList&;
                        var hitpoints__totalDotAmount : float&)
    if bleeding_damage > 0.0
      add_damage_over_time_entry(bleeding_damage, hitpoints__dotBaseSpeed, hitpoints__dotSpeedThreshold, hitpoints__dotDamage, hitpoints__totalDotAmount)
    elif bleeding_damage < 0.0
      var amount = -bleeding_damage
      decrease_damage_over_time_amount(amount, hitpoints__dotDamage, hitpoints__totalDotAmount)

[net_console_cmd(name="hitpoints.clear_bleeding")]
def clear_bleeding(@net_hero eid : EntityId)
  query(eid) <| $ [es] (var hitpoints__dotDamage : FloatList&;
                        var hitpoints__totalDotAmount : float&)
    var amount = 1e10
    decrease_damage_over_time_amount(amount, hitpoints__dotDamage, hitpoints__totalDotAmount)

[net_console_cmd(name="hitpoints.set_hero_maxhp")]
def set_hero_maxhp(value : float; @net_hero eid : EntityId)
  query(eid) <| $ [es] (var set_hero_maxhp : float&)
    set_hero_maxhp = value

[net_console_cmd(name="hitpoints.hero_god_mode")]
def hero_god_mode(@net_hero eid : EntityId)
  set_hp_for_eid(eid, 999999f)
  clear_bleeding_for_eid(eid)

[net_console_cmd(name="hitpoints.squad_god_mode")]
def squad_god_mode(@net_hero hero_eid : EntityId)
  set_hp_for_eid(hero_eid, 999999f)
  clear_bleeding_for_eid(hero_eid)
  query(hero_eid) <| $ [es] (squad_member__squad aka hero_squad_member__squad : EntityId)
    if hero_squad_member__squad != INVALID_ENTITY_ID
      query() <| $ [es] (eid aka member_eid : EntityId; squad_member__squad aka unit_squad_member__squad : EntityId; var hitpoints__hp : float&)
        if hero_squad_member__squad == unit_squad_member__squad
          hitpoints__hp = 999999f
          clear_bleeding_for_eid(member_eid)

[net_console_cmd(name="hitpoints.god_mode_everyone")]
def hero_god_mode_all()
  query() <| $ [es] (eid : EntityId; var hitpoints__hp : float&)
    hitpoints__hp = 999999f
    clear_bleeding_for_eid(eid)

[net_console_cmd(name="armor.resupply_hero")]
def hero_resupply_armor(@net_hero eid : EntityId)
  resupply_armor_for_soldier(eid)
