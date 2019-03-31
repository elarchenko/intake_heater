function prepare(src, out, test)
  local fp = io.open(src, "r" )
  content = {}
  i = 1
  print("Processing souce file")
  for line in fp:lines() do
    content[#content+1] = line
    i = i + 1
  end
  fp:close()

  i = i - 1
  local fp = io.open(test, "r" )
  print("Processing test file")
  for line in fp:lines() do
    content[i] = line
    i = i + 1
  end
  fp:close()

  local fp = io.open(out, "w+" )
  print("Preparing result file")
  for i = 1, #content do
    fp:write(string.format("%s\n", content[i]))
  end
 
  fp:close()
end
                  
prepare([[..\src\executor.lua]], [[test.lua]], [[executor_test.lua]])