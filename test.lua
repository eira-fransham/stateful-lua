local stateful = require 'stateful'

local def = {
  printmeparent = {
    enter = function(self, from)
      print('enter printmeparent' .. (from and (' from ' .. from) or ''))
    end,
    tick = function(self)
      print('tick printmeparent')
    end
  },
  printme = {
    extend = 'printmeparent',
    enter = function(self, from)
      print('enter printme' .. (from and (' from ' .. from) or ''))
    end,
    exit = function(self, to)
      print('exit printme to ' .. to)
    end,
    tick = function(self)
      print('tick printme')
    end
  },
  idle = {
    extend = 'printme',
    enter = function(self, from)
      print('enter idle' .. (from and (' from ' .. from) or ''))
    end,
    exit = function(self, to)
      print('exit idle to ' .. to)
    end,
    tick = function(self, ...)
      print 'tick idle'

      return 'another'
    end,
  },
  another = {
    extend = 'printmeparent',
    enter = function(self, from)
      print 'enter another'
    end,
    exit = function(self, to)
      print('exit another to ' .. to)
    end,
    tick = function(self, i)
      print('tick another')
      if i % 2 == 0 then
        return 'idle'
      end
    end,
  }
}

local mach = stateful.new(def, 'idle', { name = 'Test' })
local i = 0
while i < 10 do
  mach:tick(i)
  print ''
  i = i + 1
end
