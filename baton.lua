local baton = {
  _VERSION = 'baton',
  _DESCRIPTION = 'Input library for LÖVE.',
  _URL = 'https://github.com/tesselode/baton',
  _LICENSE = [[
    MIT License

    Copyright (c) 2017 Andrew Minnich

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
  ]]
}

local source = {}

function source:key(key)
  return love.keyboard.isDown(key) and 1 or 0
end

function source:sc(sc)
  return love.keyboard.isScancodeDown(sc) and 1 or 0
end

function source:mouse(button)
  return love.mouse.isDown(tonumber(button)) and 1 or 0
end

function source:axis(value)
  if self.joystick then
    local axis, direction = value:match '(.+)([%+%-])'
    local v = tonumber(axis) and self.joystick:getAxis(tonumber(axis))
                              or self.joystick:getGamepadAxis(axis)
    if direction == '-' then v = -v end
    return v > 0 and v or 0
  end
  return 0
end

function source:button(button)
  if self.joystick then
    if tonumber(button) then
      return self.joystick:isDown(tonumber(button)) and 1 or 0
    else
      return self.joystick:isGamepadDown(button) and 1 or 0
    end
  end
  return 0
end

function source:hat(value)
  if self.joystick then
      local hat, direction = value:match('(%d)(.+)')
      if self.joystick:getHat(hat) == direction then
          return 1
      end
  end
  return 0
end

local Player = {}

function Player:_update()
  if self._time == love.timer.getTime() then
    return false
  end
  self._time = love.timer.getTime()

  local keyboardUsed = false
  local joystickUsed = false

  -- update controls
  for controlName, control in pairs(self._controls) do
    -- add up sources
    control.rawValue = 0
    for _, s in ipairs(self.controls[controlName]) do
      local kv, jv = 0, 0
      local type, value = s:match '(.+):(.+)'
      if type == 'key' or type == 'sc' or type == 'mouse' then
        kv = kv + source[type](self, value)
      elseif type == 'axis' or type == 'button' or type == 'hat' then
        if not keyboardUsed then
          jv = jv + source[type](self, value)
        end
      end
      if kv > 0 then
        control.rawValue = kv
        keyboardUsed = true
      elseif jv > 0 then
        control.rawValue = jv
        if jv > self.deadzone then joystickUsed = true end
      end
    end

    -- limit to 1
    if control.rawValue > 1 then control.rawValue = 1 end

    -- deadzone
    control.value = 0
    if control.rawValue >= self.deadzone then
      control.value = control.rawValue
    end

    -- down/pressed/released
    control.downPrevious = control.down
    control.down = control.value > 0
    control.pressed = control.down and not control.downPrevious
    control.released = control.downPrevious and not control.down
  end

  -- update pairs
  for pairName, pair in pairs(self._pairs) do
    local p = self.pairs[pairName]
    
    -- raw value
    pair.rawX, pair.rawY = self._controls[p[2]].rawValue - self._controls[p[1]].rawValue,
      self._controls[p[4]].rawValue - self._controls[p[3]].rawValue

    -- limit to 1
    local len = (pair.rawX^2 + pair.rawY^2) ^ .5
    if len > 1 then
      pair.rawX, pair.rawY = pair.rawX / len, pair.rawY / len
    end

    -- deadzone
    pair.x, pair.y = 0, 0
    if self.squareDeadzone then
      if math.abs(pair.rawX) > self.deadzone then
        pair.x = pair.rawX
      end
      if math.abs(pair.rawY) > self.deadzone then
        pair.y = pair.rawY
      end
    else
      if len > self.deadzone then
        pair.x, pair.y = pair.rawX, pair.rawY
      end
    end

    -- down/pressed/released
    pair.downPrevious = pair.down
    pair.down = pair.x ~= 0 or pair.y ~= 0
    pair.pressed = pair.down and not pair.downPrevious
    pair.released = pair.downPrevious and not pair.down
  end

  -- report active device
  if keyboardUsed then
    self._activeDevice = 'keyboard'
  elseif joystickUsed then
    self._activeDevice = 'joystick'
  end
end

function Player:getRaw(name)
  self:_update()
  if self._pairs[name] then
    return self._pairs[name].rawX, self._pairs[name].rawY
  else
    return self._controls[name].rawValue
  end
end

function Player:get(name)
  self:_update()
  if self._pairs[name] then
    return self._pairs[name].x, self._pairs[name].y
  else
    return self._controls[name].value
  end
end

function Player:down(name)
  self:_update()
  if self._pairs[name] then
    return self._pairs[name].down
  else
    return self._controls[name].down
  end
end

function Player:pressed(name)
  self:_update()
  if self._pairs[name] then
    return self._pairs[name].pressed
  else
    return self._controls[name].pressed
  end
end

function Player:released(name)
  self:_update()
  if self._pairs[name] then
    return self._pairs[name].released
  else
    return self._controls[name].released
  end
end

function Player:getActiveDevice()
  self:_update()
  return self._activeDevice
end

function baton.new(config)
  local player = setmetatable({
    _time = love.timer.getTime(),
    _controls = {},
    _pairs = {},
    controls = config.controls,
    pairs = config.pairs,
    joystick = config.joystick,
    deadzone = .5,
    squareDeadzone = false,
  }, {__index = Player})
  for controlName, _ in pairs(config.controls) do
    player._controls[controlName] = {
      rawValue = 0,
      value = 0,
      downPrevious = false,
      down = false,
      pressed = false,
      released = false,
    }
  end
  for pairName, _ in pairs(config.pairs) do
    player._pairs[pairName] = {
      rawX = 0,
      rawY = 0,
      x = 0,
      y = 0,
      downPrevious = false,
      down = false,
      pressed = false,
      released = false,
    }
  end
  return player
end

return baton