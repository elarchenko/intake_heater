response="HTTP/1.0 200 OK\r\nServer: NodeMCU\r\nContent-Type: application/json\r\n\r\n"
local rsp = nil
if POST['data'] ~= nil then
  local data = sjson.decode(POST['data'])
  if file.open("settings.json", "w") then
    file.write(POST['data'])
    file.close()
  end
  rsp = '{"result": "OK"}'
end
local cmd = POST['command']
local exec = require("executor")
if cmd ~= nil then
  if cmd == "switchOn" then
    exec.switchOn()
    rsp = '{"result": "OK"}'
  end
  if cmd == "switchOff" then
    exec.switchOff()
    rsp = '{"result": "OK"}'
  end
end
if rsp == nil then
  rsp = '{"result": "Error"}'
end
response = response..rsp
return response