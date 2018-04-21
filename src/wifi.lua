--WiFi Settup
print("Connecting to the net...")
wifi.setmode(wifi.STATION)
local cfg={}
cfg.ssid="Cave"
cfg.save=true
wifi.sta.config(cfg)
wifi.sta.connect()
connected = 0

tmr.alarm(1,1000,1,function()
  if wifi.sta.getip()==nil then
    print("IP unavailable, waiting")
  else
    tmr.stop(1)
    print("Config done, IP is "..wifi.sta.getip())
    connected = 1
  end
end)
collectgarbage()
