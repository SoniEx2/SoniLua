--[[
	Notes:
	This bot uses <root>/<botName>/ for storing data (config, filesystem, etc...)
	You have to create the folder <root>/<botName>/filesystem manually for the filesystem to work. (Sorry!)
--]]

-- Bit.ly Config
bitly_enable = false
bitly_login = ""
bitly_apikey = ""

root = "C:" -- on windows this is (usually) "C:", on Mac/Linux this is "", you can also set it to C:/Path/To/A/Folder

basePrefix = '@SoniLua ' -- prefix

OpNick = "SoniEx2"

botName = "SoniLua" -- nick
networkAddress = "irc.esper.net" -- network
networkPort = 6667 -- port

-- Uncomment this line to enable NickServ
--nickServ = {nick = "SoniLua", pass = ""}

-- FileSystem
filesystem.enabled=true

-- START Unsafe features
hideActions=false
-- END Unsafe features

-- Case-Sensitive channel list
channelList = {"#Soni"}