-- autorun.lua
print()
print("---==[ Lua RTOS Nixie Clock ]==---")
print()
print("Written by Steven R. Stuart, W8AN, in Feb 2020")
print("Updated July 2025")

print()
print("Ctrl+D (or Ctrl+C) to abort autorun.lua")
print()
print("To modify wifi connection settings:")
print(" edit config.lua")
print(" (Use Ctrl+S to save, ctrl+Q to quit editor)")
print()

--
print("Wifi connecting")
tmout=0
repeat
  tmr.delay(1)
  io.write(".")
  tmout=tmout+1
until net.connected() or tmout>60
tmout=nil
print()
print("Wifi stations in range:")
net.wf.scan()
dofile("nixieclock.lua")
