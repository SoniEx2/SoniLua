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

local pack
pack = function(...)
  return {n = select('#',...), ...}
end
M.utils.table.pack = pack

local corefunc = {}
do -- core functions
  --[[
    Prepare a function to be used in a getfenv-friendly sandbox
  --]]
  function corefunc.prepfunc(sandbox,fn)
    -- fn is an upvalue, getfenv can't access it ;)
    return setfenv(function(...) return fn(...) end, sandbox.executionEnvironment)
  end
  --[[
    Setup a "standard" sandbox as close to unsandboxed Lua as possible
  --]]
  function corefunc.standard(self)
  
  end
  --[[
    Execute code
  --]]
  function corefunc.execute(self, code, chunkname)
    local f, err = loadstring(code, chunkname)
    if not f then
      return false, err
    end
    setfenv(f, self.executionEnvironment)
    -- !!! TODO: fix this! interrupts (aka signals) don't work with coroutines! !!!
    -- !!! (or at least not when your code is `while true do end`) !!!
    local co = coroutine.create(f)
    if self.timeout and self.memout then
      local clock = os.clock() + self.timeout
      collectgarbage()
      collectgarbage()
      local mem = collectgarbage("count")
      debug.sethook(co, function()
        if os.clock() > clock then
          error("[Timed out]", 0)
        end
        if collectgarbage("count") - mem > self.memout then
          error("[Memory limit reached]", 0)
        end
      end, "clr")
    elseif self.timeout then
      local clock = os.clock() + self.timeout
      debug.sethook(co, function()
        if os.clock() > clock then
          error("[Timed out]", 0)
        end
      end, "clr")
    elseif self.memout then
      collectgarbage()
      collectgarbage()
      local mem = collectgarbage("count")
      debug.sethook(co, function()
        if collectgarbage("count") - mem > self.memout then
          error("[Memory limit reached]", 0)
        end
      end, "clr")
    end
    local data
    while coroutine.status(co) ~= "dead" do
      data = pack(coroutine.resume(co))
    end
    if not data[1] then
        data.n = data.n + 1
        data[data.n] = debug.traceback(co)
      end
    return unpack(data, 1, data.n)
  end
end

--[[
  Setup the backbones of a new sandbox
--]]
local function new()
  local sandbox = {}
  sandbox.executionEnvironment = {}
  sandbox.prepfunc = corefunc.prepfunc
  sandbox.makeStandardSandbox = corefunc.standard
  sandbox.execute = corefunc.execute
end

M.new = new

--[[
  Prepare the string metatable.
--]]
function M.prepareStringMetatable()
  
end

return M