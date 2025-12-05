require ecs
require ecs.safe
require DagorSystem
require PhysMat
require %appGame.infantry.client.physmat_fx_common

[es(on_appear, tag=render)]
def foot_step_fx_init_mat_ids(evt : Event;
                              human_footsteps_fx__materials : Object;
                              var human_footsteps_fx__matTemplates : StringList&)
  resize(human_footsteps_fx__matTemplates, physMatCount())
  for_each_physmat_data(human_footsteps_fx__materials, "group__") <| $(pmid : int; data : ChildComponent)
    let fxName = data as string
    if fxName == null
      logerr("all elements in human_footsteps_fx__materials should be 't'")
      return
    human_footsteps_fx__matTemplates[pmid] := *fxName