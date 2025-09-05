#strict

import "math" as math
import "dagor.random" as random

let cdate = (require_optional("datetime")?.date ?? @(_date=null,_format=null) {sec=0, min=0, hour=0, day=0, month=0, year=0, wday=0, yday=0})()
let _default_seed = random.get_rnd_seed() + cdate.sec + cdate.min*60 + cdate.yday*86400

local position = 0
function new_rnd_seed() {
  position++
  return random.uint_noise1D(position, _default_seed)
}

const DEFAULT_MAX_INT_RAND = 32767
const maxrndfloat = 16777215.0 
const maxrndfloatmask = 16777215 
const maxnoiseint = 0xffffffff 

function randint_uniform(lo, hi, rand) { 
  let n = hi - lo + 1
  assert(n != 0)
  let maxx = maxnoiseint - (maxnoiseint % n)
  local x
  do {
    x = rand()
  } while (x >= maxx)
  return lo + (x % n)
}

class Rand{
  _seed = null
  _count = null

  constructor(seed=null) {
    this._seed = seed ?? new_rnd_seed()
    this._count = 0
  }

  function setseed(seed=null) {
    this._seed = seed ?? new_rnd_seed()
    this._count = 0
  }

  function rfloat(start=0.0, end=1.0){ 
    this._count += 1
    let start_ = math.min(end,start)
    let end_ = math.max(end,start)
    let runit = (random.uint_noise1D(this._seed, this._count) & maxrndfloatmask) / maxrndfloat 
    return runit * (end_-start_) + start_
  }

  static function _rfloat(start=0.0, end=1.0, seed=null, count=null){ 
    if (type(seed)=="table") {
      let params = seed
      start=params?.start ?? start
      end=params?.end ?? end
      seed = params?.seed ?? new_rnd_seed()
      count = params?.count ?? count
    }
    let start_ = math.min(end,start)
    let end_ = math.max(end,start)
    let runit = (random.uint_noise1D(seed, count ?? seed) & maxrndfloatmask) / maxrndfloat 
    return runit * (end_-start_) + start_
  }

  static function _rint(start=0, end=DEFAULT_MAX_INT_RAND, seed=null, count=null){ 
    if (type(seed)=="table") {
      let params = seed
      start=params?.start ?? start
      end=params?.end ?? end
      seed = params?.seed ?? new_rnd_seed()
      count = params?.count ?? count
    }
    return randint_uniform(math.min(end,start), math.max(end,start), @() random.uint_noise1D(seed, count ?? seed))
  }

  function rint(start=0, end = null) { 
    this._count += 1
    if (end==null && start==0)
      return random.uint_noise1D(this._seed, this._count)
    else {
      end = end?.tointeger() ?? DEFAULT_MAX_INT_RAND
      start = start.tointeger()
      return randint_uniform(math.min(end,start), math.max(end,start), @() random.uint_noise1D(this._seed, this._count))
    }
  }

  static rnd = random.rnd
  static gauss_rnd = random.gauss_rnd
  static uint_noise1D = random.uint_noise1D
  static set_rnd_seed = random.set_rnd_seed 
  static get_rnd_seed = random.set_rnd_seed 

  static function chooseRandom(arr, seed = null) { 
    if (arr.len()==0)
      return null
    let randfunc = @() random.uint_noise1D((seed == null) ? new_rnd_seed() : seed, 0)
    return arr[randfunc() % arr.len()]
  }

  static function shuffle(arr, seed=null) {
    let res = clone arr
    let size = res.len()
    let randfunc = @(count) random.uint_noise1D(seed == null ? new_rnd_seed() : seed, count)
    for (local i = size - 1; i > 0; i--) {
      res.swap(randfunc(i) % (i + 1), i)
    }
    return res
  }

}


let pp = @(...) print("".concat(" ".join(vargv), "\n"))
let ppa = @(v) pp.acall([null].extend(v))
let module = @(v) v<0 ? -v : v

function testRandomEnoughByPirsonCriteria(){
  function mkDistribution(buckets, runs, func){
    let rand = Rand()
    let res = {}
    for (local i=0;i<runs;i++){
      local v = rand[func](0,(buckets-0.000001))
      v = ((v*buckets).tointeger()/buckets).tointeger()
      if (res?[v] != null)
        res[v]=res[v]+1
      else
        res[v]<-1
    }
    return(res)
  }
  let hitable = [
    
    [3.841, 6.635],[5.991,9.21],[7.815,11.345],[9.488,13.277],[11.07,15.086],[12.592,16.812],[14.067,18.475],[15.507,20.09],[16.919,21.666],[18.307,23.209],[19.675,24.725],[21.026,26.217],[22.362,27.688],
    [23.685,29.141],[24.996,30.578],[26.296,32],[27.587,33.409],[28.869,34.805],[30.144,36.191],[31.41,37.566],
  ]
  function doit(funcname, buckets=hitable.len()-1, samplesTotal=100000){
    samplesTotal = samplesTotal.tofloat()
    let samples = mkDistribution(buckets, samplesTotal, funcname).values()
    let prob = samplesTotal / buckets
    let diffs = samples.map(@(v) module(v-prob)-0.5)
    let krit = diffs.map(@(v) v*v/prob)
    let hiObserved = krit.reduce(@(a,b) a+b)
    let degreeOfFreedom = buckets-1
    pp($"Pirson criteria for {funcname}:")
    ppa(["samples:"].extend(samples))
    ppa(["diffs:"].extend(diffs))
    let hiTheor5 = hitable[degreeOfFreedom][0]
    let hiTheor1 = hitable[degreeOfFreedom][1]
    pp(hiObserved, hiTheor1, "pirson criteria of suff. 0.01: ", hiObserved<hiTheor1)
    pp(hiObserved, hiTheor5, "pirson criteria of suff. 0.05: ", hiObserved<hiTheor5)
    return hiObserved<hiTheor1
  }
  return doit("rint",10) && doit("rfloat",10)
}

function testShuffle(){
  pp("\nArray of ints shuffled:")
  ppa(Rand.shuffle(array(20).map(@(_v,i) i)))
}

if (__name__ == "__main__") {
  testRandomEnoughByPirsonCriteria()
  testShuffle()
}

return freeze(Rand)
