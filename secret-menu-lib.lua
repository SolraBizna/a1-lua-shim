-- Copyright 2023 Solra Bizna. I expressly authorize you (the reader) to use
-- this script, change it to fit your needs, strip out my name and claim it as
-- your own, whatever. This copyright claim is solely to assert authorship long
-- enough to immediately disclaim all copy-rights.

-- Make sure `-a1-lua-shim.lua` loads before this!

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------

local OVERLAY_INDEX = 5
-- All of the sounds can be nil
local CURSOR_SOUND = Sounds["computer page"]
local SUCCESS_SOUND = Sounds["pattern buffer"]
local FAIL_SOUND = Sounds["cant toggle switch"]

-------------------------------------------------------------------------------
-- Upvalues
-------------------------------------------------------------------------------

local items = {}

-------------------------------------------------------------------------------
-- Global functions
-------------------------------------------------------------------------------

-- Adds an item to the end of the secret menu list, but only if it's not
-- already there. You are mostly free to put whatever structure you want into
-- this item, but a few methods are expected:
--
-- - `item:display(player)`: A function that returns the text to display. The
--   parameter is the `player` who is viewing this menu item, in case that
--   information is relevant. In addition to the string to display, this
--   function may return a second value, which is the color to display it in.
--   (If not specified, it will be white.)
-- - `item:activate1(player)`: OPTIONAL. Called when the given `player` presses
--   the primary fire button with this menu item selected. If this function
--   returns `nil`, the `FAIL_SOUND` will be played. If this function returns
--   something other than `false` or `nil`, the `SUCCESS_SOUND` is played. (If
--   you are going to play your own feedback sound, return `false` and no sound
--   will automatically be played.)
-- - `item:activate2(player)`: OPTIONAL: Like `activate1`, except it's called
--   when the `player` presses the secondary fire button.
-- - `always_shown`: Not a method, a field. If this is true, this item will
--   remain visible when the user releases the Lua key.
function add_secret_menu_item(item)
    for n=1,#items do
        if items[n] == item then
            return
        end
    end
    items[#items+1] = item
end

-- Removes the given item from the secret menu list, but only if it's already
-- there. Does nothing if this item is not in the list.
function remove_secret_menu_item(wat)
    for n=1,#items do
        if items[n] == wat then
            table.remove(items, n)
            return
        end
    end
end

-- Convenience function: Makes a secret menu item that just changes a key on
-- the player object between true and nil.
--
-- You almost certainly want `identifier` to start with an underscore.
function new_secret_player_boolean(
    false_text,
    true_text,
    identifier
)
    return {
        display=function(_, p)
            if p[identifier] then
                return true_text
            else
                return false_text
            end
        end,
        activate1=function(_, p)
            if p[identifier] then
                p[identifier] = nil
            else
                p[identifier] = true
            end
            return true
        end,
    }
end

-- Convenience function: Makes a secret menu item that just changes a key on
-- the Game object between true and nil. If `local_only` is unspecified or
-- false, anyone can toggle this value and it will affect everyone. If it is
-- truthy, then only the local player's toggles will be effective.
--
-- You almost certainly want `identifier` to start with an underscore.
function new_secret_game_boolean(
    false_text,
    true_text,
    identifier,
    local_only
)
    return {
        display=function(_, p)
            if Game[identifier] == true then
                return true_text
            else
                return false_text
            end
        end,
        activate1=function(_, p)
            if not local_only or p == Players.local_player then
                if Game[identifier] == true then
                    Game[identifier] = nil
                else
                    Game[identifier] = true
                end
                return true
            else
                -- don't even make a sound. spectators will see that we're
                -- looking at this menu item but won't be able to hear us try
                -- to toggle it.
                return false
            end
        end,
    }
end

-- Convenience function: Makes a secret menu item that just changes a stashed
-- key between "TRUE" and nil. If `local_only` is unspecified or false,
-- anyone can toggle this value and it will affect everyone. If it is truthy,
-- then only the local player's toggles will be effective.
function new_secret_stashed_boolean(
    false_text,
    true_text,
    identifier,
    local_only
)
    return {
        display=function(_, p)
            if Level.stash[identifier] == "TRUE" then
                return true_text
            else
                return false_text
            end
        end,
        activate1=function(_, p)
            if not local_only or p == Players.local_player then
                if Level.stash[identifier] == "TRUE" then
                    Level.stash[identifier] = nil
                else
                    Level.stash[identifier] = "TRUE"
                end
                return true
            else
                -- don't even make a sound. spectators will see that we're
                -- looking at this menu item but won't be able to hear us try
                -- to toggle it.
                return false
            end
        end,
    }
end

-- Return a string listing the current text displayed by every single menu
-- item. If there are no menu items, returns nil.
--
-- - `player`: Which player's secrets are to be divulged. If not specified, the
--   local player will be used.
-- - `delim`: Delimiter to use to separate each menu item. If not specified,
--   " | " will be used.
function list_all_secret_menus(player, delim)
   local player = player or Players.local_player
   local t = {}
   for i, item in ipairs(menu_items) do
      t[#t+1] = hopefully(item.display, item, player) or ("menu[%i] ERROR"):format(i)
   end
   if #t == 0 then return nil
   else return table.concat(t, delim or " | ")
   end
end

-------------------------------------------------------------------------------
-- Internal functions
-------------------------------------------------------------------------------

local function hopefully(f, ...)
    if not f then
        print(debug.traceback("Mandatory function missing!"))
        return
    end
    local ret = {xpcall(f, debug.traceback, ...)}
    if ret[1] then
        return select(2, table.unpack(ret))
    else
        print(ret[2])
        return nil
    end
end

local function do_action(player, f, ...)
    local success
    if f then
        success = hopefully(f, ...)
    end
    if success == nil then
        -- nil -> play fail sound
        if FAIL_SOUND then
            player:play_sound(FAIL_SOUND)
        end
    elseif success then
        -- truthy -> play success sound
        if SUCCESS_SOUND then
            player:play_sound(SUCCESS_SOUND)
        end
    end
end

-------------------------------------------------------------------------------
-- Triggers
-------------------------------------------------------------------------------

function Triggers.init()
    Game.nonlocal_overlays = true
end

function Triggers.idle()
    for p in Players() do
        if type(p._secret_menu_cursor) ~= "number"
          or p._secret_menu_cursor < 0
          or p._secret_menu_cursor > #items
          or math.floor(p._secret_menu_cursor) ~= p._secret_menu_cursor then
            p._secret_menu_cursor = 1
        end
        local overlay = p.overlays[OVERLAY_INDEX]
        if #items > 0 and p.action_flags.microphone_button then
            local go_left = p.action_flags.cycle_weapons_backward
            local go_right = p.action_flags.cycle_weapons_forward
            local activate1 = p.action_flags.left_trigger
            local activate2 = p.action_flags.right_trigger
            p.action_flags.cycle_weapons_backward = false
            p.action_flags.cycle_weapons_forward = false
            p.action_flags.left_trigger = false
            p.action_flags.right_trigger = false
            go_left, go_right = go_left and not go_right, go_right and not go_left
            activate1, p._secret_menu_activate1 = activate1 and not p._secret_menu_activate1, activate1
            activate2, p._secret_menu_activate2 = activate2 and not p._secret_menu_activate2, activate2
            if #items > 1 and (go_right or go_left) then
                if CURSOR_SOUND then
                    p:play_sound(CURSOR_SOUND)
                end
                if go_right then
                    p._secret_menu_cursor = p._secret_menu_cursor + 1
                    if p._secret_menu_cursor > #items then
                        p._secret_menu_cursor = 1
                    end
                elseif go_left then
                    p._secret_menu_cursor = p._secret_menu_cursor - 1
                    if p._secret_menu_cursor == 0 then
                        p._secret_menu_cursor = #items
                    end
                end
            end
            local item = items[p._secret_menu_cursor]
            if activate1 then
                do_action(p, item.activate1, item, p)
            end
            if activate2 then
                do_action(p, item.activate2, item, p)
            end
            local text, color = hopefully(item.display, item, p)
            overlay.color = color or "white"
            overlay.text = text or "ERROR"
        else
            local item = items[p._secret_menu_cursor]
            if item.always_shown then
                local text, color = hopefully(item.display, item, p)
                overlay.color = color or "white"
                overlay.text = text or "ERROR"
            else
                overlay:clear()
            end
            p._secret_menu_activate1 = nil
            p._secret_menu_activate2 = nil
        end
    end
end

