---------------------------------
-- Whitecat Nixie Clock
-- Lua RTOS
-- Author:  Steven R. Stuart
-- Jan 2020
---------------------------------
--EDST = -4 -- eastern daylight savings
EST = -5 -- eastern standard
--CST = -6
--MST = -7
--PST = -8
time_zone = EST
hours12 = false
inp_hour_sel = 34
inp_view_ip = 35
tz_offset = time_zone * 3600
mpx_speed = 2
tube_pos = {}; digit_bcd = {}
time_value = {15, 15, 15, 15, 15, 15}
date_value = {15, 15, 15, 15, 15, 15}
nixie_disp = {15, 15, 15, 15, 15, 15}
am_pm = 'A'
colon_disp = 0
init_pins = function(ara)
i = 1
repeat
pio.pin.setdir(pio.OUTPUT, ara[i])
pio.pin.setlow(ara[i])
i = i + 1
until ara[i] == nil
end
init_input = function(p)
pio.pin.setdir(pio.INPUT, p)
pio.pin.setpull(pio.PULLUP, p)
end
get_input = function(p)
return pio.pin.getval(p) == 0
end
binarize = function(dec)
local b = {}
b[1] = math.floor(dec % 2)
b[2] = math.floor(dec / 2 % 2)
b[3] = math.floor(dec / 4 % 2)
b[4] = math.floor(dec / 8 % 2)
return b
end
nixie_control = function()
local the_tube = 1
return function()
pio.pin.setlow(tube_pos[the_tube])
the_tube = the_tube + 1
if the_tube == 7 then the_tube = 1 end
local bcd = binarize(nixie_disp[the_tube])
pio.pin.setval(bcd[1],digit_bcd[1])
pio.pin.setval(bcd[2],digit_bcd[2])
pio.pin.setval(bcd[3],digit_bcd[3])
pio.pin.setval(bcd[4],digit_bcd[4])
pio.pin.sethigh(tube_pos[the_tube])
end
end
mpx = function()
tube_pos = {pio.GPIO21, pio.GPIO22, pio.GPIO23, pio.GPIO25, pio.GPIO26, pio.GPIO27}
digit_bcd = {pio.GPIO16, pio.GPIO17, pio.GPIO18, pio.GPIO19}
colons = {pio.GPIO32, pio.GPIO33}
init_pins(tube_pos)
init_pins(digit_bcd)
init_pins(colons)
local mpx = nixie_control()
repeat
mpx()
tmr.delayms(mpx_speed)
until nil
end
upd_datetime = function()
local now, dt
repeat
now = os.time() + tz_offset
dt = os.date("%x", now)
date_value[6] = dt:sub(1,1)
date_value[5] = dt:sub(2,2)
date_value[4] = dt:sub(4,4)
date_value[3] = dt:sub(5,5)
date_value[2] = dt:sub(7,7)
date_value[1] = dt:sub(8,8)
if( hours12 ) then
dt = os.date("%I", now)
local lz = dt:sub(1,1)
if lz == '0' then
time_value[6] = 15
else
time_value[6] = dt:sub(1,1)
end
else
dt = os.date("%H", now)
time_value[6] = dt:sub(1,1)
end
time_value[5] = dt:sub(2,2)
dt = os.date("%X", now)
time_value[4] = dt:sub(4,4)
time_value[3] = dt:sub(5,5)
time_value[2] = dt:sub(7,7)
time_value[1] = dt:sub(8,8)
dt = os.date("%p", now)
am_pm = dt:sub(1,1)
tmr.delayms(500)
until nil
end
nixie_display = function( disp_ara )
for i = 1, 6 do
nixie_disp[i] = disp_ara[i]
end
end
scroll = function(disp_ara, ms)
ms = ms or 150
local work_buff = {}
for i = 1, 6 do
work_buff[i+8] = nixie_disp[i]
end
for i = 1, 2 do
work_buff[i+6] = 15
end
for i = 1, 6 do
work_buff[i] = disp_ara[i]
end
local temp_disp = {}
for i = 7, 0, -1 do
for j = 1, 6 do
temp_disp[j] = work_buff[i+j]
end
nixie_display( temp_disp )
tmr.delayms(ms)
end
end
roll = function(disp_ara)
local work_buff = {}
for i = 0, 6 do
work_buff[i] = time_value[i]
end
for i = 0, 9 do
for j = 1, 6 do
work_buff[j] = work_buff[j]+1
if( work_buff[j]==10) then work_buff[j] = 0 end
nixie_display( work_buff )
end
tmr.delayms(50)
end
end
depoison = function()
local blank_disp = {15, 15, 15, 15, 15, 15}
for j = 0, 9 do
for i = 6, 1, -1 do
nixie_disp[i] = j
tmr.delayms(100)
end
end
nixie_display(blank_disp)
tmr.delayms(250)
nixie_display(time_value)
tmr.delayms(1000)
nixie_display(blank_disp)
tmr.delayms(250)
end
show_date = function(speed)
speed = speed or 150
scroll( date_value, speed)
tmr.delayms(3000)
scroll( time_value, speed)
end
show_ip = function()
local blank_disp = {15, 15, 15, 15, 15, 15}
nixie_display(blank_disp)
wf = net.wf.stat(true)
local disp = {}
local ix = 7
local show_disp = function()
nixie_display(disp)
tmr.delayms(1000)
nixie_display(blank_disp)
tmr.delayms(100)
end
for i = 1, string.len(wf.ip) do
local c = wf.ip:sub(i,i)
if( c ~= "." ) then
ix = ix - 1
disp[ix] = c
else
for j = ix-1, 1, -1 do
disp[j] = 15
end
show_disp()
ix = 7
end
end
show_disp()
end
mcp = function()
local hh, mm, ss
init_input(inp_hour_sel)
init_input(inp_view_ip)
local op = {
showdate = function() return (ss == 10) or (ss == 40) end,
eyecandy = function() return ss == 0 end,
depoison = function() return (hh >= 1) and (hh <= 6) and (am_pm=='A') end,
showip  = function() return get_input(inp_view_ip) end
}
repeat
hours12 = get_input( inp_hour_sel )
hh = time_value[6]*10 + time_value[5]
mm = time_value[4]*10 + time_value[3]
ss = time_value[2]*10 + time_value[1]
if( op.showdate() ) then
colon_disp = 0
nixie_display(time_value)
show_date()
colon_disp = 1
elseif( op.eyecandy() ) then
roll(time_value)
roll(time_value)
nixie_display(time_value)
elseif( op.showip() ) then
colon_disp = 0
show_ip()
colon_disp = 1
elseif( op.depoison() ) then
depoison()
else
nixie_display(time_value)
end
tmr.delayms(500)
until nil
end
colon = function()
local state = 0
local c1 = pwm.attach(pio.GPIO32, 100, 0.25)
local c2 = pwm.attach(pio.GPIO33, 100, 0.25)
local state_check = function()
if colon_disp == 1 and state ~= 1 then
c1:start()
c2:start()
state = 1
elseif colon_disp == 0 and state ~= 0 then
c1:stop()
c2:stop()
state = 0
end
end
repeat
state_check()
for i = 0, 0.5, 0.05 do
if state == 1 then
c1:setduty(i)
c2:setduty(i)
end
tmr.delayms(100)
end
for i = 0.5, 0, -0.05 do
if state == 1 then
c1:setduty(i)
c2:setduty(i)
end
tmr.delayms(100)
end
until nil
end
th_mpx = thread.start(mpx)
th_udt = thread.start(upd_datetime)
th_mcp = thread.start(mcp)
th_col = thread.start(colon)
