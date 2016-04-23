module ("luci.youkucloud.function", package.seeall)

local Configs = require("luci.youkucloud.config")
local LuciOS = require("os")
local LuciProtocol = require("luci.http.protocol")
local uci = require("luci.model.uci")
local LuciUci = uci.cursor()
local LuciHttp = require("luci.http")
local SocketHttp = require("socket.http")
local ltn12 = require("ltn12")
local LuciJson = require("luci.json")                                                                       
local LuciUtil = require("luci.util")
local logger = require("luci.logger")

local PWDKEY = "YoukuRouter"

-- returns a hex string
function sha1(message)
    local SHA1 = require("luci.youkucloud.sha1")
    return SHA1.sha1(message)
end

function getUConfig(key, defaultValue, config) 
    if not config then
        config = "default"
    end
    local value = LuciUci:get(config, "common", key)
    return value or defaultValue;
end

function setUConfig(key, value, config)
    if not config then
        config = "default"
    end
    if value == nil then
        value = ""
    end
   
    LuciUci:set(config, "common", key, value)
    LuciUci:save(config)
    return LuciUci:commit(config)
end

function checkAdminPwd(pwd)
    local password = getUConfig("admin", nil, "account")
    if not isStrNil(pwd) and not isStrNil(password) then
        if sha1(PWDKEY..pwd) == password then
            return true
        end
    end
    return false
end

function checksha1Pwd(pwd)
    local password = getUConfig("admin", nil, "account")
    if not isStrNil(pwd) and not isStrNil(password) then
        if pwd == password then
            return true
        end
    end
    return false
end

function checkSNPwd(pwd)
    local password = getUConfig("SN", nil, "account")
    if not isStrNil(pwd) then
        local sncode = getroutersn()
        if not isStrNil(sncode) and string.len(sncode) > 6 then 
			if pwd == string.sub(sncode,-6) then
				return true
			end
        end
    end
    return false
end

function setAdminPwd(pwd)
   if not isStrNil(pwd) then
   		setUConfig("admin", sha1(PWDKEY..pwd), "account")
   end
end

function setSNPwd(pwd)
   if not isStrNil(pwd) then
   		setUConfig("SN", sha1(PWDKEY..pwd), "account")
   end
end

function req_get(requrl)
    if not requrl then
        return 601, nil
    end
    local ret = {}
    local client, code, headers, status = SocketHttp.request{ url=requrl, sink=ltn12.sink.table(ret), method="GET"}
    local result = LuciJson.decode(ret[1])
    return code, result
end

--[[
@param mac: mac address
@return XX:XX:XX:XX:XX:XX
]]--
function macFormat(mac)
    if mac then
        return string.upper(string.gsub(mac,"-",":"))
    else
        return ""
    end
end

function checkmac(val)
	if val and val:match(
		"^[a-fA-F0-9]+:[a-fA-F0-9]+:[a-fA-F0-9]+:" ..
		 "[a-fA-F0-9]+:[a-fA-F0-9]+:[a-fA-F0-9]+$"
	) then
		local parts = string.split( val, ":" )

		for i = 1,6 do
			parts[i] = tonumber( parts[i], 16 )
			if parts[i] < 0 or parts[i] > 255 then
				return false
			end
		end

		return true
	end

	return false
end

function isStrNil(str)
    return (str == nil or str == "")
end

function parseEnter2br(str)
    if (str ~= nil) then
        str = str:gsub("\r\n", "<br>")
        str = str:gsub("\r", "<br>")
        str = str:gsub("\n", "<br>")
    end
    return str
end

function trimLinebreak(str)
    if (str ~= nil) then
        str = str:gsub("\r\n", "")
        str = str:gsub("\r", "")
        str = str:gsub("\n", "")
    end
    return str
end

function forkRestartWifi()
    LuciOS.execute("nohup "..Configs.FORK_RESTART_WIFI)
end
function forkRestartDnsmasq()
    LuciOS.execute("nohup "..Configs.FORK_RESTART_DNSMASQ)
end
function getpppoelogpath()
    return trimLinebreak(LuciUtil.exec("grep logfile /etc/ppp/options | cut -d ' ' -f 2"))
end

function getyoukuvertion()
	return LuciUtil.exec(Configs.GET_ROUTER_VERSION) or "1.0.0.1"
end

function getTime()
    return os.date("%Y-%m-%d--%X",os.time())
end

function hzFormat(hertz)
    local suff = {"Hz", "KHz", "MHz", "GHz", "THz"}
    for i=1, 5 do
        if hertz > 1024 and i < 5 then
            hertz = hertz / 1024
        else
            return string.format("%.2f %s", hertz, suff[i])
        end
    end
end

function byteFormat(byte)
    local suff = {"B", "KB", "MB", "GB", "TB"}
    for i=1, 5 do
        if byte > 1024 and i < 5 then
            byte = byte / 1024
        else
            return string.format("%.2f %s", byte, suff[i])
        end
    end
end

function checkSSID(ssid)
    if isStrNil(ssid) then
        return false
    end
	
	if string.len(ssid) > 30 then
	    return false
	end
    return true
end

function getruntime(type)
  local catUptime = "cat /proc/uptime"
  local data = LuciUtil.exec(catUptime)
  local timetmp = 0
  if data == nil then
    timetmp = 0
  else
    local t1,t2 = data:match("^(%S+) (%S+)")
    timetmp = t1
  end
  
  retdata = "0,0,0,0"
  if timetmp ~= 0 then
    local timeas,timems = timetmp:match("^(%S+).(%S+)")
    local mm = 60
    local hh = 60*60
    local dd = 60*60*24

    local day = tostring(math.floor(tonumber(timeas)/dd))
    local hour = tostring(math.floor((tonumber(timeas)-tonumber(day)*dd)/hh))
    local minute = tostring(math.floor((tonumber(timeas)-tonumber(day)*dd-tonumber(hour)*hh)/mm))
    local second = tostring(tonumber(timeas)-tonumber(day)*dd-tonumber(hour)*hh-tonumber(minute)*mm)

    retdata = day..","..hour..","..minute..","..second
  end
  return retdata
end

function getrouterpid()	
	  return LuciUtil.exec(Configs.SN_YOUKU_EXEC)
end

function getroutercrypid()	
	  return LuciUtil.exec(Configs.SN_YOUKU_EXEC_CRYPT) or nil
end

function getroutersn()
    return string.sub(LuciUtil.exec(Configs.SN_YOUKU_EXEC),-16) or nil
end

function getaccmode()
    return "1"
end

function setaccmode(accmode)
    return 0
end

function getWanGatewayenable()
    local devcnt,dspeed,uspeed,online=getDeviceSumInfo()
    return online==1
end

function createPCDNURLparam()
	local tokenstring = ""
	local tokenstringwithwifi = ""
	local rkey = ""

	local code, datainfo = req_get(Configs.ROUTER_FRAMWORK_TOKEN)
	if code ~= 200 or not datainfo then
        return tokenstring, tokenstringwithwifi, rkey
    end
	
	local wifisetting = require("luci.youkucloud.wifiSetting")
	if tonumber(datainfo["code"]) == 0 then
	    local wanip,wanmac = wifisetting.getWanIPMac()
		tokenstring = datainfo["token"] or ""
		local rkeystart,rkeyend = string.find(tokenstring,"crypt=")
		rkey = string.sub(tokenstring,rkeyend+1)
	    if wanip ~= "0.0.0.0" then
	        tokenstring = "&ip="..wanip..tokenstring
	    end 
		tokenstringwithwifi = tokenstring
		local wifiinfo = wifisetting.getWifiSimpleInfo(1)
		if wifiinfo["name"] ~= "" then
			tokenstringwithwifi = "&ssid="..wifiinfo["name"]..tokenstring
		end
	end
    return tokenstring, tokenstringwithwifi, rkey
end

function getWifiInfo()
	local info = {}
	local wifi_mac_info = LuciUtil.exec("youku_wlan_table")
	local str_lines = string.split(wifi_mac_info,"\n") 
	local line_number = 1                                                           
	local colum_index = 1  
	for _i, a_line in ipairs(str_lines) do                                          
	        if line_number > 1 then
	        	local words = string.split(a_line, " ")                         
	        	    if table.getn(words) < 6 then                                   
	                      break                                                   
	                end
	                colum_index = 1
	                local index 
					local mac,mode = nil,nil
	                for index, a_world in ipairs(words) do
					    if string.len(a_world) > 0 then
							if colum_index == 1 then
								mac = string.lower(a_world)
							end
							if colum_index == 12 then
								mode = a_world
							end
	                	    colum_index = colum_index + 1
						end
	                end
					
					if mac and not isStrNil(mac) then
					    info[mac] = mode or "2.4G"
					end
	        end
	        line_number = line_number + 1
	end
	return info
end

function getBindInfo()
	local info = {}
	LuciUci:foreach("dhcp","host",                                            
	        function(s)                                                       
	                if s ~= nil then                                          
	                      local item = {                                    
	                          ["name"] = s.name,                        
	                          ["mac"] = s.mac,                          
	                          ["ip"] = s.ip                             
	                       }                                                 
                               info[s.mac] = item                                
	                 end
	        end 
        )
        return info
end

function dhcp_table()
	local dhcp_info = LuciUtil.exec("cat /var/dhcp.leases")

	local mac_name_map = {}
	local dhcp_info_lines = string.split(dhcp_info)
	local i = 1
	local dhcp_mac,dhcp_name
	for _, a_dhcp_line in ipairs(dhcp_info_lines) do
		local dhcp_words = string.split(a_dhcp_line," ")
		i = 1
		dhcp_mac = nil
		dhcp_name = nil
		for index, a_dhcp_word in ipairs(dhcp_words) do
			if i == 2 then
				dhcp_mac = a_dhcp_word	
			elseif i == 4 then
				dhcp_name = strtrim(a_dhcp_word)
			end
			i = i + 1
		end

		if dhcp_mac ~= nil then
			mac_name_map[dhcp_mac] = dhcp_name

			if dhcp_name == "" or dhcp_name == "*" then
			    mac_name_map[dhcp_mac] = string.upper(dhcp_mac)
			end
		end
	end

	return mac_name_map
end

function get_rate_map()
	local rate_info = LuciUtil.exec("/usr/sbin/youku_speed")
	local str_lines = string.split(rate_info,"\n")
	local colum_index = 1
	local ip = "none"
	local down_rate = "none"
	local up_rate = "none"
	local devices = {}
	for _i, a_line in ipairs(str_lines) do
		local words = string.split(a_line," ")
		colum_index = 1
		ip = "none"
		down_rate = "none"
		up_rate = "none"
		for index, a_word in ipairs(words) do
			if string.len(a_word) > 0 then
				if colum_index == 1 then
					ip = a_word
				elseif colum_index == 2 then
					down_rate = a_word
				elseif colum_index == 3 then
					up_rate = a_word
				end
				colum_index = colum_index + 1
			end
		end

		devices[ip] = { ["ip"] = ip,
				["down_rate"] = down_rate,
				["up_rate"] = up_rate}
	end
	return devices
end

function getMacFilterInfo()                                                     
        local info = {}                                                         
        LuciUci:foreach("macfilter","machine",                                  
                function(s)                                                     
                        if s ~= nil and s.mac ~= nil and s.name ~= nil then
                              local item = {                                    
                                  ["mac"] = s.mac,                              
                                  ["name"] = s.name                             
                               }                                                
                               info[s.mac] = item                               
                         end                                                    
                end                                                             
        )                                                                       
        return info                                                             
end

function getMacFilterList()                                                     
        local info = {}                                                         
        LuciUci:foreach("macfilter","machine",                                  
			function(s)                                                     
				if s ~= nil and s.mac ~= nil and s.name ~= nil then
					  table.insert(info, {mac = s.mac, name = s.name})
				end                                                    
			end                                                             
        )                                                                       
        return info                                                             
end

function getNamelistInfo()                                                     
        local info = {}                                                         
        LuciUci:foreach("devnamelist","machine",                                  
                function(s)                                                     
                        if s ~= nil and s.mac ~= nil and s.name ~= nil then                                                
                               info[s.mac] = s.name                              
                         end                                                    
                end                                                             
        )                                                                       
        return info                                                             
end

function getBindDeviceInfo()
	local devices = {}
	
	LuciUci:foreach("dhcp","host",                                            
	        function(s)                                                       
	                if s ~= nil then                                          
                       		 table.insert( devices, { ip = s.ip,
                        			mac = s.mac,
                        			name = s.name,
                        			isbinded = "true",
                        			contype = "none"} )
	                 end
	        end
	)
	return devices
end

function strtrim(s)
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function getIgnore(lines)
    local res_devices = {}
    local t_devices = {}
    local t_words
    local t_mac
    local t_ip
    for _i, a_line in ipairs(lines) do
        -- skip title
        --if _i > 1 then
            t_words = string.rsplit(a_line,"%s")
            t_mac = t_words[4] or "none"
            t_ip = t_words[1] or "none"

            if t_devices[t_mac] == nil then
                t_devices[t_mac] = t_ip
            else
                local test_command = LuciUtil.exec("ping "..t_ip.." -w 1")
                local test_index = string.find(test_command,"ttl=")
                if test_index == nil then
                    res_devices[t_ip] = 1
                else
                    res_devices[t_devices[t_mac]] = 1
                    t_devices[t_mac] = t_ip
                end
            end
        --end
    end
    return res_devices
end

function getDevSampleCount()
    return strtrim(LuciUtil.exec("cat /proc/net/arp | grep br-lan | grep 0x2 | wc -l")) or "0"
end

function getAllDeviceInfo()
    local arp_info = LuciUtil.exec("cat /proc/net/arp | grep br-lan | grep 0x2")
    local str_lines = string.split(arp_info,"\n")

    local ip_addr, hw_type, flags, hw_addr, mask, device
    local name, connect_type, is_binded, down_rate, up_rate, is_accept, devicetype, deviceicon

    local rate_map = get_rate_map()
    local dhcp_map = dhcp_table()
    local wifi_map = getWifiInfo()
    local ignore_map = getIgnore(str_lines)
    local binded_devices = getBindInfo()
    local filter_devices = getMacFilterInfo()
	local namelist = getNamelistInfo()

    local devices = {}
    local n_device_count = 0
    local n_down_rate = 0
    local n_up_rate = 0

    for _i, a_line in ipairs(str_lines) do
        --if _i > 1 then
            local words = string.rsplit(a_line,"%s")
            if table.getn(words) < 6 then
                break
            end
            ip_addr = words[1] or nil
            hw_type = words[2] or nil
            flags = words[3] or nil
            hw_addr = words[4] or nil
            device = words[6] or nil

            if device == 'br-lan' and ignore_map[ip_addr] == nil then
                name = "none"
                connect_type = "lan"
                is_binded = "none"
                down_rate = "none"
                up_rate = "none"
                is_accept = "yes"
                down_rate = 0
                up_rate = 0
				devicetype = "unknown"
				deviceicon = "unknow.png"
				wifimode = "2.4G"

                if dhcp_map[hw_addr] ~= nil then
                    name = strtrim(dhcp_map[hw_addr])
                end
				
				if namelist[hw_addr] ~= nil then
				    name = strtrim(namelist[hw_addr])
				end
				
                if rate_map[ip_addr] ~= nil then
                    down_rate = rate_map[ip_addr]['down_rate']
                    up_rate = rate_map[ip_addr]['up_rate']
                end
                if binded_devices[hw_addr] ~= nil then                  
                    is_binded = "yes"                               
                end
                if filter_devices[hw_addr] ~= nil then                  
                    is_accept = "none"                              
                end
                if wifi_map[hw_addr] ~= nil then
                    connect_type = "wifi"
					wifimode = wifi_map[hw_addr]
                end
				
				devicetype = getDeviceTypefromMac(hw_addr,name)
				deviceicon = getDeviceIconfromMac(hw_addr,name)

                table.insert( devices, { ip = ip_addr, devicetype = devicetype, deviceicon=deviceicon,
                mac = hw_addr,
                name = name,
                isbinded = is_binded,
                contype = connect_type,
				wifimode = wifimode,
                down_rate = down_rate,
                up_rate = up_rate,
                accept = is_accept} )

                n_device_count = n_device_count + 1
                n_down_rate = n_down_rate + down_rate
                n_up_rate = n_up_rate + up_rate
            end
        --end
    end
    local binded_config_devices = getBindDeviceInfo()
    return devices, n_device_count, n_down_rate, n_up_rate, binded_config_devices
end

function getAllDeviceInfoNoRate()
    local arp_info = LuciUtil.exec("cat /proc/net/arp | grep br-lan | grep 0x2")
    local str_lines = string.split(arp_info,"\n")

    local ip_addr, hw_type, flags, hw_addr, mask, device
    local name, connect_type, is_binded, down_rate, up_rate, is_accept, devicetype, deviceicon

    --local rate_map = get_rate_map()
    local dhcp_map = dhcp_table()
    local wifi_map = getWifiInfo()
    local ignore_map = getIgnore(str_lines)
    local binded_devices = getBindInfo()
    local filter_devices = getMacFilterInfo()
	local namelist = getNamelistInfo()

    local devices = {}
    local n_device_count = 0
    local n_down_rate = 0
    local n_up_rate = 0

    for _i, a_line in ipairs(str_lines) do
        --if _i > 1 then
            local words = string.rsplit(a_line,"%s")
            if table.getn(words) < 6 then
                break
            end
            ip_addr = words[1] or nil
            hw_type = words[2] or nil
            flags = words[3] or nil
            hw_addr = words[4] or nil
            device = words[6] or nil

            if device == 'br-lan' and ignore_map[ip_addr] == nil then
                name = "none"
                connect_type = "lan"
                is_binded = "none"
                down_rate = "none"
                up_rate = "none"
                is_accept = "yes"
                down_rate = 0
                up_rate = 0
				devicetype = "unknown"
				deviceicon = "unknow.png"
				wifimode = "2.4G"

                if dhcp_map[hw_addr] ~= nil then
                    name = strtrim(dhcp_map[hw_addr])
                end
				
				if namelist[hw_addr] ~= nil then
				    name = strtrim(namelist[hw_addr])
				end
				
                if binded_devices[hw_addr] ~= nil then                  
                    is_binded = "yes"                               
                end
                if filter_devices[hw_addr] ~= nil then                  
                    is_accept = "none"                              
                end
                if wifi_map[hw_addr] ~= nil then
                    connect_type = "wifi"
					wifimode = wifi_map[hw_addr]
                end
				
				devicetype = getDeviceTypefromMac(hw_addr,name)
				deviceicon = getDeviceIconfromMac(hw_addr,name)

                table.insert( devices, { ip = ip_addr, devicetype = devicetype, deviceicon=deviceicon,
                mac = hw_addr,
                name = name,
                isbinded = is_binded,
                contype = connect_type,
				wifimode = wifimode,
                down_rate = down_rate,
                up_rate = up_rate,
                accept = is_accept} )

                n_device_count = n_device_count + 1
            end
        --end
    end
    local binded_config_devices = getBindDeviceInfo()
    return devices, n_device_count, n_down_rate, n_up_rate, binded_config_devices
end

function getIPListfromDevlist()
    local devices = getAllDeviceInfoNoRate()
	local iplist={}
	for _i, item in ipairs(devices) do
          iplist[item.ip] = "1"
	end
    return iplist
end

function getDeviceTypefromMac(mac,name)
  if not isStrNil(name) and string.len(name) > 7 and string.sub(name,1,7) == "android" then
      return "android"
  end
  
  local ret = "unknown"
  local NixioFs = require("nixio.fs")
  if NixioFs.access(Configs.MACTABLE_FILEPATH) then
    local key = string.upper(string.sub(string.gsub(mac,":","-"),1,8))
    local line = LuciUtil.trim(LuciUtil.exec("sed -n '/"..key.."/p' "..Configs.MACTABLE_FILEPATH))
	if not isStrNil(line) then
	  local apple = line:match("(%S+) Apple")
	  if apple then
	      ret = "iphone"
	  else
	      ret = "PC"
	  end
	end
  end
  if ret == "unknown" or ret == "PC" then
	  local s1,e1 = name:find("PC")
	  if s1 then
	      ret = "PC"
	  end
	  
	  s1,e1 = name:find("notebook")
	  if s1 then
	      ret = "PC"
	  end
      
	  s1,e1 = name:find("iphone")
	  if s1 then
	      ret = "iphone"
	  end
  end
  return ret
end

function getDeviceIconfromMac(mac,name) 
  local ret = "unknow.png"
  local NixioFs = require("nixio.fs")
  if NixioFs.access("/etc/youku/mactabletobrand") then
    local key = string.upper(string.sub(string.gsub(mac,":","-"),1,8))
    local line = LuciUtil.trim(LuciUtil.exec("sed -n '/"..key.."/p' /etc/youku/mactabletobrand"))
	if not isStrNil(line) then
	  ret = line:match("ICON:(%S+)") or "unknow.png"
	end
  end
  if ret == "unknow.png" then
	  local s1,e1 = name:find("PC")
	  if s1 then
	      ret = "PC.png"
	  end
	  
	  s1,e1 = name:find("notebook")
	  if s1 then
	      ret = "PC.png"
	  end
  end
  
  --this
  if luci.http.context.request then
	  local remotemac = getRemoteMac();
	  if string.upper(remotemac) == string.upper(mac) then
		  ret = "this.png"
	  end
  end
  return ret
end

function _pppoeStatusCheck()
	local cmd = "lua /usr/sbin/pppoe.lua status"
	local status = LuciUtil.exec(cmd)
	if status then
		status = LuciUtil.trim(status)
		if string.len(status) == 0 then
			return false
		end
		status = LuciJson.decode(status)
		
		if status.process == "connecting" and status.code ~= nil and  status.code ~= 0 then
		    local code = LuciUtil.exec("curl -s -o /dev/null -I http://www.baidu.com -w '%{http_code}' --connect-timeout 1")
			if code == "200" then
				status.process = "up"
				status.code = nil
			end
		end
		return status
	else
		return false
	end
end

function webArrived()
	local to_web = 0
	local proto = LuciUci:get("network","wan","proto")
	
	if proto == "pppoe" then
		local check = _pppoeStatusCheck()
		if check and type(check)=="table" and check.process == "up" then
				to_web = 1
		end
	else
		local code = LuciUtil.exec("curl -s -o /dev/null -I http://www.baidu.com -w '%{http_code}' --connect-timeout 1")
		if code == "200" then
		    to_web = 1
		end
	end
	
	return to_web
end

function getDeviceCount()
    local arp_info = LuciUtil.exec("cat /proc/net/arp | grep br-lan | grep 0x2")
    local str_lines = string.split(arp_info,"\n")

    local ignore_map = getIgnore(str_lines)
    local n_device_count = 0
    for _i, a_line in ipairs(str_lines) do
        local words = string.rsplit(a_line,"%s")
        if table.getn(words) < 6 then
            break
        end
        ip_addr = words[1] or nil
        device = words[6] or nil

        if device == 'br-lan' and ignore_map[ip_addr] == nil then
            n_device_count = n_device_count + 1
        end
    end

    return n_device_count
end

function getOldOnline()
	local up = 0
	local proto = LuciUci:get("network","wan","proto")
	
    if proto == "pppoe" then
        local check = _pppoeStatusCheck()
        if check and type(check)=="table" and check.process == "up" then
            up = 1
        end
    elseif proto == "dhcp" or proto == "static" then
        up = webArrived()
    end

    return up
end

function getOldDeviceSumInfo()
    local down_up_rate = LuciUtil.exec("dev_speed")
	local downrate,uprate = "0","0"
	if not isStrNil(down_up_rate) then
      local rate = string.split(down_up_rate," ")
	  downrate = rate[1] or "0"
	  uprate = rate[2] or "0"
	end

    local to_web = getOldOnline()
    local n_device_count = getDeviceCount()

    return n_device_count, downrate, uprate, to_web, "0", "0"
end

--wanstate 0: 未插网线   1: offline  2:dhcp  3:pppoe  4: unknown
function getwanstate()
    local info = LuciUtil.exec("tail -n 5 " .. Configs.NETMON_LOG_FILE)
    local lines = string.split(info,"\n")

    local online, wanstate = "-1", nil
    for i, line in ipairs(lines) do
        local words = string.split(line, " ")
		local words_n = table.getn(words)
        if words_n >= 10 then
            online = words[2]
            wanstate = words[10]
		elseif words_n > 2 then
		    online = words[2]
        end
    end
	
	local ret="0"
	if wanstate ~= nil then
	    if wanstate == "0" then
		    return "0" 
		end
	end
	
	if online == "0" then online = 1 else online = 0 end
	if online == 0 then online = getOldOnline() end
	if online == 0 then
		ret="1"
	else
	    local proto = LuciUci:get("network","wan","proto")
		if proto == "pppoe" then
		    ret="3"
		elseif proto=="dhcp" then
		    ret="2"
		else
		    ret="4"
		end
	end
    return ret
end

function getDeviceSumInfo()
    local info = LuciUtil.exec("tail -n 10 " .. Configs.NETMON_LOG_FILE)
    local lines = string.split(info,"\n")

    if table.getn(lines) < 10 then
        return getOldDeviceSumInfo()
    end

    local dev_cnt, online = 0,0
	local rate_up, rate_dwn = "0", "0" 
	local valid = 0 
	local acc_rate_up, acc_rate_down = "0", "0"
	local wanstate = nil
    for i, line in ipairs(lines) do
        local words = string.split(line, " ")
        if table.getn(words) >= 9 then
            online = words[2]
            dev_cnt = words[3]
            rate_up = words[4]
            rate_dwn = words[5]
			if table.getn(words) >=10 then
			    wanstate = words[10]
			end
            valid = valid + 1
        end
		
		if table.getn(words) >= 16  then
		    acc_rate_up = words[15]
			acc_rate_down = words[16]
		end
    end

    if valid == 0 then
        return getOldDeviceSumInfo()
    end
	
	if tonumber(acc_rate_down) > tonumber(rate_dwn) then
	    acc_rate_down = rate_dwn
	end
	
	if tonumber(acc_rate_up) > tonumber(rate_up) then
	    acc_rate_up = rate_up
	end

    -- compatible to the format
	if wanstate ~= nil and wanstate == "0" then
	    online = 0
	else
	    if online == "0" then online = 1 else online = 0 end
		if online == 0 then online = getOldOnline() end
	end
    dev_cnt = getDeviceCount()
    return dev_cnt, rate_dwn, rate_up, online, acc_rate_down, acc_rate_up
end

function action_status()
	luci.http.write("finish")
end

function actionstatusforIF()
	return "finish"
end

function ubusWanStatus()
	local ubus = require("ubus").connect()
	local wan = ubus:call("network.interface.wan", "status", {})
	local result = {}
	if wan["ipv4-address"] and #wan["ipv4-address"] > 0 then
		result["ipv4"] = wan["ipv4-address"][1]
	else
		result["ipv4"] = {
			["mask"] = 0,
			["address"] = ""
		}
	end
	result["dns"] = wan["dns-server"] or {}
	result["proto"] = string.lower(wan.proto or "dhcp")
	result["up"] = wan.up
	result["uptime"] = wan.uptime or 0
	result["pending"] = wan.pending
	result["autostart"] = wan.autostart
	return result
end

function _pppoeErrorCodeHelper(code)
	local errorA = {
		["507"] = 1, ["691"] = 1, ["509"] = 1, ["514"] = 1, ["520"] = 1,
		["646"] = 1, ["647"] = 1, ["648"] = 1, ["649"] = 1, ["691"] = 1,
	}
	local errorB = {
		["516"] = 1, ["650"] = 1, ["601"] = 1, ["510"] = 1, ["530"] = 1,
		["531"] = 1
	}
	local errorC = {
		["501"] = 1, ["502"] = 1, ["503"] = 1, ["504"] = 1, ["505"] = 1,
		["506"] = 1, ["507"] = 1, ["508"] = 1, ["511"] = 1, ["512"] = 1,
		["515"] = 1, ["517"] = 1, ["518"] = 1, ["519"] = 1
	}
	local errcode = tostring(code)
	if errcode then
		if errorA[errcode] then
			return "用户名或密码错误!"
		end
		if errorB[errcode] then
			return "连接不到服务器，请检查网络!"
		end
		if errorC[errcode] then
			return "协议未知错误!"
		end
		return 1
	end
end

function getPPPoEStatus()
	local result = {}
	local status = ubusWanStatus()
	if status then
		local LuciNetwork = require("luci.model.network").init()
		local network = LuciNetwork:get_network("wan")
		if status.proto == "pppoe" then
			if status.up then
				result["status"] = 2
			else
				local check = _pppoeStatusCheck()
				if check then
					if check.process == "down" then
						result["status"] = 4
					elseif check.process == "up" then
						result["status"] = 2
					elseif check.process == "connecting" then
						if check.code == nil or check.code == 0 then
							result["status"] = 1
						else
							result["status"] = 3
							result["errcode"] = check.msg or "601"
							result["errmsg"] = _pppoeErrorCodeHelper(tostring(check.code))
						end
					end
				else
					result["status"] = 4
				end
			end
		else
			result["status"] = 0
		end
	end
	return result
end

function setrouterinit(status)
    setUConfig("init", status, "account")
    return "0"
end

function getrouterinit()
    return getUConfig("init", "", "account")
end

function setuserAccount(account)
    setUConfig("useraccount", account, "account")
    return "0"
end

function getuserAccount()
    return getUConfig("useraccount", "", "account")
end

function getLEDMode()
   return getUConfig("lightmode", "0", "account"), getUConfig("lighttime", "22:00-08:00", "account")
end

function getAdvanceSwitch()
    return getUConfig("advanceswitch", "0", "account")
end

function setAdvanceSwitch(advanceswitch)
    setUConfig("advanceswitch", advanceswitch, "account")
    return "0"
end

function setLEDMode(mode,modetime)
    local lmode = mode or "0"
    if lmode ~= "0" and lmode ~= "1" and lmode ~= "2"then
        lmode = "0"
    end
    setUConfig("lightmode", lmode, "account")
	
	if modetime ~= nil and modetime ~= "" then
	   if string.len(modetime) ~= 11 then
	       local hourfrom,minfrom,hourto,minto = modetime:match("^(%S+):(%S+)-(%S+):(%S+)")
		   modetime = string.format("%02d:%02d-%02d:%02d",tonumber(hourfrom),tonumber(minfrom),tonumber(hourto),tonumber(minto))
	   end
	   setUConfig("lighttime", modetime, "account")
	end
    return true
end

function checkdhcpip(ip,mac)
    if isStrNil(ip) or string.len(ip) < 10 then
	    return false
	end
	
	local gatewanip = LuciUci:get("network","lan","ipaddr")
	if string.sub(ip,1,10) ~= string.sub(gatewanip,1,10) then
	    return false
	end
	
	if ip == gatewanip then
	    return false
	end
	
	local binddevices = getBindDeviceInfo()
	local ipexist = false;
	if table.getn(binddevices) > 0 then
		for _i, curdev in ipairs(binddevices) do
			if ip == curdev.ip then
			    ipexist = true;
			end
		end
	end
	
	if ipexist then
	    return false 
	end

    local dhcpinfo = checkdhcplease()
	if dhcpinfo[ip] and string.lower(dhcpinfo[ip].mac) ~= string.lower(mac) then 
	    return false
    else
	    return true
	end
end

function checkdhcplease()
    local dhcp_info = LuciUtil.exec("cat /var/dhcp.leases")
	local mac_name_map = {}
	local dhcp_info_lines = string.split(dhcp_info)
	for _, a_dhcp_line in ipairs(dhcp_info_lines) do
		if a_dhcp_line then
		    local ts,mac,ip,name = a_dhcp_line:match("^(%d+) (%S+) (%S+) (%S+)")
			if name=="*" then
			    name = mac
			end
			if ts and mac and ip and name then
			    mac_name_map[ip]={mac=mac,ip=ip,name=name}
			end
		end
	end
	return mac_name_map
end

function readUpgrade()
    local updatedata = LuciUtil.exec("cat /etc/ku_updater.conf ")
    local result = {hasupdate="0",version=nil}
    
    result["hasupdate"] = "0" 
    if updatedata ~= nil then  
        local updateinfo = LuciJson.decode(updatedata)     
        if updateinfo ~= nil and type(updateinfo) == "table" and updateinfo.data ~= nil and updateinfo.data.firmware ~= nil 
		    and updateinfo.data.firmware.level ~= "force" then
            result["hasupdate"] = "1" 
            result["version"] = string.gsub(updateinfo.data.firmware.version,"\"","")
        end
    end
	return result
end

function getupgradestatus()
    local data = LuciUtil.exec(Configs.GET_DOWNLOADFILE_STATUS)
    
    if data == nil or data == "" then
         return "1" 
    end
	  
	  if string.match(data, "update status error") ~= nil then
		   return "-1" 
	  end
	  
	  if string.match(data, "failed") ~= nil then
		   return "-2" 
	  end
	  
	  local persent = nil
	  for k, v in string.gmatch(data, "update status progress : (%S+)-(%S+)") do
         persent = tonumber(k) / tonumber(v) * 100
	  end
      
    if persent == nil or persent <= 1 then
        return "1"
    end
    
    persent = math.floor(persent)
  
    if persent >= 100 then
	      return "100"
    else
        return tostring(persent)
    end
end

function getAvailableDisk(cmd)
    local disk = LuciUtil.exec(cmd)
    if disk and tonumber(LuciUtil.trim(disk)) then
        return tonumber(LuciUtil.trim(disk))
    else
        return false
    end
end

function checkTmpDiskSpace(byte)
    local disk = getAvailableDisk(Configs.CHECK_TMPDISK)
    if disk then
        if disk - byte/1024 > 10240 then
            return true
        end
    end
    return false
end

function checkDiskSpace(byte)
    local disk = getAvailableDisk(Configs.CHECK_DISK)
    if disk then
        if disk - byte/1024 > 10240 then
            return true
        end
    end
    return false
end

function changeRouterDomain(ip)
    if isStrNil(ip) then
	    return false
	end
    local command = string.gsub(Configs.CHANGE_DOMAIN_IP, "$s", ip)
    LuciOS.execute(command)
	changeurlfiltergateway()
	return true
end

function getFooterInfo()
    local wifisetting = require("luci.youkucloud.wifiSetting")
    local result = {}
    result["sysversion"] = getyoukuvertion()
    result["wanIP"], result["MacAddr"] = wifisetting.getWanIPMac()
    result["routerQQ"] = Configs.ROUTER_QQ
    result["routerWX"] = Configs.ROUTER_WX
    result["routerHotline"] = Configs.ROUTER_HOTLINE
	
    return result
end

function isExistNetworkPublic()
    local public = LuciUci:get("network","public","ifname") or ""
	if isStrNil(public) then
	    return false
	else
	    return true
	end
end

function checkUpdatetime()
    local oldtime = getUConfig("updatetime", "", "account")
	if isStrNil(oldtime) then
	    return "true"
	end
    local curtime = LuciUtil.exec("date +%Y%m%d")
	
	if tonumber(curtime) > tonumber(oldtime) then
	    return "true"
	end
    return "false"
end

function setUpdatetime()
    local curtime = LuciUtil.exec("date +%Y%m%d")
    setUConfig("updatetime", curtime, "account")
end

function dirlistscheck()
    local dirlists = LuciUci:get("uhttpd", "main", "no_dirlists") or ""
	if dirlists ~= "1" then
	    LuciUci:set("uhttpd", "main", "no_dirlists", "1")
        LuciUci:save("uhttpd")
		LuciUci:commit("uhttpd")
		LuciUtil.exec("/etc/init.d/uhttpd restart &")
	end
end

function getRemoteMac()
	local remote_addr = LuciHttp.getenv("REMOTE_ADDR")
	local remote_mac = "00:00:00:00:00:00"
	if not isStrNil(remote_addr) then
	    remote_mac = luci.sys.net.ip4mac(remote_addr) or "00:00:00:00:00:00"
	    remote_mac = string.lower(remote_mac) 
	end
	return remote_mac
end

function checkRemoteIP()
	local remote_addr = LuciHttp.getenv("REMOTE_ADDR")
    local remoteexp = LuciUtil.split(remote_addr,".")[3] or "-1"
	if remoteexp == "215" or remoteexp == "-1" then
	    return false
	end
	return true
end

function getRouterInitMac()
    local initmac = LuciUtil.exec("eth_mac r wan")
	if initmac and string.len(initmac) > 16 then
	    initmac = string.sub(initmac,1,17)
	end
    return  initmac or "00:00:00:00:00:00"
end

function sleep(n)
    local t0 = os.clock()
    while os.clock() - t0 <= n do end
end

function checkconenv()
    local status = getwanstate()
	local proto = LuciUci:get("network","wan","proto")
    if status=="1" then
		if proto ~= "dhcp" then
	        local data = LuciUtil.exec("udhcpc -n -q -s /bin/true -t 1 -T 1 -i eth0.2")
			if data and string.match(data,"obtained") ~= nil then
			    proto = "dhcp"
			end
		end
		
		if proto ~= "pppoe" then
		   --check pppoe
		   local data = LuciUtil.exec("pppoe -I eth0.2 -t 1 -A x")
		   if data and string.match(data,"Concentrator") ~= nil then
		       proto = "pppoe"
		   end
		end
	end
	return proto
end

function tryconnect()
    local status = getwanstate()
	if status=="1" then
        local proto = LuciUci:get("network","wan","proto")
		if proto ~= "dhcp" then
		    --check dhcp 
            local data = LuciUtil.exec("udhcpc -n -q -s /bin/true -t 1 -T 1 -i eth0.2")
			if data and string.match(data,"obtained") ~= nil then
			    LuciUci:set("network","wan","proto","dhcp")
				LuciUci:save("network")
				LuciUci:commit("network")
                LuciOS.execute("/etc/init.d/network restart")
				LuciOS.execute("/etc/init.d/dnsmasq restart &")
				sleep(5)
				if getwanstate()~="2" then
                    LuciUci:set("network","wan","proto",proto)
					LuciUci:save("network")
				end
				LuciUci:commit("network")
				return
			end
		end
		
		if proto ~= "pppoe" then
		   --check pppoe
		   local data = LuciUtil.exec("pppoe -I eth0.2 -t 1 -A x")
		   if data and string.match(data,"Concentrator") ~= nil then
			    local username = LuciUci:get("network","wan","username")
				local password = LuciUci:get("network","wan","password")
				if not isStrNil(username) and not isStrNil(password) then
				    LuciUci:set("network","wan","proto","pppoe")
					LuciUci:save("network")
					LuciUci:commit("network")
					LuciOS.execute("rm -rf "..getpppoelogpath())
                    LuciOS.execute("ifup wan")
				    LuciOS.execute("/etc/init.d/dnsmasq restart &")
					sleep(5)
				    if getwanstate()~="3" then
						LuciUci:set("network","wan","proto",proto)
						LuciUci:save("network")
					end
					LuciUci:commit("network")
				end
		   end
		end
	end
end

function getdetectinfo()
    local detectinfo={tfreadwrite="false",tflogupload="false",accralaycheck="false",accgethot="false",accgethotcode="65535",accdownload="false"}
	local data = LuciUtil.exec("sh /usr/sbin/diag_generator.sh 2>/dev/null")
	if data then
	    detectinfo.tfreadwrite = data:match('tf_check:(%S+)') or "false"
	    detectinfo.tflogupload = data:match('log_check:(%S+)') or "false"
		detectinfo.accralaycheck = data:match('join_check:(%S+)') or "false"
		detectinfo.accgethot = data:match('bid_check:(%S+)') or "false"
		detectinfo.accgethotcode = data:match('bid_code:(%S+)') or "65535"
		detectinfo.accdownload = data:match('download_check:(%S+)') or "false"
	end
    return detectinfo
end

function accmodefromconfig(accmode)
    if accmode and tonumber(accmode) >= 4 then
        return "3"
    elseif accmode and tonumber(accmode) >= 2 then
        return "2"
    else
        return "1"
    end
end

function accmodetoconfig(accmode)
    if accmode and tonumber(accmode) == 1 then
        return "1"
    elseif accmode and tonumber(accmode)== 2 then
        return "2"
    else
        return "4"
    end
end

function getacctimemode()
    local acctimingenable = getUConfig("acctimingenable", nil, "account")
	if acctimingenable and acctimingenable=="true" then
	    local accfullmode = accmodefromconfig(getUConfig("accfullmode", "4", "account"))
		local acctimemode = accmodefromconfig(getUConfig("acctimemode", "1", "account"))
		local acctime = getUConfig("acctime", "22:00-08:00", "account")
	    return acctimingenable,accfullmode,acctimemode,acctime
	else
	    return nil,nil,nil,nil
	end
end

function setacctimemode(acctimingenable,accfullmode,acctimemode,acctime)
    if acctimingenable and (acctimingenable=="true" or acctimingenable==true) then
	    local fullmode = accmodetoconfig(accfullmode)
		local timemode = accmodetoconfig(acctimemode)
		
		if fullmode == timemode then
		    return false
		end
	    setUConfig("acctimingenable", "true", "account")
	    setUConfig("accfullmode", fullmode, "account")
	    setUConfig("acctimemode", timemode, "account")
	    if acctime ~= nil and acctime ~= "" then
		    if string.len(acctime) ~= 11 then
			   local hourfrom,minfrom,hourto,minto = acctime:match("^(%S+):(%S+)-(%S+):(%S+)")
			   acctime = string.format("%02d:%02d-%02d:%02d",tonumber(hourfrom),tonumber(minfrom),tonumber(hourto),tonumber(minto))
		    end
		    setUConfig("acctime", acctime, "account")
	    else
		    setUConfig("acctime", "22:00-08:00", "account")
	    end
	    return true
	else
	   setUConfig("acctimingenable", "", "account")
	   setUConfig("accfullmode", "", "account")
	   setUConfig("acctimemode", "", "account")
	   setUConfig("acctime", "", "account")
	   return true
    end
end

function txpmodefromconfig(txpmode)
    if txpmode and tonumber(txpmode) >= 0 and tonumber(txpmode) <= 60 then
        return "0"
    elseif txpmode and tonumber(txpmode) > 60 and tonumber(txpmode) <= 90 then
        return "1"
    else
        return "2"
    end
end

function txpmodetoconfig(txpmode)
    if txpmode and tonumber(txpmode) == 0 then
        return Configs.TXPOWER_GREEN
    elseif txpmode and tonumber(txpmode)== 1 then
        return Configs.TXPOWER_BASE
    else
        return Configs.TXPOWER_STRONG
    end
end

function gettxptimemode()
    local txptimingenable = getUConfig("txptimingenable", nil, "account")
	if txptimingenable and txptimingenable=="true" then
	    local txpfullmode = txpmodefromconfig(getUConfig("txpfullmode", "100", "account"))
		local txptimemode = txpmodefromconfig(getUConfig("txptimemode", "0", "account"))
		local txptime = getUConfig("txptime", "22:00-08:00", "account")
	    return txptimingenable,txpfullmode,txptimemode,txptime
	else
	    return nil,nil,nil,nil
	end
end

function gettxptimemode_5G()
    local txptimingenable = getUConfig("txptimingenable_5G", nil, "account")
	if txptimingenable and txptimingenable=="true" then
	    local txpfullmode = txpmodefromconfig(getUConfig("txpfullmode_5G", "100", "account"))
		local txptimemode = txpmodefromconfig(getUConfig("txptimemode_5G", "0", "account"))
		local txptime = getUConfig("txptime_5G", "22:00-08:00", "account")
	    return txptimingenable,txpfullmode,txptimemode,txptime
	else
	    return nil,nil,nil,nil
	end
end

function settxptimemode(txptimingenable,txpfullmode,txptimemode,txptime)
    if txptimingenable and (txptimingenable=="true" or txptimingenable==true) then
	    local fullmode = txpmodetoconfig(txpfullmode)
		local timemode = txpmodetoconfig(txptimemode)
		
		if fullmode == timemode then
		    return false
		end
	    setUConfig("txptimingenable", "true", "account")
	    setUConfig("txpfullmode", fullmode, "account")
	    setUConfig("txptimemode", timemode, "account")
	    if txptime ~= nil and txptime ~= "" then
		    if string.len(txptime) ~= 11 then
			   local hourfrom,minfrom,hourto,minto = txptime:match("^(%S+):(%S+)-(%S+):(%S+)")
			   txptime = string.format("%02d:%02d-%02d:%02d",tonumber(hourfrom),tonumber(minfrom),tonumber(hourto),tonumber(minto))
		    end
		    setUConfig("txptime", txptime, "account")
	    else
		    setUConfig("txptime", "22:00-08:00", "account")
	    end
		LuciUtil.exec(Configs.TXP_CHECK_CONF)
	    return true
	else
	   setUConfig("txptimingenable", "", "account")
	   setUConfig("txpfullmode", "", "account")
	   setUConfig("txptimemode", "", "account")
	   setUConfig("txptime", "", "account")
	   LuciUtil.exec(Configs.TXP_CHECK_CONF)
	   return true
    end
end

function settxptimemode_5G(txptimingenable,txpfullmode,txptimemode,txptime)
    if txptimingenable and (txptimingenable=="true" or txptimingenable==true) then
	    local fullmode = txpmodetoconfig(txpfullmode)
		local timemode = txpmodetoconfig(txptimemode)
		
		if fullmode == timemode then
		    return false
		end
	    setUConfig("txptimingenable_5G", "true", "account")
	    setUConfig("txpfullmode_5G", fullmode, "account")
	    setUConfig("txptimemode_5G", timemode, "account")
	    if txptime ~= nil and txptime ~= "" then
		    if string.len(txptime) ~= 11 then
			   local hourfrom,minfrom,hourto,minto = txptime:match("^(%S+):(%S+)-(%S+):(%S+)")
			   txptime = string.format("%02d:%02d-%02d:%02d",tonumber(hourfrom),tonumber(minfrom),tonumber(hourto),tonumber(minto))
		    end
		    setUConfig("txptime_5G", txptime, "account")
	    else
		    setUConfig("txptime_5G", "22:00-08:00", "account")
	    end
		LuciUtil.exec(Configs.TXP_CHECK_CONF)
	    return true
	else
	   setUConfig("txptimingenable_5G", "", "account")
	   setUConfig("txpfullmode_5G", "", "account")
	   setUConfig("txptimemode_5G", "", "account")
	   setUConfig("txptime_5G", "", "account")
	   LuciUtil.exec(Configs.TXP_CHECK_CONF)
	   return true
    end
end

function getblackwhitemode()
    return getUConfig("blackwhitemode", "0", "account")
end

function getblackwhiteInfo()
    local blackinfo = {}                                                         
	LuciUci:foreach("wifiblacklist","machine",                                  
		function(s)                                                     
			if s ~= nil and s.mac ~= nil and s.name ~= nil then
				  table.insert(blackinfo, {mac = s.mac, name = s.name})
			end                                                    
		end                                                             
	)
    
    local whiteinfo = {}                                                         
	LuciUci:foreach("wifiwhitelist","machine",                                  
		function(s)                                                     
			if s ~= nil and s.mac ~= nil and s.name ~= nil then
				  table.insert(whiteinfo, {mac = s.mac, name = s.name})
			end                                                    
		end                                                             
	)    	
	return blackinfo, whiteinfo
end

function setblackwhitedisable()
    setUConfig("blackwhitemode", "0", "account")
	LuciUtil.exec(Configs.SET_ACLPOLICY_RA0.."0")
	LuciUtil.exec(Configs.SET_ACLPOLICY_RA1.."0")
	LuciUtil.exec(Configs.CLEAR_ACL_MACLIST_RA0)
	LuciUtil.exec(Configs.CLEAR_ACL_MACLIST_RA1)
	
	local wifiSetting = require("luci.youkucloud.wifiSetting")
	if wifiSetting.wifi_5G_exist() then
	    LuciUtil.exec(Configs.SET_ACLPOLICY_RAI0.."0")
		LuciUtil.exec(Configs.CLEAR_ACL_MACLIST_RAI0)
	end
end

function checkcurrentdevwifi()
    if luci.http.context.request then
		remotemac = getRemoteMac()
		local wifi_map = getWifiInfo()
		if wifi_map[remotemac] ~= nil then
			return remotemac
		end
	end
	return nil
end

function savebwlistfile(list,filename)
    LuciUtil.exec("rm -rf /etc/config/"..filename)
    LuciUtil.exec("touch /etc/config/"..filename)
    
	if list~=nil and type(list) == "table" and table.getn(list) >= 1 then
        local config_name = ""
		for _i, item in ipairs(list) do
			config_name = string.lower(string.gsub(item.mac,"[:-]",""))
			LuciUci:section(filename, "machine", config_name, item)
		end
		LuciUci:commit(filename)
		LuciUci:save(filename)
    end
end

function checkcurmacinlist(list,curmac)
    local foundinlist = false
	local maclist = ""
	if list~=nil and type(list) == "table" and table.getn(list) >= 1 then
		for _i, item in ipairs(list) do
			if curmac and string.lower(item.mac) == string.lower(curmac) then
				foundinlist = true
			end
			maclist = maclist..string.lower(item.mac)..";"
		end
		maclist = string.sub(maclist,1,string.len(maclist)-1)
		maclist = "'"..maclist.."'"
	end
    return foundinlist,maclist
end

function setACLmaclist(maclist,mode)
    setUConfig("blackwhitemode", mode, "account")
	LuciUtil.exec(Configs.SET_ACLPOLICY_RA0.."0")
	LuciUtil.exec(Configs.SET_ACLPOLICY_RA1.."0")
	LuciUtil.exec(Configs.CLEAR_ACL_MACLIST_RA0)
	LuciUtil.exec(Configs.CLEAR_ACL_MACLIST_RA1)
	if maclist ~= "" then
		LuciUtil.exec(Configs.ADD_ACL_MACLIST_RA0..maclist)
		LuciUtil.exec(Configs.ADD_ACL_MACLIST_RA1..maclist)
	end
	LuciUtil.exec(Configs.SET_ACLPOLICY_RA0..mode)
	LuciUtil.exec(Configs.SET_ACLPOLICY_RA1..mode)
	
	local wifiSetting = require("luci.youkucloud.wifiSetting")
	if wifiSetting.wifi_5G_exist() then
	    LuciUtil.exec(Configs.SET_ACLPOLICY_RAI0.."0")
		LuciUtil.exec(Configs.CLEAR_ACL_MACLIST_RAI0)
		if maclist ~= "" then
			LuciUtil.exec(Configs.ADD_ACL_MACLIST_RAI0..maclist)
		end
		LuciUtil.exec(Configs.SET_ACLPOLICY_RAI0..mode)
	end

end

function setblackwhitetable(mode,blist,wlist)

    if  (blist ~= nil and type(blist) == "table" and table.getn(blist) > 64) 
	   or (wlist ~= nil and type(wlist) == "table" and table.getn(wlist) > 64) then
		return "10043"
	end
	
    if mode == "0" then
	    setblackwhitedisable()
	else
	    local curmac = checkcurrentdevwifi()
		local foundinlist = false
		local maclist = ""
		if mode=="1" then
		   if wlist == nil then
		       return "10040"
		   end
		   foundinlist,maclist = checkcurmacinlist(wlist,curmac)
		   if curmac and (not foundinlist) then
		       return "10041"
		   end	   
		elseif  mode=="2" then
		   if blist == nil then
		       return "10040"
		   end
		   foundinlist,maclist = checkcurmacinlist(blist,curmac)
		   if curmac and foundinlist then
		       return "10042"
		   end		
		end
		setACLmaclist(maclist,mode)
	end
	
	if blist ~= nil then
	    savebwlistfile(blist,"wifiblacklist")
	end
	
	if wlist ~= nil then
	    savebwlistfile(wlist,"wifiwhitelist")
	end
	return "0"
end

function getredirectinfo()
    local modetype = "0"
	local list = {}
	local dmzip = nil
	local rdropenflag = false
	local dmzopenflag = false
    LuciUci:foreach("firewall", "redirect",
        function(s)
            if s.name == "dmz" then
			    dmzip = s.dest_ip
				if s.enabled == "1" then 
				    dmzopenflag = true 
				end
			else
			    if s.enabled == "1" then 
				    rdropenflag = true 
				end
			    local item = {}
                item.name = s.name
                item.dest_ip = s.dest_ip
			    item.src_dport = s.src_dport
                item.dest_port = s.dest_port
				item.proto = s.proto
				table.insert(list, item)
			end 
        end
    )
	
	if dmzopenflag then
	    modetype = "2"
	elseif rdropenflag then
	    modetype = "1"
	end
    return modetype,list,dmzip
end

function deldmzconfig()
    LuciUci:delete("firewall", "dmz")
    LuciUci:commit("firewall")
end

function setdmzconfig(dmzip,flag)
    local options = {["enabled"] = "1",["src"] = "wan",["proto"] = "all",["target"] = "DNAT",["dest"] = "lan",["dest_ip"] = "",["name"] = "dmz"}
	options.dest_ip=dmzip
	if not flag then
	    options.enabled = "0"
	end
    LuciUci:section("firewall", "redirect", "dmz", options)
    LuciUci:commit("firewall")
end

function delrdrconfig()
     LuciUci:delete_all("firewall", "redirect",
        function(s)
            if s.name == "dmz" then
                return false
            else
                return true
            end
        end
    )
    LuciUci:commit("firewall")
end

function checkrdrport(port)
    if port and tonumber(port) > 0 and tonumber(port) <= 65535 then
	    return "0"
	end
	return "10052"
end

function checkportConflict(list)
    local portlist = {}
	local ret = "0"
	for _i, item in ipairs(list) do
	    if tonumber(item.src_dport) == 8908 or tonumber(item.src_dport) == 8909 or tonumber(item.src_dport) == 4466 then
		    ret = "10050"
		end
		
	    if portlist[item.src_dport] ~= nil then
		    ret = "10051"
		else
		    portlist[item.src_dport] = "1"
		end  
	end
	return ret
end

function setrdrconfig(list,flag)
    for _i, item in ipairs(list) do
		local options = {["enabled"] = "1",["src"] = "wan",["target"] = "DNAT",["dest"] = "lan",["proto"] = "tcp",["dest_ip"] = "",["src_dport"] = "",["dest_port"] = "",["name"] = ""}
		if not flag then
			options.enabled = "0"
		end
		options.name = item.name or ""
		options.dest_ip = item.dest_ip
		options.src_dport = item.src_dport
		options.dest_port = item.dest_port
		options.proto = item.proto or "tcp"
		
		local rdrname = string.format("redirect%sport", tostring(options.src_dport))
		LuciUci:section("firewall", "redirect", rdrname, options)
	end
    LuciUci:commit("firewall")
end

function setredirectinfo(modetype,list,dmzip)
    local ret = "0"
    if modetype == "1" then
	    ret = checkportConflict(list)
		if ret ~= "0" then 
		    return ret 
		end
	end
    local oldmodetype,oldlist,olddmzip = getredirectinfo()
    if modetype ~= oldmodetype then
	    deldmzconfig()
	    delrdrconfig()
		if modetype == "0" then
			setdmzconfig(olddmzip,false)
			setrdrconfig(oldlist,false)
		elseif modetype == "1" then
		    setrdrconfig(list,true)
			setdmzconfig(olddmzip,false)
		elseif modetype == "2" then
		    setrdrconfig(oldlist,false)
			setdmzconfig(dmzip,true)
		end
	else 
	    if modetype == "1" then
		    delrdrconfig()
		    setrdrconfig(list,true)
		elseif modetype == "2" then
		    deldmzconfig()
			setdmzconfig(dmzip,true)
		end
	end
	LuciOS.execute("nohup /etc/init.d/firewall restart >/dev/null 2>/dev/null & ")
	return "0"
end

function getcreditmode()
    return getUConfig("creditmode", "normal", "account")
end

function setcreditmode(mode)
    if mode ~= "fixed" and mode ~= "normal" then
	    mode = "normal"
	end
	if mode == "fixed" then
		setUConfig("accmode", "3", "account")
		setacctimemode(false)
	else
	    setUConfig("accmode", "2", "account")
	end
    return setUConfig("creditmode", mode, "account")
end

function accmodefromoldtonew(accmode)
    if accmode and accmode == "0" then
        return "4"
    elseif accmode and accmode == "2" then
        return "2"
    elseif accmode and accmode == "3" then
        return "1"
	else
	    return accmode
    end
end

function synchroConfig()
    local curconfver = getUConfig("accountversion", "1", "account")
	return curconfver
end

function getUPnPStatus()
    if tonumber(LuciUci:get("upnpd","config","enable_upnp")) == 1 then
        return true
    else
        return false
    end
end

function getUPnPList()
    if getUPnPStatus() then
        local upnpLease = LuciUtil.exec(Configs.UPNP_LEASE_FILE)
        if upnpLease then
            upnpLease = LuciUtil.trim(upnpLease)
            local upnpFile = io.open(upnpLease,"r")
            if upnpFile then
                local upnpList = {}
				local deviplist = getIPListfromDevlist()
                for line in upnpFile:lines() do
                    if not isStrNil(line) then
                        local item = {}
                        local info = LuciUtil.split(line,":")
                        if #info == 6 then
                            item["protocol"] = info[1]
                            item["extport"] = info[2]
                            item["ip"] = info[3]
                            item["intport"] = info[4]
                            item["time"] = info[5]
                            if info[6] == "(null)" then
                                item["name"] = "未知程序"
                            else
                                item["name"] = info[6]
                            end
							
							if deviplist[item["ip"]] == "1" then
                                table.insert(upnpList,item)
							end
                        end
                    end
                end
                upnpFile:close()
                return upnpList
            end
        end
    end
    return nil
end

function geturlfilterinfo()
    local enable = getUConfig("urlfilterenable", "0", "account")
	local list = {}                                                         
	LuciUci:foreach("urlfilterlist","machine",                                  
		function(s)                                                     
			if s ~= nil and s.domainname ~= nil then
				  table.insert(list, {domainname = s.domainname, domainref = s.domainref or ""})
			end                                                    
		end                                                             
	)    	
	return enable,list
end

function getUFEnableStr()
    local devid,softid = getRouterDevAndSoftID()
	if devid == "003" then
	    return "insmod /lib/modules/3.10.14/url-filter.ko"
	else
	    return "insmod /lib/modules/2.6.36/url-filter.ko"
	end
end

function getUFDisableStr()
    local devid,softid = getRouterDevAndSoftID()
	if devid == "003" then
	    return "rmmod /lib/modules/3.10.14/url-filter.ko"
	else
	    return "rmmod /lib/modules/2.6.36/url-filter.ko"
	end
end

--list.domainname  域名
--list.domainref   说明
function seturlfilterinfo(enable,list)
    if enable ~= "0" and enable ~= "1" then
	    return "4032"
	end
	
	if enable == "0" then
	    setUConfig("urlfilterenable", "0", "account")
		LuciUtil.exec(getUFDisableStr())
		LuciUtil.exec("rm -rf "..Configs.URLFILTER_FILEPATH)
	else
	    if isStrNil(list) or type(list) ~= "table" or table.getn(list) < 1 then
		    setUConfig("urlfilterenable", "1", "account")
			if isStrNil(list) then
			    checkurlfilterinit()
			else
			    LuciUtil.exec("rm -rf /etc/config/urlfilterlist")
                LuciUtil.exec("touch /etc/config/urlfilterlist")
			    LuciUtil.exec(getUFDisableStr())
		        LuciUtil.exec(getUFEnableStr())
			    changeurlfiltergateway()
	            LuciUtil.exec("rm -rf "..Configs.URLFILTER_FILEPATH)
			    LuciUtil.exec("touch "..Configs.URLFILTER_FILEPATH) 
			end
            return "0"			
	    end
		
		if table.getn(list) > 500 then
		    return "10061"
	    end 
		
		setUConfig("urlfilterenable", "1", "account")
		LuciUtil.exec("rm -rf /etc/config/urlfilterlist")
        LuciUtil.exec("touch /etc/config/urlfilterlist")
		LuciUci:commit("urlfilterlist")
		LuciUci:save("urlfilterlist")
		
		local namelist = {}
		for _i, item in ipairs(list) do
			config_name = "item"..tostring(_i)
			if isStrNil(item.domainref) then
			    item.domainref = ""
			end
			LuciUci:section("urlfilterlist", "machine", config_name, item)
			table.insert(namelist,item.domainname)
		end
		LuciUci:commit("urlfilterlist")
		LuciUci:save("urlfilterlist")
		
		LuciUtil.exec(getUFDisableStr())
		LuciUtil.exec(getUFEnableStr())

		changeurlfiltergateway()
		LuciUtil.exec("echo 'a' >> /proc/youku/url-filter/stat")
	    LuciUtil.exec("rm -rf "..Configs.URLFILTER_FILEPATH)
        LuciUtil.exec("echo \""..table.concat(namelist,"\n").."\" > "..Configs.URLFILTER_FILEPATH)
		LuciUtil.exec(Configs.URLFILTER_ADDCOMMAND)
	end
    return "0"
end

--list.domainname  域名
--list.domainref   说明
function updateurlfilterinfo(enable, optype, list)
    if enable ~= "0" and enable ~= "1" then
	    return "4032"
	end
	
	local oldenable, oldlist = geturlfilterinfo()
	
	if enable == "0" then
	    if oldenable ~= "0" then
			setUConfig("urlfilterenable", "0", "account")
			LuciUtil.exec(getUFDisableStr())
			LuciUtil.exec("rm -rf "..Configs.URLFILTER_FILEPATH)
		end
		return "0"
	end
	
	setUConfig("urlfilterenable", "1", "account")
	local namelist = {}
	--针对列表进行修改
	--optype 0: overwrite  1: add  2: update  3: delete
	if list ~= nil and type(list) == "table" and table.getn(list) >= 1 then
		if optype == "1" then
		    for _i, newitem in ipairs(list) do
			    local existflag = false
			    for _j,  item in ipairs(oldlist) do
				    if item.domainname == newitem.domainname then
					    existflag = true
					end
				end
				
				if not existflag then
					table.insert(oldlist,newitem)
					table.insert(namelist,newitem.domainname)
				end
			end
			
			LuciUtil.exec("rm -rf /etc/config/urlfilterlist")
			LuciUtil.exec("touch /etc/config/urlfilterlist")
			LuciUci:commit("urlfilterlist")
		    LuciUci:save("urlfilterlist")
			
			for _i, item in ipairs(oldlist) do
				config_name = "item"..tostring(_i)
				if isStrNil(item.domainref) then
					item.domainref = ""
				end
				LuciUci:section("urlfilterlist", "machine", config_name, item)
			end
			
			LuciUci:commit("urlfilterlist")
			LuciUci:save("urlfilterlist")
			
			LuciUtil.exec("echo 'a' >> /proc/youku/url-filter/stat")
			LuciUtil.exec("rm -rf "..Configs.URLFILTER_FILEPATH)
			LuciUtil.exec("echo \""..table.concat(namelist,"\n").."\" > "..Configs.URLFILTER_FILEPATH)
			LuciUtil.exec(Configs.URLFILTER_ADDCOMMAND)
			
		elseif optype == "2" then
		    for _i, item in ipairs(oldlist) do
			    for _j,  newitem in ipairs(list) do
				    if item.domainname == newitem.domainname then
					    item.domainref = newitem.domainref
					end
				end
			end
			
			LuciUtil.exec("rm -rf /etc/config/urlfilterlist")
			LuciUtil.exec("touch /etc/config/urlfilterlist")
			LuciUci:commit("urlfilterlist")
		    LuciUci:save("urlfilterlist")
			
			for _i, item in ipairs(oldlist) do
				config_name = "item"..tostring(_i)
				if isStrNil(item.domainref) then
					item.domainref = ""
				end
				LuciUci:section("urlfilterlist", "machine", config_name, item)
			end
			
			LuciUci:commit("urlfilterlist")
			LuciUci:save("urlfilterlist")
			
		elseif optype == "3" then
			for _j,  newitem in ipairs(list) do
				for _i = #oldlist, 1,  -1 do
				    if oldlist[_i].domainname == newitem.domainname then
					    table.remove(oldlist,_i)
						table.insert(namelist,newitem.domainname)
					end
				end
			end
			
			LuciUtil.exec("rm -rf /etc/config/urlfilterlist")
			LuciUtil.exec("touch /etc/config/urlfilterlist")
			LuciUci:commit("urlfilterlist")
		    LuciUci:save("urlfilterlist")
			
			for _i, item in ipairs(oldlist) do
				config_name = "item"..tostring(_i)
				if isStrNil(item.domainref) then
					item.domainref = ""
				end
				LuciUci:section("urlfilterlist", "machine", config_name, item)
			end
			
			LuciUci:commit("urlfilterlist")
			LuciUci:save("urlfilterlist")
			
			LuciUtil.exec("echo 'd' >> /proc/youku/url-filter/stat")
			LuciUtil.exec("rm -rf "..Configs.URLFILTER_FILEPATH)
			LuciUtil.exec("echo \""..table.concat(namelist,"\n").."\" > "..Configs.URLFILTER_FILEPATH)
			LuciUtil.exec(Configs.URLFILTER_ADDCOMMAND)
			LuciUtil.exec("echo 'a' >> /proc/youku/url-filter/stat")
			
		else
		    oldlist = list
			LuciUtil.exec("rm -rf /etc/config/urlfilterlist")
			LuciUtil.exec("touch /etc/config/urlfilterlist")
			LuciUci:commit("urlfilterlist")
		    LuciUci:save("urlfilterlist")
			
			for _i, item in ipairs(oldlist) do
				config_name = "item"..tostring(_i)
				if isStrNil(item.domainref) then
					item.domainref = ""
				end
				LuciUci:section("urlfilterlist", "machine", config_name, item)
				table.insert(namelist,item.domainname)
			end
			LuciUci:commit("urlfilterlist")
			LuciUci:save("urlfilterlist")
			
			LuciUtil.exec(getUFDisableStr())
			LuciUtil.exec(getUFEnableStr())
			changeurlfiltergateway()
			LuciUtil.exec("echo 'a' >> /proc/youku/url-filter/stat")
			LuciUtil.exec("rm -rf "..Configs.URLFILTER_FILEPATH)
			LuciUtil.exec("echo \""..table.concat(namelist,"\n").."\" > "..Configs.URLFILTER_FILEPATH)
			LuciUtil.exec(Configs.URLFILTER_ADDCOMMAND)
		end	
	else
	    if oldenable ~= "1" then
			LuciUtil.exec(getUFDisableStr())
			LuciUtil.exec(getUFEnableStr())
			changeurlfiltergateway()
			LuciUtil.exec("rm -rf "..Configs.URLFILTER_FILEPATH)
			LuciUtil.exec("echo \""..table.concat(namelist,"\n").."\" > "..Configs.URLFILTER_FILEPATH)
			LuciUtil.exec(Configs.URLFILTER_ADDCOMMAND)
		end
	end
    return "0"
end

function changeurlfiltergateway()
    local enable = getUConfig("urlfilterenable", "0", "account")
	if enable == "1" then
	    local gateway = LuciUci:get("network","lan","ipaddr")
		LuciUtil.exec("echo \""..gateway.."\" >> /proc/youku/url-filter/gateway")
	end
end

function changeurlfilterRdrIP(ip)
    local enable = getUConfig("urlfilterenable", "0", "account")
	if enable == "1" then
		LuciUtil.exec("echo \""..ip.."\" >> /proc/youku/url-filter/redirIp")
	end
end

function checkurlfilterinit()
    local enable = getUConfig("urlfilterenable", "0", "account")
	if enable == "1" then
	    LuciUtil.exec(getUFDisableStr())
		LuciUtil.exec(getUFEnableStr())
		changeurlfiltergateway()
		LuciUtil.exec("rm -rf "..Configs.URLFILTER_FILEPATH)
		
		local namelist = {}                                                         
		LuciUci:foreach("urlfilterlist","machine",                                  
			function(s)                                                     
				if s ~= nil and s.domainname ~= nil then
					  table.insert(namelist, s.domainname)
				end                                                    
			end                                                             
		)    	
		if namelist == nil or type(namelist) ~= "table" or table.getn(namelist) < 1 then
            LuciUtil.exec("touch "..Configs.URLFILTER_FILEPATH)
		else
		    LuciUtil.exec("echo \""..table.concat(namelist,"\n").."\" > "..Configs.URLFILTER_FILEPATH)
			LuciUtil.exec(Configs.URLFILTER_ADDCOMMAND)
		end
    end
end

function getSYSinfo()
    local sysInfo = {}
	local LuciSys = require("luci.sys")
    local platform, model, memtotal, memcached, membuffers, memfree, bogomips = LuciSys.sysinfo()
    local devid,softid = getRouterDevAndSoftID()
	if devid == "003" then
	    sysInfo["devtype"] = "YK-L2"
	else
	    sysInfo["devtype"] = "YK-L1"
	end
	sysInfo["cputype"] = platform
    if platform == "MT7620" then
        sysInfo["cpuhz"] = "580 MHz"
	elseif platform == "MT7621" then
	    sysInfo["cpuhz"] = "880 MHz * 2"
    end
	
	if memtotal > (130*1024) then
	    sysInfo["memTotal"] = "256 MB"
	else
	    sysInfo["memTotal"] = "128 MB"
	end
    sysInfo["memFree"] = string.format("%0.2f MB",memfree/1024)
    return sysInfo
end

function getCustomInfo()
    local custominfo = {}
    local cusinfo = LuciUtil.exec("cat /www/extend/js/common.js 2>/dev/null")
	if cusinfo then
	    custominfo.showUGold = cusinfo:match('var showUGold = (%S+);') or "1"
		custominfo.fixedEnable = cusinfo:match('var fixedEnable = (%S+);') or "1"
		custominfo.AppManageEnable = cusinfo:match('var AppManageEnable = (%S+);') or "1"
		custominfo.customName = cusinfo:match('var customName = "(%S+)";') or "标准版"
		local customtext = cusinfo:match('var customReference = "(%S+)";') or ""
		custominfo.customReference = getCustomRef(customtext) or ""
	else
	    custominfo.showUGold = "1"
		custominfo.fixedEnable = "1"
		custominfo.AppManageEnable = "1"
		custominfo.customName = "标准版"
		custominfo.customReference = ""
    end
	return custominfo
end

function getCustomRef(customtext)
    local devid,softid = getRouterDevAndSoftID()
	local returnref = ""
	if softid == "001" then
	    local NixioFs = require("nixio.fs")
		if NixioFs.access("/tmp/youku/stat/wokuan.log") then
			local line = LuciUtil.trim(LuciUtil.exec("tail -n 1 /tmp/youku/stat/wokuan.log"))
			if not isStrNil(line) then
				local sday = line:match('^(%S+) ') or ""
				local sh,sm,ss = line:match(' (%S+):(%S+):(%S+) {')                         
				local result = line:match('{\"result\":\"(%S+)\",\"desc\"') or "false"
				if not isStrNil(sh) and not isStrNil(sm) and not isStrNil(ss) then									 
					local showtime = sday..sh..sm..ss                    
					local curtime = LuciUtil.exec("date '+%Y%m%d%H%M%S'")                                                   

					if result == "success" and tonumber(curtime) - tonumber(showtime) < 80000 then
						returnref = customtext
					end  
				end
			end
		end 
	end
	return returnref
end

function getRouterDevAndSoftID()
    local peerid = getrouterpid()
	local devid = "000"
	local softid = "000"
	if string.len(peerid) > 24 then
        devid = string.sub(peerid,19,21) or "000"
	    softid = string.sub(peerid,22,24) or "000"
	end
	return devid,softid
end

function startspeedtest()
    local ret = LuciUtil.exec(Configs.SPEEDTEST_START)
	if not isStrNil(ret) then
	    ret = LuciJson.decode(ret)
		return ret.code
	end
	return -1
end

function checkspeedinfo()
    local checkret = LuciUtil.exec(Configs.SPEEDTEST_CHECK)
	local data = {progress=0, downspeed=0, upspeed=0} 
	if not isStrNil(checkret) then
	    local str_lines = string.split(checkret,"\n")
	    for _i, a_line in ipairs(str_lines) do
			local words = string.split(a_line, " ") 
			
            if table.getn(words) >= 4 and ( words[3] == "-1" or words[4] == "-1" ) then
               return -1,data
            end
			
			if table.getn(words) == 4 then
				data.progress = tonumber(words[2])
				data.downspeed = tonumber(words[4])*8192
				data.upspeed = tonumber(words[3])*8192
			end
	    end
		
		if data.progress == 100 then
		    setUConfig("downspeed", data.downspeed, "account")
			setUConfig("upspeed", data.upspeed, "account")
		end
	end
	return 0,data
end

function checkdhcpAndLanGateway()
    local cmdstring = LuciUtil.exec(Configs.GET_DOMAIN_IP)
	local dhcpgateway = "192.168.11.1"
	if not isStrNil(cmdstring) then
	    dhcpgateway = cmdstring:match("/wifi.youku.com/(%S+)") or "192.168.11.1"
	end
	local langateway = LuciUci:get("network","lan","ipaddr")
	if dhcpgateway ~= langateway then
	    changeRouterDomain(langateway)
		forkRestartDnsmasq()
	end
end

function checkActivateEnable()
    local activeinfo = "0"
    local cusinfo = LuciUtil.exec("cat /www/extend/js/common.js 2>/dev/null")
	if cusinfo then
	    activeinfo = cusinfo:match('var activeEnable = (%S+);') or "0"
    end
	
	if activeinfo == "1" then
	    return true
	end
	return false
end

function activateEnable(key)
    LuciUtil.exec("/usr/sbin/check_svc.sh check wkplug >/dev/null 2>/dev/null")
    return "0"
end

function getaccpause()
    local accpause = getUConfig("accpause", "0", "account")
	if accpause == "0" then
	    return accpause,"0"
	else
	    local accpauseEtime = getUConfig("accpauseendtime", "0", "account")
		local accpausedelay = getUConfig("accpausedelay", "0", "account")
		local curtime = trimLinebreak(LuciUtil.exec("date '+%s'"))
		if tonumber(curtime) > tonumber(accpauseEtime) then
		    setUConfig("accpause", "0", "account")
			setUConfig("accpausedelay", "0", "account")
			setUConfig("accpauseendtime", "", "account")
			return "0","0"
		else
		    return accpause,accpausedelay
		end
	end
end

function setaccpause(enable,delay)
	if enable == "1" then
	    local accpause,accdelay = getaccpause()
		if accpause == "1" then
		     return
		end
		
		if isStrNil(delay) then
			delay = "2"
		end
		
		local curtime = trimLinebreak(LuciUtil.exec("date '+%s'"))
		local endtime = tostring(tonumber(curtime) + tonumber(delay) * 3600)
		
		setUConfig("accpause", "1", "account")
		setUConfig("accpausedelay", delay, "account")
		setUConfig("accpauseendtime", endtime, "account")	
	else
	    setUConfig("accpause", "0", "account")
		setUConfig("accpausedelay", "0", "account")
		setUConfig("accpauseendtime", "", "account")
	end
	LuciUtil.exec(Configs.ACC_CHECK_CONF)
end

function resetwifidriver(flag)
    local devid,softid = getRouterDevAndSoftID()
	local cmd = ""
	if flag then
		if devid == "003" then
			cmd = "wifi down >/dev/null 2>/dev/null && rmmod /lib/modules/3.10.14/mt7603e.ko >/dev/null 2>/dev/null && insmod /lib/modules/3.10.14/mt7603e.ko >/dev/null 2>/dev/null && /etc/init.d/network restart >/dev/null 2>/dev/null "
		else
			cmd = "wifi downup >/dev/null 2>/dev/null && ifconfig ra1 up >/dev/null 2>/dev/null "
		end
	else
	    cmd = "wifi downup >/dev/null 2>/dev/null && ifconfig ra1 down >/dev/null 2>/dev/null "
	end
	return cmd
end

function getWanclone()
    return getUConfig("wanclone", "1", "account")
end
-- "1":使用当前mac地址   "2": 使用出厂MAC  "3": 使用设备MAC  "4":"使用自定义MAC" 
function setWanclone(wanclone)
    if not isStrNil(wanclone) and (tonumber(wanclone) >= 1 and tonumber(wanclone) <= 4) then
	    setUConfig("wanclone", tostring(tonumber(wanclone)), "account")
	end
end