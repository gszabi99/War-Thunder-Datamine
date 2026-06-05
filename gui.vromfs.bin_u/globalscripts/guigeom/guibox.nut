let { min, max } = require("math")
let { Point2 } = require("dagor.math")
let { format } = require("string")














let GuiBox = class {
  c1 = null  
  c2 = null  
  priority = 0
  isToStringForDebug = true

  constructor(vx1 = 0, vy1 = 0, vx2 = 0, vy2 = 0, vpriority = 0) {
    this.c1 = [vx1, vy1]
    this.c2 = [vx2, vy2]
    this.priority = vpriority
  }

  function _tostring() {
    return format("GuiBox((%d,%d), (%d,%d)%s)", this.c1[0], this.c1[1], this.c2[0], this.c2[1],
      this.priority ? ($", priority = {this.priority}") : "")
  }

  function isIntersect(box) {
    return  !(box.c1[0] >= this.c2[0] || this.c1[0] >= box.c2[0]
           || box.c1[1] >= this.c2[1] || this.c1[1] >= box.c2[1])
  }

  function isInside(box) {
    return   (box.c1[0] <= this.c1[0] && this.c2[0] <= box.c2[0]
           && box.c1[1] <= this.c1[1] && this.c2[1] <= box.c2[1])
  }

  function getIntersectCorner(box) {
    if (!this.isIntersect(box))
      return null

    return Point2((box.c2[0] > this.c1[0]) ? this.c1[0] : this.c2[0],
                    (box.c2[1] > this.c1[1]) ? this.c1[1] : this.c2[1])
  }

  function addBox(box) {
    for (local i = 0; i < 2; i++) {
      if (box.c1[i] < this.c1[i])
        this.c1[i] = box.c1[i]
      if (box.c2[i] > this.c2[i])
        this.c2[i] = box.c2[i]
    }
  }

  function cutBox(box) { 
    if (!this.isIntersect(box))
      return null

    let cls = this.getclass()
    let cutList = []
    if (box.c1[0] < this.c1[0])
      cutList.append(cls(box.c1[0], box.c1[1], this.c1[0], box.c2[1]))
    if (box.c2[0] > this.c2[0])
      cutList.append(cls(this.c2[0], box.c1[1], box.c2[0], box.c2[1]))

    let offset1 = max(this.c1[0], box.c1[0])
    let offset2 = min(this.c2[0], box.c2[0])
    if (box.c1[1] < this.c1[1])
      cutList.append(cls(offset1, box.c1[1], offset2, this.c1[1]))
    if (box.c2[1] > this.c2[1])
      cutList.append(cls(offset1, this.c2[1], offset2, box.c2[1]))

    return cutList
  }

  function incPos(inc) {
    for (local i = 0; i < 2; i++) {
      this.c1[i] += inc[i]
      this.c2[i] += inc[i]
    }
    return this
  }

  function incSize(kAdd, kMul = 0) {
    for (local i = 0; i < 2; i++) {
      local inc = kAdd
      if (kMul)
        inc += ((this.c2[i] - this.c1[i]) * kMul).tointeger()
      if (inc) {
        this.c1[i] -= inc
        this.c2[i] += inc
      }
    }
    return this
  }

  function cloneBox(incSzX = 0, incSzY = null) {
    incSzY = incSzY ?? incSzX
    let cls = this.getclass()
    return cls(this.c1[0] - incSzX, this.c1[1] - incSzY, this.c2[0] + incSzX, this.c2[1] + incSzY)
  }
}

function cutBoxesAroundTargets(rootBox, targetBoxes, sizeIncAdd = 0, sizeIncMul = 0) {
  let darkBoxes = [rootBox.cloneBox()]
  foreach (target in targetBoxes) {
    if (sizeIncAdd != 0 || sizeIncMul != 0)
      target.incSize(sizeIncAdd, sizeIncMul)
    for (local i = darkBoxes.len() - 1; i >= 0; i--) {
      let newBoxes = target.cutBox(darkBoxes[i])
      if (newBoxes == null)
        continue
      darkBoxes.remove(i)
      darkBoxes.extend(newBoxes)
    }
  }
  return darkBoxes
}

return {
  GuiBox
  cutBoxesAroundTargets
}