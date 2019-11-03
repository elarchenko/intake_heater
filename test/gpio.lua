local wo = {}
wo.gpio = {0, 0, 0, 0, 0}

wo.HIGH = 1
wo.LOW = 0

function mode(arg1, arg2)
  return 0
end

function write(arg1, arg2)
  wo.gpio[arg1] = arg2
  return 0
end

function get(arg1)
  return wo.gpio[arg1]
end

wo.mode = mode
wo.write = write
wo.get = get

return wo