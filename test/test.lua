local wo = require('ds18b20')
local gpio = require('gpio')
local tmr = require('tmr')
local file = require('file')
local rtctime = require('rtctime')
local fan_pin = 1
local sensor_pin = 4
local heater_pin = 2
local r_1 = 5
local r_2 = 6
local r_3 = 7
local r_4 = 8

local st = {}
local set = {}
local st_string = nil
gpio.mode(heater_pin, gpio.OPENDRAIN)
gpio.write(heater_pin, gpio.HIGH)
gpio.mode(fan_pin, gpio.OPENDRAIN)
gpio.write(fan_pin, gpio.HIGH)
st.fan = 0
st.heater = 0
st.state = "off"
wo.setup(sensor_pin)
local sensor_b_rom = "28:1F:C0:79:97:04:03:F3"
local sensor_a_rom = "28:FF:18:60:A6:16:03:19"
wo.setting({sensor_b_rom, sensor_a_rom}, 10)
local timer = tmr.create()
local prev_int = 15000
tmr.register(timer, prev_int, tmr.ALARM_AUTO, function() process() end)
st.sensor_a = nil
st.sensor_b = nil
st.details = ""
local mem_t = 0.0
local count = 6
local tm = nil
local rm
local ta = nil
local tb = nil
local err_a = -1
local err_b = -1
local wrapper = {}
local rotation = {}
local rotation_pointer

function sntp_sync_time()
  sntp.sync(nil, function(sec, usec, server, info) rtctime.set(sec + 18000) end, sntp_sync_time, 1)
end

function relay(id, s)
  if (id == fan_pin) then
    st.fan = s
  end
  if (id == heater_pin) then
    st.heater = s
  end
  if (s == 1) then
    gpio.write(id, gpio.LOW)
  else
    gpio.write(id, gpio.HIGH)
  end
end  

wrapper.saveState = function()
  st_string = sjson.encode(st)
  if (file.open("state.json", "w+")) then
    file.write(st_string)
    file.close()
  end
end

wrapper.getSettings = function()
  if (file.open("settings.json", "r")) then
    set = sjson.decode(file.read())
    file.close()
  end
end

wrapper.getTime = function()
  tm = rtctime.epoch2cal(rtctime.get())
  return string.format("%04d/%02d/%02d %02d:%02d:%02d", tm["year"], tm["mon"], tm["day"], tm["hour"], tm["min"], tm["sec"])
end  

function process()
  print("Processing")
  wrapper.getSettings()
  if (prev_int ~= set.interval) then
    tmr.interval(timer, set.interval)
    prev_int = set.interval
  end
  
  st.time = wrapper.getTime()
  
  wo.read(
    function(ind,rom,res,temp,tdec,par)
      rm = string.format("%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X",string.match(rom,"(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(%d+)"))
      if (temp > -50) then
        if (rm == sensor_a_rom) then
          ta = temp
        end
        if (rm == sensor_b_rom) then
          tb = temp
        end
      end
    end, {})
  
  if (ta ~= nil) then
    st.sensor_a = ta
    err_a = -1
    ta = nil
  else
    err_a = err_a + 1
  end
  if (tb ~= nil) then
    st.sensor_b = tb
    err_b = -1
    tb = nil
  else
    err_b = err_b + 1
  end
  
  if (st.sensor_b ~= nil and st.sensor_b >= set.limit) then
    relay(heater_pin, 0)
    st.state = "err"
    st.details = "Overheated!"
  end
  if (st.sensor_a ~= nil and st.sensor_a >= set.limit) then
    relay(heater_pin, 0)
    st.state = "err"
    st.details = "Overheated!"
  end
  if (err_a >= count) then
    relay(heater_pin, 0)
    st.state = "err"
    st.details = "Sensor A isn't responding."
  end
  if (err_b >= count) then
    relay(heater_pin, 0)
    st.state = "err"
    st.details = "Sensor B isn't responding."
  end
  
  if (st.state == "err") then
    if (st.sensor_b ~= nil and st.sensor_b <= set.cold) then
      relay(fan_pin, 0)
    end
    relay(heater_pin, 0)
  end
  
  if (st.state == "cooling") then
    if (st.sensor_b ~= nil and st.sensor_b <= set.cold) then
      relay(fan_pin, 0)
      st.state = "off"
    end
    relay(heater_pin, 0)
  end
  
  if (st.state == "changed") then
    count = count - 1
    if (count == 0) then
      if (math.abs(mem_t - st.sensor_a) < set.delta) then
        st.state = "work"
      else
        count = set.count
        mem_t = st.sensor_a
      end
    end
    mem_t = st.sensor_a
  end
  
  if (st.state == "work") then
    if (st.sensor_a ~= nil and st.sensor_a <= set.lowLevel) then
      if (st.heater == 0) then
        relay(heater_pin, 1)
      else
        rotate(1)
      end
      mem_t = st.sensor_a
      count = set.count
      st.state = "changed"
    end
    if (st.sensor_a ~= nil and st.sensor_a >= set.highLevel) then
      if (st.heater == 1) then
        relay(heater_pin, 0)
        st.state = "changed"
        mem_t = st.sensor_a
        count = set.count
        rotate(-1)
      end
    end
  end
  
  wrapper.saveState()
  print("Processed")
end

function rotate(direction)
  print("Rotating ", tostring(direction))
  gpio.mode(r_1, gpio.OUTPUT)
  gpio.mode(r_2, gpio.OUTPUT)
  gpio.mode(r_3, gpio.OUTPUT)
  gpio.mode(r_4, gpio.OUTPUT)
  rotation_pointer = 1
  for i = 1, set.steps, 1
  do
    rotation_pointer = rotation_pointer - direction
    if (rotation_pointer < 1) then
      rotation_pointer = 8
    end
    if (rotation_pointer > 8) then
      rotation_pointer = 1
    end
    gpio.write(r_1, rotation[rotation_pointer][1])
    gpio.write(r_2, rotation[rotation_pointer][2])
    gpio.write(r_3, rotation[rotation_pointer][3])
    gpio.write(r_4, rotation[rotation_pointer][4])
    tmr.delay(set.delay)
  end
  gpio.mode(r_1, gpio.INPUT)
  gpio.mode(r_2, gpio.INPUT)
  gpio.mode(r_3, gpio.INPUT)
  gpio.mode(r_4, gpio.INPUT)
end

function switchOn()
  print("Turning on")
  if (st.state == "off") then
    err_a = -1
    err_b = -1
    relay(fan_pin, 1)
    st.state = "work"
    st.details = "Starting"
  end
end

function switchOff()
  print("Turning off")
  if (st.state ~= "err") then
    st.state = "cooling"
    relay(heater_pin, 0)
  end
end

function init()
  print("Time syncing...")
  sntp_sync_time()
  
  rotation[1] = { gpio.HIGH, gpio.LOW, gpio.LOW, gpio.LOW }
  rotation[2] = { gpio.HIGH, gpio.HIGH, gpio.LOW, gpio.LOW }
  rotation[3] = { gpio.LOW, gpio.HIGH, gpio.LOW, gpio.LOW }
  rotation[4] = { gpio.LOW, gpio.HIGH, gpio.HIGH, gpio.LOW }
  rotation[5] = { gpio.LOW, gpio.LOW, gpio.HIGH, gpio.LOW }
  rotation[6] = { gpio.LOW, gpio.LOW, gpio.HIGH, gpio.HIGH }
  rotation[7] = { gpio.LOW, gpio.LOW, gpio.LOW, gpio.HIGH }
  rotation[8] = { gpio.HIGH, gpio.LOW, gpio.LOW, gpio.HIGH }
  
  wrapper.getSettings()
  wrapper.saveState()

  cron.schedule("0 9 * * 1,2,3,4,5", switchOff)
  cron.schedule("30 18 * * 1,2,3,4,5", switchOn)
  
  tmr.start(timer)
end

wrapper.switchOn = switchOn
wrapper.switchOff = switchOff
wrapper.init = init
wrapper.rotate = rotate

luaunit = require('luaunit')

local actual_a
local actual_b
local rotation

function read_a(bind, args)
  bind(0,"40:255:24:96:166:22:03:25",9,actual_a,98,0)
end

function read_ab(bind, args)
  bind(1,"40:31:192:121:151:04:03:243",9,actual_b,98,0)
  bind(0,"40:255:24:96:166:22:03:25",9,actual_a,98,0)
end

function fakeTime()
  return "2019"
end

function save()
  return 0
end

function get()
  set.interval = 15000
  set.limit = 50
  set.lowLevel = -5
  set.highLevel = 10
  set.count = 6
  set.delta = 0.2
  set.cold = 40
  set.steps = 100
  set.delay = 1000
end

function prepare()
  st = {}
  set = {}
  st_string = nil
  st.fan = 0
  st.heater = 0
  st.state = "off"
  st.sensor_a = nil
  st.sensor_b = nil
  st.details = ""
  mem_t = 0.0
  count = 6
  tm = nil
  rm = nil
  ta = nil
  tb = nil
  err_a = -1
  err_b = -1
end

function rotate(rt)
  rotation = rt
end

function test1()
  wo.read = read_a
  wrapper.getTime = fakeTime
  wrapper.saveState = save
  wrapper.getSettings = get
  actual_a = 20.98
  prepare()
  process()
  luaunit.assertEquals(st.sensor_a, 20.98)
end

function test2()
  wo.read = read_a
  wrapper.getTime = fakeTime
  wrapper.saveState = save
  wrapper.getSettings = get
  actual_a = 21
  prepare()
  for i=1,count + 1,1 do
    process()
  end
  luaunit.assertEquals(st.state, "err")
end

function test3()
  wo.read = read_ab
  wrapper.getTime = fakeTime
  wrapper.saveState = save
  wrapper.getSettings = get
  actual_a = 21
  actual_b = 22
  prepare()
  wrapper.switchOn()
  process()
  luaunit.assertEquals(st.sensor_a, 21)
  luaunit.assertEquals(st.sensor_b, 22)
  wo.read = read_a
  for i=1,count,1 do
    process()
  end
  luaunit.assertEquals(st.state, "work")
  wo.read = read_ab
  process()
  wo.read = read_a
  for i=1,count + 1,1 do
    process()
  end
  luaunit.assertEquals(st.state, "err")
end

function test4()
  wo.read = read_ab
  wrapper.getTime = fakeTime
  wrapper.saveState = save
  wrapper.getSettings = get
  actual_a = 1
  actual_b = 22
  prepare()
  wrapper.switchOn()
  process()
  actual_a = 0
  process()
  actual_a = -2
  process()
  actual_a = -4
  process()
  actual_a = -6
  process()
  luaunit.assertEquals(st.state, "changed")
  actual_a = 10
  process()
  actual_a = 30
  process()
  actual_a = 50
  process()
  actual_a = 70
  process()
  luaunit.assertEquals(st.state, "err")
end

function test5()
  wo.read = read_ab
  wrapper.getTime = fakeTime
  wrapper.saveState = save
  wrapper.getSettings = get
  wrapper.rotate = rotate
  actual_a = 0
  actual_b = 0
  prepare()
  wrapper.switchOn()
  process()
  actual_a = -2
  process()
  luaunit.assertEquals(st.state, "work")
  actual_a = -6
  process()
  luaunit.assertEquals(st.state, "changed")
  actual_a = -6.1
  rotation = 0
  for i=1,count,1 do
    process()
  end
  luaunit.assertEquals(st.state, "changed")
  luaunit.assertEquals(rotation, 1)
end

function test6()
  wo.read = read_ab
  wrapper.getTime = fakeTime
  wrapper.saveState = save
  wrapper.getSettings = get
  wrapper.rotate = rotate
  actual_a = -8
  actual_b = -8
  rotation = 0
  prepare()
  wrapper.switchOn()
  process()
  luaunit.assertEquals(st.state, "changed")
  actual_a = -6
  for i=1,count,1 do
    process()
  end
  luaunit.assertEquals(st.state, "changed")
  luaunit.assertEquals(mem_t, -6)
  luaunit.assertEquals(count, set.count)
  for i=1,count,1 do
    process()
  end
  luaunit.assertEquals(st.state, "changed")
  luaunit.assertEquals(rotation, 1)
  actual_a = 0
  for i=1,count,1 do
    process()
  end
  luaunit.assertEquals(st.state, "work")
  luaunit.assertEquals(st.heater, 1)
  actual_a = 11
  process()
  luaunit.assertEquals(st.state, "changed")
  luaunit.assertEquals(st.heater, 0)
  luaunit.assertEquals(rotation, -1)
  actual_a = 3
  for i=1,count,1 do
    process()
  end
  luaunit.assertEquals(st.state, "work")
  luaunit.assertEquals(st.heater, 0)
end



os.exit(luaunit.LuaUnit.run())
