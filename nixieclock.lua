---------------------------------
-- Whitecat Nixie Clock
-- Lua RTOS
-- Author:  Steven R. Stuart
-- Jan 2020, Jul 2025
---------------------------------

--  GPIO Usage
--  ----------
--  tube position
--    GPIO 21  out
--    GPIO 22  out
--    GPIO 23  out
--    GPIO 25  out
--    GPIO 26  out
--    GPIO 27  out
--
--  7441 BCD
--    GPIO 16  out
--    GPIO 17  out
--    GPIO 18  out
--    GPIO 19  out
--
--  colons
--    GPIO 32  out
--    GPIO 33  out
--
--  neopixel
--    GPIO 13  out
--
--  12/24 hour select switch
--    GPIO 34  in
--
--  select time zone
--    GPIO 15  in
--
--  view IP address button
--    GPIO 35  in


-- time zones
EDST = -4             -- eastern daylight savings
EST  = -5             -- eastern standard
--CST  = -6
--MST  = -7
--PST  = -8
tz0 = EST  * 3600     -- convert time zones to seconds to add to UTC
tz1 = EDST * 3600
time_zone = tz0       -- Choose a time zone
inp_tz_sel = 15       -- timezone switch (daylight svgs time)

hours12 = false       -- Set true for 12 hour display
inp_hour_sel = 34     -- GPIO34 switch to choose 12/24 hour display
inp_view_ip = 35      -- GPIO35 pushbutton to view IP address
outp_neopix = pio.GPIO13

---==[ DISPLAY HANDLER ]==---
mpx_speed = 2     -- display update (in milliseconds)

-- tube anodes (lsd to msd) and digit bcd (abcd) output pins,
--tube_pos = {pio.GPIO21, pio.GPIO22, pio.GPIO23, pio.GPIO25, pio.GPIO26, pio.GPIO27}
tube_pos = {pio.GPIO27, pio.GPIO26, pio.GPIO25, pio.GPIO23, pio.GPIO22, pio.GPIO21}
digit_bcd = {pio.GPIO16, pio.GPIO17, pio.GPIO18, pio.GPIO19} -- ABCD
colons = {pio.GPIO32, pio.GPIO33}

time_value = {15, 15, 15, 15, 15, 15}  -- {sec, 10sec, 1m, 10m, 1h, 10h}
date_value = {15, 15, 15, 15, 15, 15}  -- {mo, 10mo, 1d, 10d, 1yr, 10yr}
nixie_disp = {15, 15, 15, 15, 15, 15}  -- this is what the multiplexer shows on the Nixies
am_pm = 'A'
colon_disp = 0  --0 off, 1 on


-- initialize tube position and digit bcd pins as outputs and set all to 0
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
    pio.pin.setpull(pio.PULLUP, p)  -- pins 34-39 do not feature pull-up/down circuitry
end

get_input = function(p)
    return pio.pin.getval(p) == 0   -- true when logic low
end

-- return an array of decimals in binary values
-- binarize(5) returns {1, 0, 1, 0}
-- ex:  x = binarize(7); print(x[4],x[3],x[2],x[1]) -- prints 0 1 1 1
binarize = function(dec)
  local b = {}
  b[1] = math.floor(dec % 2) -- lsb
  b[2] = math.floor(dec / 2 % 2)
  b[3] = math.floor(dec / 4 % 2)
  b[4] = math.floor(dec / 8 % 2)
  return b
end


-- Show the nixie_disp digit at the next tube position
nixie_control = function()
  local the_tube = 1
  return function()
    pio.pin.setlow(tube_pos[the_tube])         --turn off the active display tube
    the_tube = the_tube + 1                    --choose the next tube
    if the_tube == 7 then the_tube = 1 end     --rotate
    if string.byte(nixie_disp[the_tube]) < 58 then -- display if not blank, 57 = asc'9'
      local bcd = binarize(nixie_disp[the_tube]) --get binary value to display on the tube
      pio.pin.setval(bcd[1],digit_bcd[1])        --place BCD on Nixie driver chip
      pio.pin.setval(bcd[2],digit_bcd[2])
      pio.pin.setval(bcd[3],digit_bcd[3])
      pio.pin.setval(bcd[4],digit_bcd[4])
      pio.pin.sethigh(tube_pos[the_tube])        --turn on the tube
    end
  end
end


-- Nixie display multiplexer
mpx = function()  --run as a thread

  init_pins(tube_pos)
  init_pins(digit_bcd)
  init_pins(colons)

  local mpx = nixie_control()

  repeat
    mpx()
    tmr.delayms(mpx_speed)  -- single tube active time
  until nil
end

---==[ CLOCK ]==---

-- update the date_value and time_value arrays every 1/2 second
upd_datetime = function() --run as a thread

  local now, dt

  repeat
    now = os.time() + time_zone   -- get epoch seconds

    dt = os.date("%x", now)       -- date 09/16/98
    date_value[6] = dt:sub(1,1)
    date_value[5] = dt:sub(2,2)
    date_value[4] = dt:sub(4,4)
    date_value[3] = dt:sub(5,5)
    date_value[2] = dt:sub(7,7)
    date_value[1] = dt:sub(8,8)

    if( hours12 ) then
      dt = os.date("%I", now)     -- hours [01-12]
      local lz = dt:sub(1,1) -- leading zero blanking
      if lz == '0' then
        time_value[6] = 15
      else
        time_value[6] = dt:sub(1,1)
      end
    else
      dt = os.date("%H", now)     -- hours [00-23]
      time_value[6] = dt:sub(1,1)
    end
      time_value[5] = dt:sub(2,2)

    dt = os.date("%X", now)       -- time 23:48:10
    time_value[4] = dt:sub(4,4)
    time_value[3] = dt:sub(5,5)
    time_value[2] = dt:sub(7,7)
    time_value[1] = dt:sub(8,8)

    dt = os.date("%p", now)       -- "AM" or "PM"
    am_pm = dt:sub(1,1)

    tmr.delayms(500)
  until nil
end

-- copy disp_ara{} to nixie_disp
nixie_display = function( disp_ara )
  for i = 1, 6 do
    nixie_disp[i] = disp_ara[i]
  end
end

scroll = function(disp_ara, ms)

  ms = ms or 150

  -- work_buff initializes as: sSmMhH..sSmMhH
  -- positions 1..6 is the scroll in display
  -- positions 7 and 8 are blanks
  -- the current display is in positions 9..14

  local work_buff = {}

  for i = 1, 6 do   -- take a copy of what is showing
    work_buff[i+8] = nixie_disp[i]
  end
  for i = 1, 2 do   --
    work_buff[i+6] = 15
  end
  for i = 1, 6 do -- get desired display
    work_buff[i] = disp_ara[i]
  end

  local temp_disp = {}

  for i = 7, 0, -1 do  -- scroll it
    for j = 1, 6 do
      temp_disp[j] = work_buff[i+j]
    end
    nixie_display( temp_disp ) -- show it
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


depoison = function()  -- runs in a thread

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

  speed = speed or 150  -- milliseconds

  scroll( date_value, speed)
  tmr.delayms(3000)
  scroll( time_value, speed)
end


show_ip = function()

    local blank_disp = {15, 15, 15, 15, 15, 15}
    nixie_display(blank_disp)

    wf = net.wf.stat(true)
    --local a,b,c,d = string.match(wf.ip, "(%d+)%.(%d+)%.(%d+)%.(%d+)")
    --print(a,b,c,d)

    local disp = {}
    local ix = 7    -- disp index
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
      else  -- found end of token
        for j = ix-1, 1, -1 do -- fill rest of disp with blanks
          disp[j] = 15
        end
        show_disp()
        ix = 7      --re-init index for next token
      end
    end
    show_disp()
end


init_neopix = function(port,size)
    return neopixel.attach(neopixel.WS2812B, port, size)
end

get_time_zone = function()
  if get_input(inp_tz_sel) then
    return tz0
  else
    return tz1
  end
end

mcp = function()  -- run in a thread

  local hh, mm, ss

  --initialize user input switches
  init_input(inp_hour_sel)
  init_input(inp_tz_sel)
  init_input(inp_view_ip)

  --operation schedules
  local op = {
    showdate = function() return (ss == 10) or (ss == 40) end,
    eyecandy = function() return ss == 0 end,
    depoison = function() return (hh >= 1) and (hh <= 6) and (am_pm=='A') end,
    showip   = function() return get_input(inp_view_ip) end
    --showip   = function() return ss == 50 end
    --depoison = function() return (mm >= 28) and (mm <= 30) end
  }

  --pixel_mv = pixel_move()

  repeat -- forever

    time_zone = get_time_zone()
    hours12 = get_input( inp_hour_sel ) --set 12/24 hour flag

    --grab time tokens for calculations
    hh = time_value[6]*10 + time_value[5]
    mm = time_value[4]*10 + time_value[3]
    ss = time_value[2]*10 + time_value[1]

    --select and execute operation based on op{} logic
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

    --pixel_mv()
    tmr.delayms(500) -- yield the thread for 0.5 second

  until nil

end

-- colon separator lamps
colon = function()

  local state = 0   -- 0=stopped, 1=running
  local c1 = pwm.attach(pio.GPIO32, 100, 0.25) --pin, freq, dutycycle
  local c2 = pwm.attach(pio.GPIO33, 100, 0.25)

  local state_control = function()
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

    state_control()
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

-- Maintenance commands- run from terminal
time_now = function()
  print(
    time_value[6]..time_value[5]..":"..
    time_value[4]..time_value[3]..":"..
    time_value[2]..time_value[1].." "..
    date_value[6]..date_value[5].."-"..
    date_value[4]..date_value[3].."-"..
    date_value[2]..date_value[1]
  )
end

nixie_dump = function()
  print(
    nixie_disp[6].." "..
    nixie_disp[5].." "..
    nixie_disp[4].." "..
    nixie_disp[3].." "..
    nixie_disp[2].." "..
    nixie_disp[1]
  )
end


---==[ SYSTEM ]==---

print("system starting")

th_mpx = thread.start(mpx)     -- start the nixie display multiplexer
depoison()                     -- lamp test
th_col = thread.start(colon)   -- start colon system, NE-2 bulbs
colon_disp = 1                 -- begin colon display

if net.connected() then
  print("Wifi network is connected")
  net.stat()   -- show status on term
  show_ip()    -- show ip on nixie
else
  print("Wifi network has NOT connected !")
  repeat
    depoison()
  until nil
end

collectgarbage("count")

th_udt = thread.start(upd_datetime)   -- start date/time updater
th_mcp = thread.start(mcp)            -- start scheduler

print("system running")
