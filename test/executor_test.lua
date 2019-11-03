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
  luaunit.assertEquals(gpio.get(fan_pin), 1)
  luaunit.assertEquals(gpio.get(heater_pin), 1)
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
  luaunit.assertEquals(gpio.get(fan_pin), 1)
  luaunit.assertEquals(gpio.get(heater_pin), 1)
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
  luaunit.assertEquals(gpio.get(fan_pin), 0)
  luaunit.assertEquals(gpio.get(heater_pin), 1)
  wo.read = read_ab
  process()
  wo.read = read_a
  for i=1,count + 1,1 do
    process()
  end
  luaunit.assertEquals(st.state, "err")
  luaunit.assertEquals(gpio.get(fan_pin), 1)
  luaunit.assertEquals(gpio.get(heater_pin), 1)
end

function test4()
  wo.read = read_ab
  wrapper.getTime = fakeTime
  wrapper.saveState = save
  wrapper.getSettings = get
  actual_a = 1
  actual_b = 1
  prepare()
  wrapper.switchOn()
  process()
  actual_a = 0
  actual_b = 0
  process()
  actual_a = -2
  actual_b = -2
  process()
  actual_a = -4
  actual_b = -4
  process()
  luaunit.assertEquals(gpio.get(fan_pin), 0)
  luaunit.assertEquals(gpio.get(heater_pin), 1)
  actual_a = -6
  actual_b = -6
  process()
  luaunit.assertEquals(st.state, "changed")
  luaunit.assertEquals(gpio.get(fan_pin), 0)
  luaunit.assertEquals(gpio.get(heater_pin), 0)
  actual_a = 11
  actual_b = 11
  process()
  luaunit.assertEquals(gpio.get(fan_pin), 0)
  luaunit.assertEquals(gpio.get(heater_pin), 1)
  actual_a = 31
  actual_b = 31
  process()
  luaunit.assertEquals(gpio.get(fan_pin), 0)
  actual_a = 51
  actual_b = 51
  process()
  luaunit.assertEquals(gpio.get(fan_pin), 0)
  luaunit.assertEquals(gpio.get(heater_pin), 1)
  actual_a = 31
  actual_b = 31
  process()
  luaunit.assertEquals(st.state, "err")
  luaunit.assertEquals(gpio.get(fan_pin), 1)
  luaunit.assertEquals(gpio.get(heater_pin), 1)
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