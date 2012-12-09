local function formatTime( nTime, bTwentyFourHour )
	local sTOD = nil
	if not bTwentyFourHour then
		if nTime >= 12 then
			sTOD = "PM"
		else
			sTOD = "AM"
		end
		if nTime >= 13 then
			nTime = nTime - 12
		end
	end

	local nHour = math.floor(nTime)
	local nMinute = math.floor((nTime - nHour)*60)
	if sTOD then
		return string.format( "%d:%02d %s", nHour, nMinute, sTOD )
	else
		return string.format( "%d:%02d", nHour, nMinute )
	end
end

local function serializeImpl(t,tTracking)	
	local sType = type(t)
	if sType == "table" then
		if tTracking[t] ~= nil then
			error("Cannot serialize table with recursive entries")
		end
		tTracking[t] = true
		local result = "{"
		for k,v in pairs(t) do
			result = result..("["..serializeImpl(k, tTracking).."]="..serializeImpl(v, tTracking)..",")
		end
		result = result.."}"
		return result
	elseif sType == "string" then
		return string.format("%q",t)
	elseif sType == "number" or sType == "boolean" or sType == "nil" then
		return tostring(t)
	else
		error("Cannot serialize type "..sType)
	end
end

local function serialize(t)
	local tTracking = {}
	return serializeImpl(t,tTracking)
end

local function unserialize(s)
	local func, e = loadstring( "return "..s, "serialize" )
	if not func then
		return s
	else
		setfenv(func,{})
		return func()
	end
end

local function urlEncode( str )
	if str then
		str = string.gsub (str, "\n", "\r\n")
		str = string.gsub (str, "([^%w ])",
		function (c)
			if c~="." then
				return string.format ("%%%02X", string.byte(c))
			else
				return c
			end
		end)
		str = string.gsub (str, " ", "+")
	end
	return str	
end

textutils = {}
textutils.serialize = serialize
textutils.urlEncode = urlEncode
textutils.unserialize = unserialize
textutils.formatTime = formatTime