local wo = require('ds18b20')
local fan_pin = 1
local sensor_pin = 4
local heater_pin = 2

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
local sensor_b_rom = "28:FF:BE:38:A6:16:05:AF"
local sensor_a_rom = "28:FF:18:60:A6:16:03:19"
wo.setting({sensor_b_rom, sensor_a_rom}, 10)
local timer = tmr.create()
local prev_int = 15000
tmr.register(timer, prev_int, tmr.ALARM_AUTO, function() process() end)
st.sensor_a = nil
st.sensor_b = nil
st.details = "Initialization"
local mem_t = 0.0
local count = 6
local tm = nil
local rm
local ta = nil
local tb = nil
local err_a = -1
local err_b = -1
local wrapper = {}

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

function saveState()
  st_string = sjson.encode(st)
  if (file.open("state.json", "w")) then
    file.write(st_string)
    file.close()
  end
end

function getSettings()
  if (file.open("settings.json", "r")) then
    set = sjson.decode(file.read())
    file.close()
  end
end

function process()
  print("Processing")
  st.details = ""
  
  getSettings()
  if (prev_int ~= set.interval) then
    tmr.interval(timer, set.interval)
    prev_int = set.interval
  end
  
  tm = rtctime.epoch2cal(rtctime.get())
  st.time = string.format("%04d/%02d/%02d %02d:%02d:%02d", tm["year"], tm["mon"], tm["day"], tm["hour"], tm["min"], tm["sec"])
  
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
  if (err_a >= 5) then
    relay(heater_pin, 0)
    st.state = "err"
    st.details = "Sensor A isn't responding"
  end
  if (err_b >= 5) then
    relay(heater_pin, 0)
    st.state = "err"
    st.details = "Sensor B isn't responding"
  end
  
  if (st.state == "err") then
    if (st.sensor_b ~= nil and st.sensor_b <= set.cold) then
      relay(fan_pin, 0)
    end
  end
  
  if (st.state == "cooling") then
    if (st.sensor_b ~= nil and st.sensor_b <= set.cold) then
      relay(fan_pin, 0)
      st.state = "off"
    end
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
      relay(heater_pin, 0)
      st.state = "changed"
      mem_t = st.sensor_a
      count = set.count
      rotate(-1)
    end
  end
  
  saveState()
  print("Processed")
end

function rotate(direction)
  print("Rotating ", tostring(direction))
  st.state = "work"
end

function switchOn()
  print("Turning on")
  if (st.state ~= "err") then
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
  
  getSettings()
  saveState()

  cron.schedule("0 9 * * 1,2,3,4,5", switchOff)
  cron.schedule("30 18 * * 1,2,3,4,5", switchOn)
  
  tmr.start(timer)
end

wrapper.switchOn = switchOn
wrapper.switchOff = switchOff
wrapper.init = init

return wrapper