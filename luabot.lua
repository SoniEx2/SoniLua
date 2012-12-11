--[[
--	Required External Libs:
--	- LuaIRC (http://luaforge.net/projects/luairc/)
--	- LuaBit (http://luaforge.net/projects/bit/)
--	- LuaJSON (http://luaforge.net/projects/luajson/)
--	- socket.http (???)
--]]

require 'irc'

-- Fix math.random()
math.randomseed(tonumber(tostring(os.time()):reverse():sub(1,6)))
for x=1,tonumber(tostring(os.time()):reverse():sub(1,6)) do
	math.random()
end

require 'bit'
require 'plugins.textutils'
require 'json'
http = require 'socket.http'

local base = _G

local irc = irc
local args = {...}
ignoreNotice=true
filesystem = {}

require 'config'

irc.register_callback("connect", function()
	
	-- NickServ
    if nickServ then
		irc.say("NickServ","identify "..nickServ.nick.." "..nickServ.pass)
	end
	
	for x,y in pairs(channelList) do
		irc.join(y)
	end
	
	ignoreNotice=false
	
end)

local output = false
local channel = nil
local active_nick = nil
local force_error = nil
local timeout = nil
local crlimit = 0
local antispam = 0
local showActions = not hideActions

local native_print=print
local native_strgsub=string.gsub
local native_strfind=string.find
_G.native_print=print
_G.native_strgsub=string.gsub
_G.native_strfind=string.find
local do_antispam=0

local antispam_user={}
local antispam_global={
helpful={}	
}
blacklist = {}

local user_handlers = {}
chanPrefix = {}

if filesystem.enabled then
	filesystem.open = function(sPath,sMode)
		if (not sMode) or sMode=="" then
			return nil, "Mode not found"
		end
		local sMode11 = sMode:sub(1,1)
		local sMode22 = sMode:sub(2,2)
		if not (sMode11=="r" or sMode11=="w") then
			native_print("11: "..sMode11)
			return nil, "Unknown mode"
		end
		if sMode22 then
			if sMode22~="" and (sMode22=="b" or sMode22=="+") then
					native_print("22: "..sMode22)
					return nil, "Unknown mode"
			end
		end
		if #sMode>2 then
			return nil, "Unknown mode"
		end
		sPath = native_strgsub(sPath,"\\","/")
		local _sPath = ""
		while sPath~=_sPath do
			_sPath = sPath
			sPath = native_strgsub(sPath,"%.%./","")
		end
		sPath=root.."/"..botName.."/filesystem/"..sPath
		local tFileHandler, sError = io.open(sPath,sMode)
		if not tFileHandler then
			a,b = native_strfind(sError,root.."/"..botName.."/filesystem/")
			sStart = string.sub(sError,1,a-1)
			sEnd = string.sub(sError,b)
			sError = sStart..sEnd
			return nil, sError
		end
		return tFileHandler, sError
	end
end

globalFunctions = {"assert", "collectgarbage", "error", "ipairs", "next", "pairs", "pcall", "print", "rawequal", "rawset", "rawget", "select", "tonumber", "tostring", "type", "unpack", "_VERSION", "sleep", "hexadecimal", "haspaid", "printarray", "bitly"}
globalTables = {"coroutine", "string", "table", "math", "bit", "textutils", "filesystem"}
pluginFunctions = {}

local f,err = io.open(root.."/"..botName.."/blacklist.txt","r")
if not f then
	native_print(err)
	native_print()
	native_print()
else
	blacklist = textutils.unserialize(f:read("*a"))
	f:close()
end

if type(blacklist)~="table" then
	native_print(type(blacklist).." is not table")
	blacklist = {}
end

function sleep(sleep_t)
  local a=os.clock()
  local a=a+sleep_t
  if sleep_t>10 then
    print("Error: max sleep time: 10 seconds")
  else
    while os.clock()<a do
	end
  end
end

function haspaid(name)
	local body,c,l,h = http.request('http://www.minecraft.net/haspaid.jsp?user='..name)
	return body
	--irc.say(chan,body)	
end

function bitly(long_url)
	if bitly_enable then
		local r,c,h,s = http.request("https://api-ssl.bitly.com/v3/shorten?login="..bitly_login.."&apiKey="..bitly_apikey.."&longUrl="..url_encode(long_url))
		local array=json.decode(r)
		local bitly=array.data.url
		local url=array.data.long_url
		if showActions then
			native_print(bitly)
			native_print(url)
		end
		return bitly
	else
		return nil, "Bit.ly command disabled by bot operator's choice"
	end
end

url_encode = textutils.urlEncode
	
function hexadecimal(x) return string.upper(string.format("%02x","0x"..bit.tohex(string.byte(x)))) end

--levenshtein
--[[
Function: EditDistance

Finds the edit distance between two strings or tables. Edit distance is the minimum number of
edits needed to transform one string or table into the other.
Parameters:
s - A *string* or *table*.
t - Another *string* or *table* to compare against s.
lim - An *optional number* to limit the function to a maximum edit distance. If specified
and the function detects that the edit distance is going to be larger than limit, limit
is returned immediately.
Returns:
A *number* specifying the minimum edits it takes to transform s into t or vice versa. Will
not return a higher number than lim, if specified.
Example:

:EditDistance( "Tuesday", "Teusday" ) -- One transposition.
:EditDistance( "kitten", "sitting" ) -- Two substitutions and a deletion.

returns...

:1
:3
Notes:
* Complexity is O( (#t+1) * (#s+1) ) when lim isn't specified.
* This function can be used to compare array-like tables as easily as strings.
* The algorithm used is Damerau–Levenshtein distance, which calculates edit distance based
off number of subsitutions, additions, deletions, and transpositions.
* Source code for this function is based off the Wikipedia article for the algorithm
<http://en.wikipedia.org/w/index.php?title=Damerau%E2%80%93Levenshtein_distance&oldid=351641537>.
* This function is case sensitive when comparing strings.
* If this function is being used several times a second, you should be taking advantage of
the lim parameter.
* Using this function to compare against a dictionary of 250,000 words took about 0.6
seconds on my machine for the word "Teusday", around 10 seconds for very poorly
spelled words. Both tests used lim.
Revisions:

v1.00 - Initial.
]]
function EditDistance( s, t, lim )
    local s_len, t_len = #s, #t -- Calculate the sizes of the strings or arrays
    if lim and math.abs( s_len - t_len ) >= lim then -- If sizes differ by lim, we can stop here
        return lim
    end
    
    -- Convert string arguments to arrays of ints (ASCII values)
    if type( s ) == "string" then
        s = { string.byte( s, 1, s_len ) }
    end
    
    if type( t ) == "string" then
        t = { string.byte( t, 1, t_len ) }
    end
    
    local min = math.min -- Localize for performance
    local num_columns = t_len + 1 -- We use this a lot
    
    local d = {} -- (s_len+1) * (t_len+1) is going to be the size of this array
    -- This is technically a 2D array, but we're treating it as 1D. Remember that 2D access in the
    -- form my_2d_array[ i, j ] can be converted to my_1d_array[ i * num_columns + j ], where
    -- num_columns is the number of columns you had in the 2D array assuming row-major order and
    -- that row and column indices start at 0 (we're starting at 0).
    
    for i=0, s_len do
        d[ i * num_columns ] = i -- Initialize cost of deletion
    end
    for j=0, t_len do
        d[ j ] = j -- Initialize cost of insertion
    end
    
    for i=1, s_len do
        local i_pos = i * num_columns
        local best = lim -- Check to make sure something in this row will be below the limit
        for j=1, t_len do
            local add_cost = (s[ i ] ~= t[ j ] and 1 or 0)
            local val = min(
                d[ i_pos - num_columns + j ] + 1, -- Cost of deletion
                d[ i_pos + j - 1 ] + 1, -- Cost of insertion
                d[ i_pos - num_columns + j - 1 ] + add_cost -- Cost of substitution, it might not cost anything if it's the same
            )
            d[ i_pos + j ] = val
            
            -- Is this eligible for tranposition?
            if i > 1 and j > 1 and s[ i ] == t[ j - 1 ] and s[ i - 1 ] == t[ j ] then
                d[ i_pos + j ] = min(
                    val, -- Current cost
                    d[ i_pos - num_columns - num_columns + j - 2 ] + add_cost -- Cost of transposition
                )
            end
            
            if lim and val < best then
                best = val
            end
        end
        
        if lim and best >= lim then
            return lim
        end
    end
    
    return d[ #d ]
end

--end levenshtein


local function antispam_line(channel,nick,line)
	--warning: time is not portable

	local print=function(...)
		local s=""
	        for k,v in ipairs({...}) do
	                s = s..tostring(v)
	        end
		if not isNotice then
			irc.say(channel,s)
		else
			irc.notice(channel,s)
		end
		if showActions then
			native_print(s)
		end
	end


	local max_time=60
	local max_lines=10
	local lev_weight=1.5
	local length_weight=0.01
	local time=os.time()
	if not antispam_user[nick] then
		antispam_user[nick]={}
	end
	local times=antispam_user[nick]
	local total_lines=0
	local total_weight=0
	local to_remove={}
	for k,v in pairs(times) do
		if v.ttime<(time-max_time) then
			table.insert(to_remove,k)
		else
			local distance=EditDistance(v.tline,line,40)
			local add=((1/(1+distance))*lev_weight)
			local lenadd=string.len(v.tline)*length_weight
			if lenadd<1 then lenadd=1 end
			--print(string.format("# %d+%f from (%f)'%s' to '%s'",distance,add,lenadd,v.tline,line))
			total_lines=total_lines+lenadd
			total_weight=total_weight+add
		end
	end
	for k,v in pairs(to_remove) do
		times[v]=nil
	end
	table.insert(times,{ttime=time,tline=line})
	
	local lenadd=string.len(line)*length_weight
	total_lines=total_lines+lenadd

	local total_final=total_lines+total_weight
	--print(string.format("Totals for %s: Line %d Distance %f for %f",nick,total_lines,total_weight,total_final))
	

	if(total_final>3 and (string.lower(tostring(channel))~="#soni" and string.lower(tostring(channel))~="#ccbots")) then
		if not antispam_global.botchan then antispam_global.botchan=0 end
		if(antispam_global.botchan+300<os.time()) then
			antispam_global.botchan=os.time()
		end
	end

	if(total_final>max_lines) then
		if not antispam_global.helpful[nick] then antispam_global.helpful[nick]=0 end
		if(antispam_global.helpful[nick]+60<os.time()) then
			antispam_global.helpful[nick]=os.time()
			print(nick..": antispam trigger")
		end
		return false
	end

	return true
end

function print(...)
	local s = ""
	for k,v in ipairs({...}) do
		--todo: fix for tables
		--if(type(v)=="string") then
			--setmetatable(v,nil) --disabled higher up
		s = s..tostring(v)
		--end
	end
	while type(s) ~= "string" do
		s=tostring(s)
	end

--[[	if(type(s)~="string") then
		s=tostring(s)
	end
	if(type(s)~="string") then
		returnff
	end]]
	if s == "" then return end
	output = true
	if do_antispam then
		antispam = antispam + 1
		if (not antispam_line(channel,active_nick,s)) then
			return
		end
		if antispam > 5 then
			force_error = "Message limit exceeded!"
			return
		end
	end
	if not isNotice then
		irc.say(channel, s)
	else
		irc.notice(channel, s)
	end
	if showActions then
		native_print(s)
	end
end

---paste

do --admin namespace closure

local last={}
local lastn=1

local admin_otp=nil
local admin_otp_expire=0

function admin_runstring(str)
	local f, err = loadstring(str)
	if f == nil then
		print(err)
	else
		local ok, err = pcall(f)
		if not ok then
			print(err)
		end
	end
end

function admin(argstring,chan)

	local sp
	if type(argstring)=="string" then
		sp=string.find(argstring," ")
	end
	local pass
	local cmd
	if sp then
		pass=string.sub(argstring,1,sp-1)
		cmd=string.sub(argstring,sp+1)
		if pass==admin_otp and admin_otp_expire>os.time() then
			admin_otp=nil
			if showActions then
				native_print('Do: "'..cmd..'"')
			end
			admin_runstring(cmd)
		else
			irc.say(chan, 'password failure')
		end
	else
		irc.say(chan, 'generating new pass...')
	end
	

	local pass=math.random()
	local data=pass:sub(3)
	local collide=0
	for k,v in pairs(last) do
		if v==data then
			collide=1
		end
	end
	if collide==0 then
		last[lastn]=data
		lastn=lastn+1
		if lastn>20 then
			lastn=1
		end
		admin_otp=data
		admin_otp_expire=os.time()+60 --not portable to random platforms
		native_print("pass: \""..admin_otp..'"')
		irc.notice(OpNick,"pass: \""..admin_otp..'"')
	else
		native_print("pass: unable to random")
		admin_otp=nil
	end

end


end --admin namespace closure

function printarray(a) local str="" for k,v in pairs(a) do str=str.."["..tostring(k).."]=("..tostring(v)..") " end print(str) end
function native_printarray(a) local str="" for k,v in pairs(a) do str=str.."["..tostring(k).."]=("..tostring(v)..") " end native_print(str) end

---paste

local sandboxRun
local force_reset

sandbox={}

local secure_run

local function forceErrorHook(...)
	--native_print("eh: ",...)
	--ar="ar:"
	--for k,v in pairs(debug.getinfo(2)) do ar=ar..' ['..tostring(k)..']='..tostring(v) end
	--native_print(ar)
	if os.clock() > timeout then
		force_error = "Time limit exceeded!"
	end
	if gcinfo() > 50000 then
		force_error = "Memory limit exceeded!"
		force_reset = true
	end
	if force_error ~= nil then
		local f = debug.getinfo(2, "f").func
		if f ~= secure_run then
			error(force_error)
		end
	end
end

local secure_loadstring = function(s,...)
	--if s:byte(1) == 27 then return nil, "yes, oh yes" end
	if type(s)~="string" or (string.byte(s,1) == 27) then
		return nil, "Bytecode loading not allowed"
	end
	
	local untrusted_function, message = loadstring(s,...)
	if not untrusted_function then
		return nil, message
	end
	setfenv(untrusted_function, sandbox)
	return untrusted_function
end

local function do_nothing()

end

local function create_msgh(f)
	--todo this shouldn't work like it does, find out why!
	local function msgh(...)
		native_print(string.format("MH F %d",force_error))
		if force_error ~= nil then
			f(...)
		end
		native_print("MH q")
	end
	return msgh
end

local function createSandbox()
	local t = {}
	local _G = _G
	local getfenv = getfenv
	local getmetatable = getmetatable
	local coroutine = coroutine
	local pluginFunctions = pluginFunctions
	local native_print = native_print
	
	local indext = {}
	
	setmetatable(t, {__index=indext})
	
	for k,v in ipairs(globalFunctions) do
		indext[v] = _G[v]
	end
	
	for k,v in pairs(pluginFunctions) do
		-- TODO fix this
	end
	
	for _,k in ipairs(globalTables) do
		local replacement = {}
		for k2,v2 in pairs(_G[k]) do
			replacement[k2] = v2
		end
		t[k] = replacement
	end
	
	t.string.find=function (self, ...)
		return "Nope"
	end
	t.string.rep=function (self, times)
		local nself=""
		for x=1,times do
			nself=nself..self
		end
		return nself
	end
	t.string.gsub=function (self, ...)
		return "Nope"
	end
	
	t.textutils.unserialize=function(s)
		local func, e = loadstring( "return "..s, "serialize" )
		if not func then
			return s
		else
			setfenv(func,sandbox)
			return func()
		end
	end

	t.os = {}
	for k,v in ipairs({"clock", "difftime", "time", "date"}) do
		t.os[v] = os[v]
	end
	
	t._G = t
	
	t.coroutine.create = function(f)
		crlimit = crlimit - 1
		if crlimit < 0 then
			force_error = "Coroutine limit exceeded!"
			error(force_error)
		end
		return coroutine.create(function()
			debug.sethook(forceErrorHook, "l")
			f()
		end)
	end
	
	t.coroutine.wrap = function(f)
		local c = t.coroutine.create(f)
		return function()
			local r = {t.coroutine.resume(c)}
			table.remove(r, 1)
			return unpack(r)
		end
	end
	
	indext.getfenv = function()
		return t
	end
	
	t.string.find=function (self, ...)
		return "Nope"
	end
	t.string.rep=function (self, times)
		local nself=""
		for x=1,times do
			nself=nself..self
			sleep(1)
		end
		return nself
	end
	t.string.gsub=function (self, ...)
		return "Nope"
	end
	
	getmetatable("").__index.find=function (self, ...)
		--native_print(debug.getinfo(2).source)
		if isSandboxCmd then
			return "Nope"
		else
			return native_strfind(self, ...)
		end
	end
	getmetatable("").__index.gsub=function (self, ...)
		--native_print(debug.getinfo(2).source)
		if isSandboxCmd then
			return "Nope"
		else
			return native_strgsub(self, ...)
		end
	end
	getmetatable("").__index.rep=function (self, times)
		local nself=""
		for x=1,times do
			nself=nself..self
		end
		return nself
	end
	
	indext.getmetatable = function(t2)
		if type(t2) ~= "table" then
			return nil
		end
		if t == t2 then
			return nil
		end
		return getmetatable(t2)
	end
	
	indext.setmetatable = function(t2, mt)
		if type(t2) ~= "table" then
			return
		end
		if t == t2 then
			return
		end
		setmetatable(t2, mt)
	end

	indext.xpcall=function(f,msgh,...)
		call_handler=create_msgh(msgh)
		xpcall(f,call_handler,...)
	end
	
	
--[[	t.loadstring = function(s)
		-- TODO sandbox this
		--error(2, "No.")
		--if s:byte(1) == 27 then return nil, "yes, oh yes" end
		if type(s)~="string" or (string.byte(s,1) == 27) then error("yes, oh yes",2) end
		local untrusted_function, message = loadstring(s)
		if not untrusted_function then return nil, message end
		setfenv(untrusted_function, t)
		return untrusted_function
	end]]
	t.loadstring=secure_loadstring
		
	return t
end

sandbox = createSandbox()

--local
function sandboxRun(code, name)
	local f, err = secure_loadstring(code, name)
	if f == nil then
		print(err)
		return
	end
	secure_run(f,name)
end

--local
function secure_run(func,name, ...)
	antispam = 0
	
	output = false
	setfenv(func, sandbox)
	force_error = nil
	crlimit = 20
	timeout = os.clock() + 10
	do_antispam=1

	debug.sethook(forceErrorHook, "l")
	
	isSandboxCmd = true
	local ok, err = pcall(func, ...)
	isSandboxCmd = false
	
	debug.sethook()

	do_antispam=0
	antispam = 0
	
	if force_error ~= nil then
		-- get an error message using the same formatting
		--kevin: todo: verify this line
		ok, err = pcall(loadstring("local a={...} error(a[1])", name), force_error)
		if force_reset then
			force_reset = false
			sandbox = createSandbox()
			
			collectgarbage()
			collectgarbage()
		end
	end
	if not ok then
		print(err)
	end
	if not output then
		print("No output.")
	end
end

irc.register_callback("private_msg", function(from, msg)
	if isBlacklisted(from) then
		msg = ""
		return
	end
	isNotice=false
	if msg == "pil" then
		irc.say(from, "http://www.lua.org/pil/")
	elseif msg:sub(1,8)=="haspaid " then
	    channel = from
		cmd = msg:sub(9)
		irc.say(from,haspaid(cmd))
    elseif (" "..msg.." "):find("[^a-zA-Z]LUA[^a-zA-Z]") then
		local foo=from..": Lua is not an acronym."
		if not(antispam_global.lua) then antispam_global.lua=0 end
		if(os.time()>(antispam_global.lua+60)) and antispam_line(chan,from,foo) then
			antispam_global.lua=os.time()
			irc.say(chan, from..": Lua is not an acronym.")
		end
	else
	    channel = from
		active_nick=from
		if showActions then
			native_print("running \""..msg.."\" for "..from.." in private conversation")
		end
		sandbox.irc_nick=tostring(from)
		sandbox.irc_channel=tostring(from)		
		sandboxRun(msg, from)
	end
end)

irc.register_callback("private_notice", function(from, msg)
	if not ((ignoreNotice) or (from=="NickServ")) then
		if isBlacklisted(from) then
			msg = ""
			return
		end
		isNotice=true
		if msg == "pil" then
			irc.notice(from, "http://www.lua.org/pil/")
		elseif msg:sub(1,8)=="haspaid " then
			channel = from
			cmd = msg:sub(9)
			irc.notice(from,haspaid(cmd))
		elseif (" "..msg.." "):find("[^a-zA-Z]LUA[^a-zA-Z]") then
			local foo=from..": Lua is not an acronym."
			if not(antispam_global.lua) then antispam_global.lua=0 end
			if(os.time()>(antispam_global.lua+60)) and antispam_line(chan,from,foo) then
				antispam_global.lua=os.time()
				irc.notice(from, from..": Lua is not an acronym.")
			end
		else
			channel = from
			active_nick=from
			if showActions then
				native_print("running \""..msg.."\" for "..from.." in private conversation")
			end
			sandbox.irc_nick=tostring(from)
			sandbox.irc_channel=tostring(from)		
			sandboxRun(msg, from)
		end
	end
end)

function getChanPrefix(chan,msg,from)
	if msg:sub(1,9)==basePrefix then
		return basePrefix
	else
		return chanPrefix[chan:lower()] or basePrefix
	end
end

function setPrefix(prefix, chan)
    chan = chan:lower()
    if chan~="base" then
        chanPrefix[chan] = prefix
    else
        basePrefix = prefix
    end
end

function isChannelOp(from,chan)
	local x=chan._members[from]
	if (x:sub(1,1)=="@") and (from~=x) then
		return true
	else
		return false
	end
end

irc.register_callback("nick_change", function(new_nick, from)
	if from==OpNick then
		OpNick=new_nick
	end
end)

function isBlacklisted(sName)
	for x,y in pairs(blacklist) do
		if y:lower()==sName:lower() then
			return true
		end
	end
	return false
end

function hasHomophobicWord(msg)
	local tHomophobicWordList = {"fag","faggot","homo"}
	for x,y in pairs(tHomophobicWordList) do
		if msg:find("[^a-zA-Z]"..y.."[^a-zA-Z]") then
			return true
		end
	end
	return false
end

function hasRacistWord(msg)
	local tRacistWordList = {"nigger","redneck","wide eyes"}
	for x,y in pairs(tRacistWordList) do
		if msg:find("[^a-zA-Z]"..y.."[^a-zA-Z]") then
			return true
		end
	end
	return false
end

irc.register_callback("channel_msg", function(chan, from, msg)
	channel = chan._name
	active_nick = tostring(from)
	isNotice=false
	if isBlacklisted(active_nick) then
		msg = ""
		return
	end
	local cprefix=getChanPrefix(channel,msg,from)
	local cprefixlen=#cprefix
	if msg:sub(1,cprefixlen+4)==cprefix.."lua " then
		torun=msg:sub(cprefixlen+5)
		if showActions then
			native_print("running \""..torun.."\" for "..from.." in "..chan)
		end
		sandbox.irc_channel=tostring(chan)
		sandbox.irc_nick=tostring(from)
		sandboxRun(torun, from)
	elseif msg==cprefix.."die" then
        if (string.lower(tostring(from))==string.lower(tostring(OpNick))) then
            assert(false,"DEAD!")
        else
		    irc.notice(from, "Nope ;)")
		end
	elseif msg:sub(1,cprefixlen+10)==cprefix.."setprefix " then
        if (string.lower(tostring(from))==string.lower(tostring(OpNick))) then
			cmd = msg:sub(cprefixlen+11)
			sp=string.find(cmd," ")
			if sp then
				chann=string.sub(cmd,1,sp-1)
				newprefix=string.sub(cmd,sp+1)
				setPrefix(newprefix,chann)
				print("Prefix for channel "..chann.." changed to "..newprefix)
			else
				print("Usage: <channel> <prefix>")
			end
		else
			return
		end
	elseif msg:sub(1,cprefixlen+6)==cprefix.."admin " then
		local cmd=msg:sub(cprefixlen+7)
		if showActions then
			native_print("ADMIN \""..cmd.."\" for "..from.." in "..chan)
		end
		admin(cmd,chan)
	elseif msg:sub(1,cprefixlen+14)==cprefix.."blacklist add " and string.lower(tostring(from))==string.lower(tostring(OpNick)) then
		local cmd=msg:sub(cprefixlen+15)
		if showActions then
			native_print("BLACKLIST \""..cmd.."\" for "..from.." in "..chan)
		end
		table.insert(blacklist,cmd:lower())
		local f,err=io.open(root.."/"..botName.."/blacklist.txt", "w")
		if not f then
			native_print(err)
		else
			native_print("Saving blacklist...")				
			while not f:write(tostring(textutils.serialize(blacklist))) do
				native_print("Saving blacklist...")
			end
			--f:flush()
			--f:close()
			if io.close(f) then
				native_print("Blacklist saved!")
			end
		end
	elseif msg:sub(1,cprefixlen+14)==cprefix.."blacklist del " and string.lower(tostring(from))==string.lower(tostring(OpNick)) then
		local cmd=msg:sub(cprefixlen+15)
		if showActions then
			native_print("UNBLACKLIST \""..cmd.."\" for "..from.." in "..chan)
		end
		local a
		for x,y in pairs(blacklist) do
			if y==cmd:lower() then
				a=x
			end
		end
		if not a then return end
		table.remove(blacklist,a)
		f,err=io.open(root.."/"..botName.."/blacklist.txt", "w")
		if not f then
			native_print(err)
		else
			f:write(textutils.serialize(blacklist))
			f:close()
		end
	elseif msg == cprefix.."resetlua" then
		sandbox = {}
		sandbox = createSandbox()
		irc.say(chan, "Sandbox reset")
	elseif msg == cprefix.."pil" then
		irc.say(chan, "http://www.lua.org/pil/")
	elseif msg:sub(1,cprefixlen+4) == cprefix.."pil " then
		irc.say(chan, msg:sub(cprefixlen+5)..": http://www.lua.org/pil/")
    elseif msg:sub(1,cprefixlen+5)==cprefix.."join " then
        if (string.lower(tostring(from))==string.lower(tostring(OpNick))) then
            local cmd=msg:sub(cprefixlen+6)
			if showActions then
				native_print("JOIN \""..cmd.."\" for "..from.." in "..chan)
			end
            irc.join(cmd)
        else
		    return
		end
    elseif msg==cprefix.."leave" then
		if showActions then
			native_print("LEAVE \""..chan.."\" for "..from)
		end
		irc.say(channel, "Leaving...")
		irc.part(channel)
	elseif msg:sub(1,cprefixlen+8)==cprefix.."haspaid " then
		cmd = msg:sub(cprefixlen+9)
		irc.say(chan,haspaid(cmd))
	elseif msg:sub(1,cprefixlen+6)==cprefix.."bitly " then
		cmd=msg:sub(cprefixlen+7)
		if showActions then
			native_print("BITLY \""..cmd.."\" for "..from.." in "..chan)
		end
		irc.say(chan,"shortening "..cmd..", please wait...")
		sleep(2)
		local bitly_url,err=bitly(cmd)
		if bitly_url then
			irc.say(chan,"done! "..bitly_url)
		else
			irc.say(chan,err)
		end
	elseif msg==cprefix.."suicide" then
		if showActions then
			native_print("running SUICIDE for "..from.." in "..chan)
		end
		irc.act(channel, "commits suicide")
	elseif msg:sub(1,cprefixlen+4)==cprefix.."act " then
		if showActions then
			native_print("running ACT for "..from.." in "..chan)
		end
		cmd=msg:sub(cprefixlen+5)
		irc.act(channel, cmd)
	elseif msg:sub(1,cprefixlen+5)==cprefix.."kick " then
		if isChannelOp(from,chan) then
			local cmd=msg:sub(cprefixlen+6)
			sp=string.find(cmd," ")
			local reason=""
			if sp then
				reason=string.sub(cmd,sp+1)
				cmd=string.sub(cmd,1,sp-1)
			end
			if cmd ~= "SoniLua" then
				if showActions then
					native_print("KICK \""..cmd.."\" for "..from.." in "..chan)
				end
				if reason~="" then
					irc.send("KICK",channel,cmd,reason)
				else
					irc.send("KICK",channel,cmd)
				end
			end
		else
			irc.say(channel,from..": This command requires you to be a channel operator!")
		end
	elseif msg:sub(1,cprefixlen+7)==cprefix.."lmgtfy " then
		local cmd=msg:sub(cprefixlen+8)
		local cmd=url_encode(cmd)
		if showActions then
			native_print("LMGTFY \""..cmd.."\" for "..from.." in "..chan)
		end
		irc.say(channel,"http://lmgtfy.com/?q="..cmd)
	elseif msg:sub(1,cprefixlen)==cprefix then
		if sandbox.irc_command then
			local cmd=msg:sub(cprefixlen+1)
			if showActions then
				native_print('irc_command in "'..chan..'" from "'..from..'" : "'..cmd..'"')
			end
			secure_run(sandbox.irc_command,from,chan,from,cmd)
		end
	elseif (" "..msg.." "):find("[^a-zA-Z]LUA[^a-zA-Z]") then
		local foo=from..": Lua is not an acronym."
		if not(antispam_global.lua) then antispam_global.lua=0 end
		if(os.time()>(antispam_global.lua+60)) and antispam_line(chan,from,foo) then
			antispam_global.lua=os.time()
			irc.say(chan, from..": Lua is not an acronym.")
		end
	else
		local msg = (" "..msg.." "):lower()
		if hasHomophobicWord(msg) then
			if isChannelOp(from,chan) then
				irc.send("KICK",channel,from,"THIS IS A LGBT FRIENDLY BOT, MOTHERFUCKER!")
			else
				irc.send("KICK",channel,from,"NO HOMOPHOBIA!")
			end
		elseif hasRacistWord(msg) then
			irc.send("KICK",channel,from,"NO RACISM!")
		end
	end
end)

irc.connect {
	nick = botName,
	username = botName,
	realname = botName,
	network = networkAddress,
	port = networkPort,
	timeout = 120
}