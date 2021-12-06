require ecs
require WTCamera

[es (tag=gameClient, on_event=(EventEntityCreated, EventComponentsAppear))]
def camera_set_on_create_es(evt: Event; cameraTeamplate: string)
  let cameraId = get_flight_camera_control() |> getCameraId(cameraTeamplate)
  if cameraId >= 0
    get_flight_camera_control() |> setCamera(cameraId, null)

[es (tag=gameClient, on_event=CmdCameraEnter)]
def camera_enter_es(evt: Event; var camera_dot_active: bool&)
  camera_dot_active = true

[es (tag=gameClient, on_event=CmdCameraLeave)]
def camera_leave_es(evt: Event; var camera_dot_active: bool&)
  camera_dot_active = false
