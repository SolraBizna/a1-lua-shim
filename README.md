This is a simple Lua script for the [Aleph One][1] engine. It makes it easier for multiple scripts to cooperate in the same context. It is intended to be especially helpful for scenario scripting.

[1]: https://github.com/Aleph-One-Marathon/alephone/

# Usage

Add this as the first script in your level/plugin/whatever. Make sure it runs before any other scripts.

In each script, you can declare triggers either of the ways that normally work in Aleph One. Piecemeal:

```lua
Triggers = {}

function Triggers.player_damaged(victim)
    victim.life = 300
end

function Triggers.idle()
   Players.print("Console spam!!!")
end
```

Or using the all-at-once method:

```lua
Triggers = {
   player_damaged = function(victim)
      victim.life = 300
   end,
   idle = function()
      Players.print("Console spam!!!")
   end,
}
```

This shim also provides an optional, extra classy method:

```lua
Triggers {
   player_damaged = function(victim)
      victim.life = 300
   end,
   idle = function()
      Players.print("Console spam!!!")
   end,
}
```

Triggers will be called, with all the normal parameters, in whatever order they are provided. If scripts A, B, and C all provide an `idle` trigger, then A's `idle` will be called first, B's second, and C's third. If a trigger has an error, the next triggers will still be called; in the previous example, if B's `idle` trigger throws a Lua error, C's `idle` trigger will still be called.

You can prevent subsequent triggers from being called by explicitly returning `false` from a trigger (e.g. if you prevented damage and don't want the next `player_damaged` trigger to be called).

# Bonus Features

## Danger Pairs

`pairs` gets its name changed to `danger_pairs`, so that casual use will be caught. `pairs` is a very useful function, irreplaceable for some purposes, and when used properly it can grant nice performance with no problems. However, careless use will cause films to desync. Thus, this shim renames it to `danger_pairs`. If you need it, and you're sure you're not going to cause a desync by using it, just use the longer name and you're all set. (In fact, *this script* contains two film-safe uses of `danger_pairs`!)

## Print

This script makes it so that `print` will print both to the screen *and* to the Aleph One log. It will even work during `Triggers.init` or at the top level of the script.

# Legalese

Copyright 2023 Solra Bizna. I expressly authorize you (the reader) to use this script, change it to fit your needs, strip out my name and claim it as your own, whatever. This copyright claim is solely to assert authorship long enough to immediately disclaim all copy-rights.
