require ecs
require math
require math.base
require DagorMath
require %game.events
require vehicle




[es]
def vehicle_acceleration_es(info : ParallelUpdateFrameDelayed;
                            var vehicle_acceleration__tick : int&;
                            var vehicle_acceleration__velocity : float3&;
                            var vehicle_acceleration__acceleration : float3&;
                            var vehicle_acceleration__viscAcceleration : float3&;
                            var vehicle_acceleration__counterAccel : float3&;
                            vehicle_net_phys : VehiclePhysActor;
                            vehicle_acceleration__accelVisc : float = 0.2f;
                            vehicle_acceleration__counterAccelVisc : float = 0.4f)
  let curTick = vehicle_net_phys.phys.currentState.atTick
  let deltaTime : float = float(curTick - vehicle_acceleration__tick) * vehicle_net_phys.phys.timeStep
  var prevAccel = vehicle_acceleration__viscAcceleration
  prevAccel = approach(prevAccel, vehicle_acceleration__acceleration + vehicle_acceleration__counterAccel, info.dt,
      vehicle_acceleration__accelVisc)
  vehicle_acceleration__viscAcceleration = prevAccel
  vehicle_acceleration__counterAccel = approach(vehicle_acceleration__counterAccel,
                                                  -vehicle_acceleration__acceleration, info.dt,
                                                  vehicle_acceleration__counterAccelVisc)

  if deltaTime <= 0.f
    return

  let prevVelocity = vehicle_acceleration__velocity
  let curVelocity = vehicle_phys_getCurrentStateVelocity(vehicle_net_phys.phys)
  vehicle_acceleration__velocity = curVelocity
  vehicle_acceleration__acceleration = (curVelocity - prevVelocity) * safeinv(deltaTime)
  vehicle_acceleration__tick = curTick
