local random = require("dagor.random")
local cdate = (require_optional("system")?.date ?? @(date=null,format=null) {sec=0, min=0, hour=0, day=0, month=0, year=0, wday=0, yday=0})()
local _default_seed = random.get_rnd_seed() + cdate.sec + cdate.min*60 + cdate.yday*86400
local position = 0
local function new_rnd_seed(){//setting new rnd
  position++
  return random.uint_noise1D(position, _default_seed)
}

local DEFAULT_MAX_INT_RAND = 32767
const maxrndfloat = 16777215.0 // float can only hold 23-bits integers without data loss
const maxrndfloatmask = 16777215 // (1<24)-1
local maxnoiseint = 0xffffffff // 32 bits
local function randint_uniform(lo, hi, rand) { // returns random int in range [lo,hi], closed interval
  local n = hi - lo + 1
  ::assert(n != 0)
  local maxx = maxnoiseint - (maxnoiseint % n)
  local x
  do {
    x = rand()
  } while (x >= maxx)
  return lo + (x % n)
}

local Rand = class{
  _seed = null
  _count = null

  constructor(seed=null) {
    _seed = seed ?? new_rnd_seed()
    _count = 0
  }

  function setseed(seed=null) {
    _seed = seed ?? new_rnd_seed()
    _count = 0
  }

  function rfloat(start=0.0, end=1.0){ // return float in range [start,end)
    _count += 1
    local start_ = ::min(end,start)
    local end_ = ::max(end,start)
    local runit = (random.uint_noise1D(_seed, _count) & maxrndfloatmask) / maxrndfloat // [0,1]
    return runit * (end_-start_) + start_
  }

  static function _rfloat(start=0.0, end=1.0, seed=null, count=null){ // return float in range [start,end)
    if (::type(seed)=="table") {
      local params = seed
      start=params?.start ?? start
      end=params?.end ?? end
      seed = params?.seed ?? new_rnd_seed()
      count = params?.count ?? count
    }
    local start_ = ::min(end,start)
    local end_ = ::max(end,start)
    local runit = (random.uint_noise1D(seed, count ?? seed) & maxrndfloatmask) / maxrndfloat // [0,1]
    return runit * (end_-start_) + start_
  }

  static function _rint(start=0, end=DEFAULT_MAX_INT_RAND, seed=null, count=null){ // return int in range [start, end], i.e. inclusive
    if (::type(seed)=="table") {
      local params = seed
      start=params?.start ?? start
      end=params?.end ?? end
      seed = params?.seed ?? new_rnd_seed()
      count = params?.count ?? count
    }
    return randint_uniform(::min(end,start), ::max(end,start), @() random.uint_noise1D(seed, count ?? seed))
  }

  function rint(start=0, end = null) { // return int in range [start, end], i.e. inclusive
    _count += 1
    if (end==null && start==0)
      return random.uint_noise1D(_seed, _count)
    else {
      end = end?.tointeger() ?? DEFAULT_MAX_INT_RAND
      start = start.tointeger()
      return randint_uniform(::min(end,start), ::max(end,start), @() random.uint_noise1D(_seed, _count))
    }
  }

  static grnd = random.grnd
  static gauss_rnd = random.gauss_rnd
  static uint_noise1D = random.uint_noise1D

  static function chooseRandom(arr, seed = null) { //free standing
    if (arr.len()==0)
      return null
    local randfunc = @() random.uint_noise1D((seed == null) ? new_rnd_seed() : seed, 0)
    return arr[randfunc() % arr.len()]
  }

  static function shuffle(arr, seed=null) {
    local res = clone arr
    local size = res.len()
    local j
    local v
    local randfunc = @(count) random.uint_noise1D(seed == null ? new_rnd_seed() : seed, count)
    for (local i = size - 1; i > 0; i--) {
      j = randfunc(i) % (i + 1)
      v = res[j]
      res[j] = res[i]
      res[i] = v
    }
    return res
  }

}

//test is random is reandom enough by Pirson criteria
local pp = @(...) print("".concat(" ".join(vargv), "\n"))
local ppa = @(v) pp.acall([null].extend(v))
local module = @(v) v<0 ? -v : v

local function testRandomEnoughByPirsonCriteria(){
  local function mkDistribution(buckets, runs, func){
    local rand = Rand()
    local res = {}
    for (local i=0;i<runs;i++){
      local v = rand[func](0,(buckets-0.000001))//epsilon
      v = ((v*buckets).tointeger()/buckets).tointeger()
      if (res?[v] != null)
        res[v]=res[v]+1
      else
        res[v]<-1
    }
    return(res)
  }
  local hitable = [
    //index - degree of freedom, first - 0.05 of sufficiency, second - 0.01
    [3.841, 6.635],[5.991,9.21],[7.815,11.345],[9.488,13.277],[11.07,15.086],[12.592,16.812],[14.067,18.475],[15.507,20.09],[16.919,21.666],[18.307,23.209],[19.675,24.725],[21.026,26.217],[22.362,27.688],
    [23.685,29.141],[24.996,30.578],[26.296,32],[27.587,33.409],[28.869,34.805],[30.144,36.191],[31.41,37.566],
  ]
  local function doit(funcname, buckets=hitable.len()-1, samplesTotal=100000){
    samplesTotal = samplesTotal.tofloat()
    local samples = mkDistribution(buckets, samplesTotal, funcname).values()
    local prob = samplesTotal / buckets
    local diffs = samples.map(@(v) module(v-prob)-0.5)
    local krit = diffs.map(@(v) v*v/prob)
    local hiObserved = krit.reduce(@(a,b) a+b)
    local degreeOfFreedom = buckets-1
    pp($"Pirson criteria for {funcname}:")
    ppa(["samples:"].extend(samples))
    ppa(["diffs:"].extend(diffs))
    local hiTheor5 = hitable[degreeOfFreedom][0]
    local hiTheor1 = hitable[degreeOfFreedom][1]
    pp(hiObserved, hiTheor1, "pirson criteria of suff. 0.01: ", hiObserved<hiTheor1)
    pp(hiObserved, hiTheor5, "pirson criteria of suff. 0.05: ", hiObserved<hiTheor5)
    return hiObserved<hiTheor1
  }
  return doit("rint",10) && doit("rfloat",10)
}
local function testShuffle(){
  pp("\nArray of ints shuffled:")
  ppa(Rand.shuffle(::array(20).map(@(v,i) i)))
}

if (this?.__name__ == "__main__") {
  testRandomEnoughByPirsonCriteria()
  testShuffle()
}

return Rand
