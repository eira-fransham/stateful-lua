local math = require 'math'

local mod = {}

local error = function(msg)
  error('stateful: ' .. msg)
end

local function nop(...)
end

local nopcoroutine = coroutine.create(nop)

function reverse(arr)
  local i, j = 1, #arr

  while i < j do
    arr[i], arr[j] = arr[j], arr[i]

    i = i + 1
    j = j - 1
  end
end

-- Do this mutably for _MAXIMUM SPEED_
local function normalizedef(statemachine)
  local definition = statemachine.definition

  for k, v in pairs(definition) do
    if type(v) == 'function' then
      definition[k] = {
        extend = nil,
        before = nop,
        after = nop,
        tick = v,
      }
      v = definition[k]
    end

    -- Then it must be a table
    v.enter = v.enter or nop
    v.exit = v.exit or nop
    v.tick = v.tick or nop

    v.extend_list = {}

    local ex = v.extend

    while ex do
      table.insert(v.extend_list, ex)

      ex = definition[ex].extend
    end

    reverse(v.extend_list)
  end
end

local function get_divergence_point(a, b)
  for i = 1, math.max(#a, #b) do
    local first, second = a[i], b[i]

    if first ~= second then
      return i
    end
  end

  return nil
end

local function exits(def, from, div)
  return coroutine.wrap(
    function()
      local list = def[from].extend_list

      coroutine.yield(def[from].exit)
      for i = #list, div, -1 do
        coroutine.yield(def[list[i]].exit)
      end
    end
  )
end

local function enters(def, to, div)
  div = div or 1
  return coroutine.wrap(
    function()
      local list = def[to].extend_list

      for i = div, #list do
        coroutine.yield(def[list[i]].enter)
      end
      coroutine.yield(def[to].enter)
    end
  )
end

local stmc_methods = {}

function stmc_methods:gotostate(to)
  local def, from = self.definition, self.state

  if from == to then
    return
  end

  local divergence = get_divergence_point(
    def[from].extend_list,
    def[to].extend_list
  )

  if divergence then
    local exits = exits(def, from, divergence)
    for exit in exits do
      exit(self.value, to)
    end
    for enter in enters(def, to, divergence) do
      enter(self.value, from)
    end
  end

  self.state = to
end

function stmc_methods:tick(...)
  local state = self.definition[self.state]

  local tick = state.tick
  if tick then
    local newstate = tick(self.value, ...)
    if newstate then
      self:gotostate(newstate)
      return
    end
  end

  local extends = self.definition[self.state].extend_list
  for i = #extends, 1, -1 do
    local tick = self.definition[extends[i]].tick
    if tick then
      local newstate = tick(self.value, ...)
      if newstate then
        self:gotostate(newstate)
        return
      end
    end
  end
end

function mod.new(definition, init, value)
  if not init or not definition[init] then
    error 'Missing default state'
  end

  local statemachine = {
    state = init,
    definition = definition,
    value = value,
  }

  setmetatable(statemachine, { __index = stmc_methods })

  normalizedef(statemachine)

  for enter in enters(statemachine.definition, init) do
    enter(statemachine.value, nil)
  end

  return statemachine
end

return mod
