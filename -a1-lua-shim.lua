-- Copyright 2023 Solra Bizna. I expressly authorize you (the reader) to use
-- this script, change it to fit your needs, strip out my name and claim it as
-- your own, whatever. This copyright claim is solely to assert authorship long
-- enough to immediately disclaim all copy-rights.

-- Part 0: Don't let me call pairs() [by accident]. I hate pairs().

_G.danger_pairs = pairs
pairs = nil

-- Part 1: Create a system that allows triggers to be created cooperatively.
-- AND some safety stuff that will make it so that we won't do things the old
-- way by accident and ruin everything.

local shadow_triggers = {}
local the_real_triggers = {}
local subtriggers = {}

Triggers = nil

setmetatable(_G, {
   __index = {Triggers = shadow_triggers},
   __newindex = function(t, key, value)
      if key == "Triggers" then
         for key, value in danger_pairs(value) do
            shadow_triggers[key] = value
         end
      else
         rawset(_G, key, value)
      end
   end,
})

setmetatable(shadow_triggers, {
   __index = the_real_triggers,
   __newindex = function(t, key, value)
      if the_real_triggers[key] == nil then
         the_real_triggers[key] = function(...)
            local ret = true
            for _, subtrigger in ipairs(subtriggers[key]) do
               local success, result
               if debug and debug.traceback and xpcall then
                  success, result = xpcall(subtrigger, debug.traceback, ...)
               else
                  success, result = pcall(subtrigger, ...)
               end
               if not success then
                  -- There was a message. Print the error message.
                  print(result)
               elseif result == false then
                  -- If the subtrigger explicitly returned false, don't call
                  -- any more subtriggers.
                  ret = false
                  break
               end
            end
            return ret
         end
      end
      if subtriggers[key] == nil then
         subtriggers[key] = {}
      end
      table.insert(subtriggers[key], value)
   end,
   __call = function(me, t)
      for key, value in danger_pairs(t) do
         me[key] = value
      end
   end,
})

-- Part 2: Make print print *both* to the command line *and* to the screen,
-- even in Triggers.init(), even in the top level.

local messages_to_print_on_first_idle = {}
local real_print = print
function print(...)
   -- print prints its arguments separated by tabs
   local text = table.concat({...}, "\t")
   real_print(text)
   if messages_to_print_on_first_idle ~= nil then
      table.insert(messages_to_print_on_first_idle, text)
   else
      Players.print(text)
   end
end

function Triggers.idle()
   if messages_to_print_on_first_idle ~= nil then
      for _, message in ipairs(messages_to_print_on_first_idle) do
         Players.print(message)
      end
      messages_to_print_on_first_idle = nil
   end
end

-- Part 3: There's no downside to calling the restore_* functions if they're
-- not needed. They need to be called at least once per init() if they are
-- needed. So let's call them ourselves!

function Triggers.init(restoring_game)
   if restoring_game then
      Game.restore_saved()
   else
      Game.restore_passed()
   end
end
