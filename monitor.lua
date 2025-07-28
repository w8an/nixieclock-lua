repeat
  os.uptime()
  time_now()
  print("net:"..tostring(net.connected()))
  print("mem:"..collectgarbage("count").."\n")
  tmr.sleep(1)
until nil
