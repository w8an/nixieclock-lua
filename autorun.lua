print()
print("---==[ Lua RTOS Nixie Clock ]==---")
print()
print("Written by Steven R. Stuart, W8AN, in Feb 2020")

print()
print("To modify wifi connection settings:")
print("edit wifi.lua")
print("(Use Ctrl+S to save, ctrl+Q to quit editor)")
print()

--
dofile("wifi.lua") -- get wifi credentials
print("Wifi stations in range...")
net.wf.scan()

print("Connecting to: "..ssid)
net.wf.setup(net.wf.mode.STA, ssid, pswd)
net.wf.start()
tout=0
repeat
  tmr.delay(1)
  io.write(".")
  tout=tout+1
until net.connected() or tout>60
tout=nil
print()
io.write("Wifi connection to "..ssid.." ")
if net.connected() then
  print("successful")
  net.stat()
  net.service.sntp.start()
else
  print("FAILED!")
end

dofile("nixieclock.lua")
--
