require ecs

require %appGame.wt_events

[es(tag=server)]
def set_death_skip_cooldown_server_es(evt : EventResetDeathCooldown; var unit__deathControlLostAtTime : float&)
  let timeEps = 0.01
  if unit__deathControlLostAtTime > timeEps
    unit__deathControlLostAtTime = timeEps 
