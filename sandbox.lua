local M = {
  utils = {}
}

-- START table utils
M.utils.table = {}
local tcopy

do -- table.copy
  -- upvalues, screw globals
  local next,type,rawset = next,type,rawset
   
  local function deep(inp,rec)
    if type(inp) ~= "table" then
      return inp
    end
    local out = {}
    rec = (type(rec) == "table") and rec or {}
    rec[inp] = out -- use normal assignment so we use rec' metatable (if any)
    for key,value in next,inp do -- skip metatables by using next directly
      -- we want a copy of the key and the value
      -- if one is not available on the rec table, we have to make one
      -- we can't do normal assignment here because a custom rec table might set a metatable on out
      rawset(out,rec[key] or deep(key,rec),rec[value] or deep(value,rec))
    end
    return out
  end
   
  local function shallow(inp)
    local out = {}
    for key,value in next,inp do -- skip metatables by using next directly
      out[key] = value
    end
    return out
  end
  
  tcopy = {shallow = shallow, deep = deep}
end

M.utils.table.copy = tcopy -- "sandbox.utils.table.copy.deep(someTable, someRecursionIndexThing)"
-- END table utils

--[[
  Prepare a function to be used in a getfenv-friendly sandbox
--]]
local function prepfunc(sandbox,fn)
  -- fn is an upvalue, getfenv can't access it ;)
  return setfenv(function(...) return fn(...) end, sandbox)
end

--[[
  Setup the backbones of a new sandbox
--]]
local function new()
  local sandbox = {}
  sandbox.prepfunc = prepfunc
  --[[
    Setup a "standard" sandbox as close to unsandboxed Lua as possible
  --]]
  sandbox.makeStandardSandbox = function()
  end
end

M.new = new

--[[
  Prepare the string metatable.
--]]
function M.prepareStringMetatable()
  
end

return M