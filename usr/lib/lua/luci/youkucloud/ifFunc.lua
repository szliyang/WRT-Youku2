module ("luci.youkucloud.ifFunc", package.seeall)
local wifisetting = require("luci.youkucloud.wifiSetting")
local commonFunc = require("luci.youkucloud.function")
local commonConf = require("luci.youkucloud.config")
local youkuInterface = require("luci.youkucloud.youkuinterface")
local uci = require("luci.model.uci")
local LuciUci = uci.cursor()
local LuciUtil = require "luci.util"
local json = require("luci.json")
local LuciOS = require("os")

ERROR_LIST={
    ["4031"]={["code"]=4031,["desc"]="key参数不合法，访问拒绝！"},
	["4032"]={["code"]=4032,["desc"]="context参数不合法,访问拒绝！"},
	["4033"]={["code"]=4033,["desc"]="操作不合法,访问拒绝！"},
	["4034"]={["code"]=4034,["desc"]="访客身份连接,访问拒绝！"},
	["4035"]={["code"]=4035,["desc"]="该版本不支持此项设定,访问拒绝！"},
	["10001"]={["code"]=10001,["desc"]="管理员密码不正确！"},
	["10002"]={["code"]=10002,["desc"]="原管理员密码不正确！"},
    ["10003"]={["code"]=10003,["desc"]="新管理员密码不符合规范！"},
	["10010"]={["code"]=10010,["desc"]="设备信息错误！"},
	["10011"]={["code"]=10011,["desc"]="设备名称不存在！"},
	["10012"]={["code"]=10012,["desc"]="设备MAC地址错误！"},
	["10013"]={["code"]=10013,["desc"]="输入的设备IP已使用或错误！"},
	["10020"]={["code"]=10020,["desc"]="WiFi设置错误！"},
	["10021"]={["code"]=10021,["desc"]="WiFi信号强度定时设置错误！"},
	["10022"]={["code"]=10022,["desc"]="加速器模式定时设置错误！"},
	["10023"]={["code"]=10023,["desc"]="加入固定收益计划，不能设置加速模式！"},
	["10030"]={["code"]=10030,["desc"]="升级包文件不合法！"},
	["10031"]={["code"]=10031,["desc"]="升级包文件不存在！"},
	["10032"]={["code"]=10032,["desc"]="升级包文件下载失败！"},
	["10033"]={["code"]=10033,["desc"]="磁盘空间不足，无法上传升级包！"},
	["10034"]={["code"]=10034,["desc"]="升级信息获取失败！"},
	["10040"]={["code"]=10040,["desc"]="访问控制模式不正确！"},
	["10041"]={["code"]=10041,["desc"]="本机(Wi-Fi连接)必须在白名单中！"},
	["10042"]={["code"]=10042,["desc"]="本机(Wi-Fi连接)不能放到黑名单中！"},
	["10043"]={["code"]=10043,["desc"]="名单中最多放64条！"},
	["10050"]={["code"]=10050,["desc"]="路由器保留端口不能用作转发！"},
	["10051"]={["code"]=10051,["desc"]="端口转发列表中存在端口冲突！"},
	["10052"]={["code"]=10052,["desc"]="端口格式不正确！"},
	["10060"]={["code"]=10060,["desc"]="网址过滤列表不能为空！"},
	["10061"]={["code"]=10061,["desc"]="网址过滤列表超过最大限制条数！"},
	["10070"]={["code"]=10070,["desc"]="QOS相关参数错误！"},
	["10071"]={["code"]=10071,["desc"]="设置QOS前请先测速！"}
}

function login(pwd,paramto)
	local result={result=0,data=nil,error=nil}
	if string.len(pwd) > 3 then
		local prefix = string.sub(pwd,1,2)
		pwd = string.sub(pwd,3)
		if(prefix=="ad" and commonFunc.checkAdminPwd(pwd)) or (prefix=="sn" and commonFunc.checkSNPwd(pwd) and paramto==nil) 
		   or (prefix=="sh" and commonFunc.checksha1Pwd(pwd)) then
			local data = {key=nil,ver=nil}
			data.key = youkuInterface.createLoginKey()
			data.pid = commonFunc.getroutersn()
			data.crypid = commonFunc.getroutercrypid()
			data.pcdnurltoken,data.pcdnurltokenwithssid,data.rkey = commonFunc.createPCDNURLparam()
			data.devid,data.softid = commonFunc.getRouterDevAndSoftID()
			data.custominfo = commonFunc.getCustomInfo()
			data.ver = 4
			result.result = 0
			result.data = data
		else
			result=seterrordata(result,ERROR_LIST["10001"])
		end
	else
	    result=seterrordata(result,ERROR_LIST["10001"])
	end
	return result
end

function logout(key)
    local ret = youkuInterface.deleteLoginKey(key)
	local result = {result=0,error=nil}
	if ret ~= 0 then
	    result=seterrordata(result,ERROR_LIST["4031"])
	end
	return result
end

function getRouterInfo(paramcon,havekey,fromtype)
    local keyflag = havekey or false
	local result={result=0,data=nil,error=nil}
	local data={}
	
	if paramcon == nil or paramcon == "" then
	    result=seterrordata(result,ERROR_LIST["4032"])
		return result
	end
	
	if paramcon ~= "dynamic" and paramcon ~="network" 
	   and paramcon ~="devices" and paramcon ~="basic" 
	   and paramcon ~="all" and paramcon ~= "pppoestate" 
	   and paramcon ~= "actionstate" and paramcon ~= "devicesnorate" 
	   and paramcon ~= "detect" then
	    result=seterrordata(result,ERROR_LIST["4032"])
		return result
	end
	
	if paramcon == "pppoestate" then
	    local status = commonFunc.getPPPoEStatus()
		if status and tonumber(status.status)==3 then
		     data.pppoestate=status.status
			 data.pppoeerrcode=status.errcode
			 data.pppoeerrmsg=status.errmsg
		else
		     data.pppoestate=status.status
		end
		result.result = 0
	    result.data = data
	    return result
	end
	
	if paramcon == "actionstate" then
	    data.actionstate = commonFunc.actionstatusforIF()
		result.result = 0
	    result.data = data
	    return result
	end
	
	if paramcon == "detect" then
	    data = commonFunc.getdetectinfo()
		result.result = 0
	    result.data = data
	    return result
	end
	
	local initflagint = 1
	local initflag = commonFunc.getrouterinit()
    if initflag == nil or initflag == "" or initflag == "false" then
	    initflagint = 0
	end
	
	if paramcon == "network"  and  initflagint == 1 and keyflag then
	    local s = loadnetworkfile()
		if not commonFunc.isStrNil(s) then
            result.data = s
			if s.initflag ~= initflagint then
			    result = _getRouterInfo(paramcon,havekey,"app")
			    writenetworkfile(result.data)
				if fromtype ~= "app" then
					result.data.pid = nil
				end
				return result
			end
			
			result.data.accmode = commonFunc.getaccmode()
		    --result.data.accpause, result.data.accpausedelay = commonFunc.getaccpause()
		    result.data.acctimingenable,result.data.accfullmode,result.data.acctimemode,result.data.acctime = commonFunc.getacctimemode()
            result.data.uptime = commonFunc.getruntime()
		    result.data.devicecount,result.data.down_rate,result.data.up_rate,result.data.toweb,result.data.acc_down_rate,result.data.acc_up_rate = commonFunc.getDeviceSumInfo()
            result.data.toweb = tostring(result.data.toweb)
			result.data.wanIP, result.data.MacAddr = wifisetting.getWanIPMac()
			result.data.wanstate = commonFunc.getwanstate()
			result.data.pcdnurltoken,result.data.pcdnurltokenwithssid,result.data.rkey = commonFunc.createPCDNURLparam()
			result.data.checkupdatetime=commonFunc.checkUpdatetime()
			result.data.custominfo = commonFunc.getCustomInfo()
            result.data.initflag = initflagint
			
			result.data.newver = ""
			if result.data.wanstate =="2" or result.data.wanstate == "3" then
				local newverinfo = commonFunc.readUpgrade()
				if newverinfo.hasupdate=="1" then
				   result.data.newver = newverinfo.version
				end
			end
			
			if keyflag then
			    if result.data.lan ~= nil then
				    result.data.lan.upnpdevlist = commonFunc.getUPnPList()  --upnp的设备列表
				end
				
				local wifiInfo = wifisetting.getWifiBasicInfo(1)
				result.data.wifi = wifiInfo
				result.data.wifi.txptimingenable,result.data.wifi.txpfullmode,result.data.wifi.txptimemode,result.data.wifi.txptime = commonFunc.gettxptimemode()
				if wifisetting.wifi_5G_exist() then
					local wifi5GInfo = wifisetting.getWifiBasicInfo(3)
					result.data.wifi_5G = wifi5GInfo
				end
				
				if result.data.wan ~= nil then
				    result.data.wan.localmac = result.data.MacAddr
					if result.data.wan.dns == nil or result.data.wan.dns == "" then
					    local dns_info = LuciUtil.exec("cat /tmp/resolv.conf.auto")
						result.data.wan.dns = dns_info:match('nameserver (%S+)')
					end
					if result.data.wan.dns ~= nil and result.data.wan.dns ~= "" then
						local dnslist = string.split(result.data.wan.dns," ")
						if dnslist and #dnslist > 1 then
							result.data.wan.dns1 = dnslist[1]
							result.data.wan.dns2 = dnslist[2]
						else
							result.data.wan.dns1 = result.data.wan.dns
						end
					end
				end
	        end
			
			if luci.http.context.request then
			    local remotemac = commonFunc.getRemoteMac()
			    if result.data.wan ~= nil then
				    result.data.wan.remotemac = remotemac
				end
				local wifi_map = commonFunc.getWifiInfo()
				result.data.connectiontype = "line"
				if wifi_map[remotemac] ~= nil then
					result.data.connectiontype = "wifi"
				end
			end
			if fromtype ~= "app" then
			    result.data.pid = nil
			end
		else 
		    result = _getRouterInfo(paramcon,havekey,"app")
			writenetworkfile(result.data)
			if fromtype ~= "app" then
			    result.data.pid = nil
			end
        end		
	else
	   result = _getRouterInfo(paramcon,havekey,fromtype)
	end
    
	return result
end

function loadnetworkfile()
  local LuciUtil = require "luci.util"
  local nixio = require("nixio")
  local fd = nixio.open("/tmp/youkunetwork", "r")
    local s = ""
    if fd then
        s = fd:readall() or ""
        fd:close()
    end
	
	if s == "" or s == nil then
	    return nil
	end
	
    return LuciUtil.restore_data(s)
end

function writenetworkfile(tbl)
    local LuciUtil = require "luci.util"
	local nixio = require("nixio")
	local fd = nixio.open("/tmp/youkunetwork", "w")
	local s = LuciUtil.serialize_data(tbl)
    if fd then
        fd:write(s)
        fd:close()
    end
end

function _getRouterInfo(paramcon,havekey,fromtype)
    local keyflag = havekey or false
	local result={result=0,data=nil,error=nil}
	local data={}
	
	--获取基础信息
	data.initflag=1
	local initflag = commonFunc.getrouterinit()
    if initflag == nil or initflag == ""  then
	    data.initflag=0
	end
	data.curver = commonFunc.getyoukuvertion()
	data.wanstate = commonFunc.getwanstate()
	if fromtype and fromtype == "app" then
	    data.pid = commonFunc.getroutersn()
	end
	data.crypid = commonFunc.getroutercrypid()
	data.wanIP, data.MacAddr = wifisetting.getWanIPMac()
	data.wanGateway = wifisetting.getWanIPGateway()["gateway"]
	data.checkupdatetime=commonFunc.checkUpdatetime()
	data.creditmode=commonFunc.getcreditmode()
	data.have5G = "0"
	if wifisetting.wifi_5G_exist() then
	    data.have5G = "1"
	end
	
	data.newver = ""
	if data.wanstate =="2" or data.wanstate == "3" then
		local newverinfo = commonFunc.readUpgrade()
		if newverinfo.hasupdate=="1" then
		   data.newver = newverinfo.version
		end
	end
		
	local remotemac = nil
	if luci.http.context.request then
		remotemac = commonFunc.getRemoteMac()
		local wifi_map = commonFunc.getWifiInfo()
		data.connectiontype = "line"
		if wifi_map[remotemac] ~= nil then
		    data.connectiontype = "wifi"
		end
	end
	
	--basic 2 数据
	if keyflag and paramcon ~= "dynamic" then
	    data.lightmode,data.lighttime = commonFunc.getLEDMode()
		data.pcdnurltoken,data.pcdnurltokenwithssid,data.rkey = commonFunc.createPCDNURLparam()
	end
	
	--dynamic 数据
	if keyflag and (paramcon == "dynamic" or paramcon == "all" or paramcon == "network")then
	    data.accmode = commonFunc.getaccmode()
		--data.accpause, data.accpausedelay = commonFunc.getaccpause()
		data.acctimingenable,data.accfullmode,data.acctimemode,data.acctime = commonFunc.getacctimemode()
        data.uptime = commonFunc.getruntime()
		data.devicecount,data.down_rate,data.up_rate,data.toweb,data.acc_down_rate,data.acc_up_rate = commonFunc.getDeviceSumInfo()
        data.toweb = tostring(data.toweb)
    end
	
	--network wifi data
	if (paramcon == "network" or paramcon == "all") and (data.initflag==0 or keyflag) then
	    data.sysinfo = commonFunc.getSYSinfo()
	    data.custominfo = commonFunc.getCustomInfo()
        data.devid,data.softid = commonFunc.getRouterDevAndSoftID()
		data.wifi = wifisetting.getWifiBasicInfo(1)
		data.wifi.txptimingenable,data.wifi.txpfullmode,data.wifi.txptimemode,data.wifi.txptime = commonFunc.gettxptimemode()
		if data.have5G == "1" then
		    data.wifi_5G = wifisetting.getWifiBasicInfo(3)
		end
	end
	
	--network wan lan data
	if (paramcon == "network" or paramcon == "all") and (data.initflag==0 or keyflag) then
	    local waninfo = {}
        waninfo["proto"] = LuciUci:get("network","wan","proto")
		waninfo["ipaddr"] = LuciUci:get("network","wan","ipaddr") or ""
        waninfo["netmask"] = LuciUci:get("network","wan","netmask") or ""
        waninfo["gateway"] = LuciUci:get("network","wan","gateway") or ""
		waninfo["username"] = LuciUci:get("network","wan","username") or ""
        waninfo["password"] = "youku********"
		if (data.initflag==0 or keyflag) then
			waninfo["dns"] = LuciUci:get("network","wan","dns") or ""
			local dns_info = LuciUtil.exec("cat /tmp/resolv.conf.auto")
			if waninfo["dns"] == nil or waninfo["dns"] == "" then
				waninfo["dns"] = dns_info:match('nameserver (%S+)')
			end
			if waninfo["dns"] ~= nil and waninfo["dns"] ~= "" then
				local dnslist = string.split(waninfo["dns"]," ")
				if dnslist and #dnslist > 1 then
					waninfo["dns1"] = dnslist[1]
					waninfo["dns2"] = dnslist[2]
				else
					waninfo["dns1"] = waninfo["dns"]
				end
			end
			local dnsflag = LuciUci:get("network","wan","peerdns")
			if dnsflag == nil or dnsflag == 1 then
				waninfo["switch"] = 0
			else
				waninfo["switch"] = 1
			end
			
			waninfo["mtu"] = LuciUci:get("network","wan","mtu")
			waninfo["localmac"] = data.MacAddr
			waninfo["remotemac"] = remotemac
			waninfo["initmac"] = commonFunc.getRouterInitMac()
			waninfo['wanclone'] = commonFunc.getWanclone()
			
			if (data.initflag==0 and data.wanstate=="1") then
				waninfo["proto"] = commonFunc.checkconenv()
			end
		end
		waninfo.advance_switch = commonFunc.getAdvanceSwitch()
		data.wan = waninfo
		
		if keyflag then
			local laninfo = {}
			laninfo["ipaddr"] = LuciUci:get("network","lan","ipaddr")                      
			laninfo["netmask"] = LuciUci:get("network","lan","netmask")  

			local ignore = LuciUci:get("dhcp","lan","ignore")
			if ignore ~= "1" then
				ignore = "0"
			end
			laninfo["dhcp_switch"] = ignore

			local list = string.split(laninfo["ipaddr"],".")                                
			local pre_ip = ""                                                                   
			local i = 0                                                                         
			for k,v in ipairs(list) do                                                          
				  pre_ip = pre_ip .. v                                                        
				  pre_ip = pre_ip .. "."                                                      
				  if i == 2 then                                                              
						  break                                                               
				  end                                                                         
			  i = i + 1                                                                       
			end                                                                                 
																						  
			local dhcp_start = LuciUci:get("dhcp","lan","start")                                
			local dhcp_limit = LuciUci:get("dhcp","lan","limit")                                
			laninfo["dhcp_pre_ip"] =  pre_ip                                                     
			laninfo["dhcp_start_ip"] = dhcp_start                                                
			local tmp_int = tonumber(dhcp_start)                                                
			tmp_int = tmp_int + tonumber(dhcp_limit) - 1                                        
			laninfo["dhcp_stop_ip"] = tostring(tmp_int)
			laninfo["enable_upnp"]= tonumber(LuciUci:get("upnpd","config","enable_upnp"))
			laninfo.upnpdevlist = commonFunc.getUPnPList()  --upnp的设备列表
			data.lan = laninfo
			
			--dmz and portforward  0:关闭  1：端口转发  2：DMZ
			data.redirecttype, data.redirectlist, data.dmzip = commonFunc.getredirectinfo()
			
			--网址过滤 
			data.urlfilterenable,data.urlfilterlist = commonFunc.geturlfilterinfo()
			
			--上下行最大网速，以前的测速结果
			data.maxdownspeed, data.maxupspeed = 0,0
			
			--qos相关信息
			data.qosenable, data.qostype, data.qosdevlist = "0","1",{}
		end
	end
	
	if (paramcon == "devices" or paramcon == "all") and keyflag then
	    data.devices = commonFunc.getAllDeviceInfo()
	end
	
	if paramcon == "devicesnorate" and keyflag then
		data.devices = commonFunc.getAllDeviceInfoNoRate()
	end
	
	if (paramcon == "devices" or paramcon == "devicesnorate" or paramcon == "all") and keyflag then
		data.blackwhitemode = commonFunc.getblackwhitemode()
		data.blacklist,data.whitelist = commonFunc.getblackwhiteInfo()
	end
	
	result.result = 0
	result.data = data
	return result
end

function setRouterInfo(paramcon,havekey,loginkey)
    local result={result=0,data=nil,error=nil}
	local retdata={mode=0}
		
	local setdatas = paramcon
	if setdatas==nil or type(setdatas) ~= "table" then
		result=seterrordata(result,ERROR_LIST["4032"])
		return result
	end
	
	local initflag=1
	local tmpflag = commonFunc.getrouterinit()
	if tmpflag == nil or tmpflag == ""  then
		initflag=0
	end
	
	local restartwifi=false
	local restartnetwork=0    --0: 无操作  1: ifdownup wan  2: wifi downup  3: network restart
	local restartdnsmaq=false
	local reboot=false
	local relogin=false
	local guestcmdstr=""
	
	if setdatas.admin ~= nil and type(setdatas.admin) == "table" then
		if initflag == 1 then
		    local ret = commonFunc.checkAdminPwd(setdatas.admin.admin_oldpwd) or commonFunc.checkSNPwd(setdatas.admin.admin_oldpwd)
			if commonFunc.isStrNil(setdatas.admin.admin_oldpwd) or (not ret) then
				result=seterrordata(result,ERROR_LIST["10002"])
				return result
			end
		end
		
		if commonFunc.isStrNil(setdatas.admin.admin_newpwd) then
			result=seterrordata(result,ERROR_LIST["10003"])
			return result
		end
		commonFunc.setAdminPwd(setdatas.admin.admin_newpwd)
		commonFunc.setrouterinit("true")
		if havekey then
			youkuInterface.deleteLoginKey(loginkey)
			relogin = true
		end
	end
	
	if not commonFunc.isStrNil(setdatas.creditmode) and havekey then
	    commonFunc.setcreditmode(setdatas.creditmode)
	end
	
	if not commonFunc.isStrNil(setdatas.lightmode) and havekey then
		commonFunc.setLEDMode(setdatas.lightmode,setdatas.lighttime)
	end
	
	if not commonFunc.isStrNil(setdatas.accmode) and havekey then
	    --set accmode 
		if (commonFunc.getcreditmode()=="normal") then
		    commonFunc.setaccmode(setdatas.accmode)
			commonFunc.setacctimemode(false)
		else
		    result=seterrordata(result,ERROR_LIST["10023"])
			return result 
		end
	end
	
	if setdatas.acctimingenable and havekey then
	    if (commonFunc.getcreditmode()=="normal") then
			if (setdatas.acctimingenable=="true" or setdatas.acctimingenable==true)
			   and (commonFunc.isStrNil(setdatas.accfullmode) or commonFunc.isStrNil(setdatas.acctimemode) or commonFunc.isStrNil(setdatas.acctime)) then
			   result=seterrordata(result,ERROR_LIST["10022"])
			   return result 
			end
			if not commonFunc.setacctimemode(setdatas.acctimingenable,setdatas.accfullmode,setdatas.acctimemode,setdatas.acctime) then
			   result=seterrordata(result,ERROR_LIST["10022"])
			   return result 
			end
		else
		    result=seterrordata(result,ERROR_LIST["10023"])
			return result 
		end
	end
	
	if not commonFunc.isStrNil(setdatas.accpause) and havekey then
		commonFunc.setaccpause(setdatas.accpause,setdatas.accpausedelay)
	end
	
	if not commonFunc.isStrNil(setdatas.setupdatetime) and havekey then
		commonFunc.setUpdatetime()
	end
	
	if setdatas.devices ~= nil and type(setdatas.devices) == "table" and havekey then
		if table.getn(setdatas.devices) < 1 or type(setdatas.devices[1]) ~= "table" then
			result=seterrordata(result,ERROR_LIST["10010"])
			return result
		end
		
		for i, curdevice in ipairs(setdatas.devices) do
			if type(curdevice)=="table" and curdevice.device_op ~= nil and curdevice.device_mac ~= nil then
				if curdevice.device_op=="1" then
					if curdevice.device_mac=="|||" then
						local binddevices = commonFunc.getBindDeviceInfo()
						if table.getn(binddevices) > 0 then
						    local config_name = ""
							for _i, curdev in ipairs(binddevices) do
								config_name = string.lower(string.gsub(curdev.mac,"[:-]",""))
								LuciUci:delete("dhcp", config_name)
							end
						end
					else
					    if not commonFunc.checkmac(commonFunc.macFormat(curdevice.device_mac)) then
						    result=seterrordata(result,ERROR_LIST["10012"])
			                return result
						end
						local config_name = string.lower(string.gsub(curdevice.device_mac,"[:-]",""))
						LuciUci:delete("dhcp", config_name)
					end
					LuciUci:commit("dhcp")
					LuciUci:save("dhcp")
					restartdnsmaq = true
				elseif curdevice.device_op=="2" then
				    if not commonFunc.checkmac(commonFunc.macFormat(curdevice.device_mac)) then
						result=seterrordata(result,ERROR_LIST["10012"])
						return result
					end
					
					if curdevice.device_ip == nil or (not commonFunc.checkdhcpip(curdevice.device_ip,curdevice.device_mac)) then
						result=seterrordata(result,ERROR_LIST["10013"])
						return result
					end
					
					if commonFunc.isStrNil(curdevice.device_name) then
						curdevice.device_name = curdevice.device_mac
					end

					curdevice.device_mac = string.lower(curdevice.device_mac)
					local options = {["name"] = curdevice.device_name,["mac"] = curdevice.device_mac,["ip"] = curdevice.device_ip}
					local config_name = string.lower(string.gsub(curdevice.device_mac,"[:-]",""))
					LuciUci:section("dhcp", "host", config_name, options)
					LuciUci:commit("dhcp")
					LuciUci:save("dhcp")  
                    restartdnsmaq = true					
				elseif curdevice.device_op=="3" then
					if curdevice.device_mac=="|||" then
						local filterdevices = commonFunc.getMacFilterList()
						if table.getn(filterdevices) > 0 then
						    local config_name = ""
							for _i, curdev in ipairs(filterdevices) do
								config_name = string.lower(string.gsub(curdev.mac,"[:-]",""))
								LuciUci:delete("macfilter", config_name)
								LuciUtil.exec("iptables -I FORWARD -m mac --mac-source " .. curdev.mac .. " -j ACCEPT")
							end
						end
					else
					    if not commonFunc.checkmac(commonFunc.macFormat(curdevice.device_mac)) then
						    result=seterrordata(result,ERROR_LIST["10012"])
			                return result
						end
						local config_name = string.lower(string.gsub(curdevice.device_mac,"[:-]",""))
						LuciUci:delete("macfilter", config_name)
						LuciUtil.exec("iptables -I FORWARD -m mac --mac-source " .. curdevice.device_mac .. " -j ACCEPT")
					end
					LuciUci:commit("macfilter")
					LuciUci:save("macfilter")
				elseif curdevice.device_op=="4" then
				    if not commonFunc.checkmac(commonFunc.macFormat(curdevice.device_mac)) then
						result=seterrordata(result,ERROR_LIST["10012"])
						return result
					end
					if commonFunc.isStrNil(curdevice.device_name) then
						curdevice.device_name = curdevice.device_mac
					end
					curdevice.device_mac = string.lower(curdevice.device_mac)
					local options = {["name"] = curdevice.device_name,["mac"] = curdevice.device_mac}
					local config_name = string.lower(string.gsub(curdevice.device_mac,"[:-]",""))
					LuciUci:section("macfilter", "machine", config_name, options)
					LuciUci:commit("macfilter")
					LuciUci:save("macfilter")
					LuciUtil.exec("iptables -I FORWARD -m mac --mac-source " .. curdevice.device_mac .. " -j DROP")
				elseif curdevice.device_op=="5" then
					if curdevice.device_name == nil or curdevice.device_mac == nil then
						result=seterrordata(result,ERROR_LIST["10011"])
						return result
					end
					if not commonFunc.checkmac(commonFunc.macFormat(curdevice.device_mac)) then
						result=seterrordata(result,ERROR_LIST["10012"])
						return result
					end
					local config_name = string.lower(string.gsub(curdevice.device_mac,"[:-]",""))
					local options = {["name"] = curdevice.device_name,["mac"] = curdevice.device_mac}
					LuciUci:delete("devnamelist", config_name)
					LuciUci:section("devnamelist", "machine", config_name, options)
					LuciUci:commit("devnamelist")
					LuciUci:save("devnamelist")	
				end
			end
		end
	end
	
	if setdatas.blackwhitemode ~= nil then
	    if setdatas.blackwhitemode == "0" or setdatas.blackwhitemode == "1" or setdatas.blackwhitemode == "2" then
			local ret = commonFunc.setblackwhitetable(setdatas.blackwhitemode,setdatas.blackdevlist,setdatas.whitedevlist)
			if ret ~= "0" then
				result=seterrordata(result,ERROR_LIST[ret])
			    return result
			end
        else
		    result=seterrordata(result,ERROR_LIST["10040"])
			return result
		end
	end
	
	if setdatas.redirecttype ~= nil then
	    --dmz and portforward  0:关闭  1：端口转发  2：DMZ
		local ret = commonFunc.setredirectinfo(setdatas.redirecttype, setdatas.redirectlist, setdatas.dmzip)
		if ret ~= "0" then
			result=seterrordata(result,ERROR_LIST[ret])
			return result
		end
	end
	
	if setdatas.urlfilterenable ~= nil then
	    if setdatas.urlfilteroptype == nil then
			--网址过滤  0：disable  1：enable
			local ret = commonFunc.seturlfilterinfo(setdatas.urlfilterenable, setdatas.urlfilterlist)
			if ret ~= "0" then
				result=seterrordata(result,ERROR_LIST[ret])
				return result
			end
		else
		    local ret = commonFunc.updateurlfilterinfo(setdatas.urlfilterenable, setdatas.urlfilteroptype, setdatas.urlfilterlist)
			if ret ~= "0" then
				result=seterrordata(result,ERROR_LIST[ret])
				return result
			end
		end
	end
	
	--if setdatas.maxdownspeed ~= nil and setdatas.maxupspeed ~= nil then
	--    commonFunc.setspeedinfo(setdatas.maxdownspeed,setdatas.maxupspeed)
	--end
	
	--if setdatas.qosenable ~= nil and setdatas.qostype ~= nil and setdatas.qosdevlist ~= nil then
	    --local ret = commonFunc.setqosinfo(setdatas.qosenable, setdatas.qostype, setdatas.qosdevlist)
		--if ret ~= "0" then
		--	result=seterrordata(result,ERROR_LIST[ret])
		--	return result,""
		--end
	--end
	
	local have5Gflag = wifisetting.wifi_5G_exist()
	if setdatas.wifi ~= nil and type(setdatas.wifi) == "table" then
		local wfenable,wfssid,wfpwd,wfchannal,wfhiddenflag,wfencryption,wftxpwr,wfguest = nil,nil,nil,nil,nil,nil,nil,nil
		if havekey or initflag==0 then
			wfenable = setdatas.wifi.wifi_enable
			wfssid = setdatas.wifi.wifi_ssid
			wfpwd = setdatas.wifi.wifi_pwd
			wfencryption="mixed-psk"
		end
		if havekey then
			wfchannal=setdatas.wifi.wifi_channal
			wfhiddenflag = setdatas.wifi.wifi_hidden
			wftxpwr = setdatas.wifi.wifi_txpwr
			wfguest = setdatas.wifi.wifi_guest
		end
		
		local onlychannal = true
		if (not commonFunc.isStrNil(wfenable)) or (not commonFunc.isStrNil(wfssid))
		   or (not commonFunc.isStrNil(wfpwd)) or (not commonFunc.isStrNil(wfhiddenflag)) then
			restartnetwork=2
			onlychannal = false
		end
		
		if (not commonFunc.isStrNil(wfssid)) or (not commonFunc.isStrNil(wfpwd)) or (not commonFunc.isStrNil(wfencryption)) 
		    or (not commonFunc.isStrNil(wfchannal)) or (not commonFunc.isStrNil(wfhiddenflag)) or (not commonFunc.isStrNil(wfenable)) then
			if wifisetting.setWifiBasicInfo(1, wfssid, wfpwd, wfencryption, wfchannal, onlychannal, wfhiddenflag, wfenable)=="false" then
				result=seterrordata(result,ERROR_LIST["10020"])
				return result
			end
		end
		
		if not commonFunc.isStrNil(wftxpwr) then
		    wifisetting.setTxpwrMode(1,wftxpwr)
			commonFunc.settxptimemode(false)
			
			if have5Gflag then
			    wifisetting.setTxpwrMode(3,wftxpwr)
			    commonFunc.settxptimemode_5G(false)
			end
		end
		
		if setdatas.wifi.wifi_channal_nosave and havekey then
			local channal=setdatas.wifi.wifi_channal_nosave
			if tonumber(channal) >= 1 and tonumber(channal) <= 13 then
				LuciOS.execute(commonConf.SET_CHANNAL..tostring(tonumber(channal)).." >/dev/null 2>/dev/null & ")	
			elseif tonumber(channal) == 0 then
			    LuciOS.execute(commonConfig.SET_CHANNAL.."0 >/dev/null 2>/dev/null & ")
				LuciOS.execute("iwpriv ra0 set AutoChannelSel=2 >/dev/null 2>/dev/null & ")
			end
		end
		
		if setdatas.wifi.txptimingenable and havekey then
		    if (setdatas.wifi.txptimingenable=="true" or setdatas.wifi.txptimingenable==true)
			   and (commonFunc.isStrNil(setdatas.wifi.txpfullmode) or commonFunc.isStrNil(setdatas.wifi.txptimemode) or commonFunc.isStrNil(setdatas.wifi.txptime)) then
		       result=seterrordata(result,ERROR_LIST["10021"])
			   return result 
		    end
			if not commonFunc.settxptimemode(setdatas.wifi.txptimingenable,setdatas.wifi.txpfullmode,setdatas.wifi.txptimemode,setdatas.wifi.txptime) then
			   result=seterrordata(result,ERROR_LIST["10021"])
			   return result 
			end
			
			if have5Gflag then
			    if not commonFunc.settxptimemode_5G(setdatas.wifi.txptimingenable,setdatas.wifi.txpfullmode,setdatas.wifi.txptimemode,setdatas.wifi.txptime) then
				    result=seterrordata(result,ERROR_LIST["10021"])
				    return result 
			    end
			end
		end
		
		if (not commonFunc.isStrNil(wfguest)) and (wfguest=="0" or wfguest=="false") then
		    local oldguestmode=wifisetting.getGuestMode()
			if oldguestmode == "true" then
			    wifisetting.setGuestModeOff()
				guestcmdstr = commonFunc.resetwifidriver(false)
			    restartnetwork=2
			end
		elseif (not commonFunc.isStrNil(wfguest)) and (wfguest=="1" or wfguest=="true") then
			local oldguestmode=wifisetting.getGuestMode()
			if oldguestmode == "false" then
			    wifisetting.setGuestModeOn()
				guestcmdstr = commonFunc.resetwifidriver(true)
			    restartnetwork=2
			end
		end
	end
	
	if have5Gflag and setdatas.wifi_5G ~= nil and type(setdatas.wifi_5G) == "table" then
		local wfenable,wfssid,wfpwd,wfchannal,wfhiddenflag,wfencryption,wftxpwr = nil,nil,nil,nil,nil,nil,nil
		if havekey or initflag==0 then
			wfenable = setdatas.wifi_5G.wifi_enable
			wfssid = setdatas.wifi_5G.wifi_ssid
			wfpwd = setdatas.wifi_5G.wifi_pwd
			wfencryption="mixed-psk"
		end
		if havekey then
			wfchannal=setdatas.wifi_5G.wifi_channal
			wfhiddenflag = setdatas.wifi_5G.wifi_hidden
		end
		
		local onlychannal = true
		if (not commonFunc.isStrNil(wfenable)) or (not commonFunc.isStrNil(wfssid))
		   or (not commonFunc.isStrNil(wfpwd)) or (not commonFunc.isStrNil(wfhiddenflag)) then
			restartnetwork=2
			onlychannal = false
		end
		
		if (not commonFunc.isStrNil(wfssid)) or (not commonFunc.isStrNil(wfpwd)) or (not commonFunc.isStrNil(wfencryption)) 
		    or (not commonFunc.isStrNil(wfchannal)) or (not commonFunc.isStrNil(wfhiddenflag)) or (not commonFunc.isStrNil(wfenable)) then
			if wifisetting.setWifiBasicInfo(3, wfssid, wfpwd, wfencryption, wfchannal, onlychannal, wfhiddenflag, wfenable)=="false" then
				result=seterrordata(result,ERROR_LIST["10020"])
				return result
			end
		end
	end
	
	if setdatas.lan ~= nil and type(setdatas.lan) == "table" and havekey then
		if setdatas.lan.ipaddr then
			setUCI("network","lan","ipaddr",setdatas.lan.ipaddr)
			setUCI("network","lan","netmask",setdatas.lan.netmask)
			commonFunc.changeRouterDomain(setdatas.lan.ipaddr)
			LuciUci:save("network")
			LuciUci:commit("network")       
			reboot=true
		end
		
		if not commonFunc.isStrNil(setdatas.lan.dhcp_switch) then
			LuciUci:set("dhcp","lan","ignore",setdatas.lan.dhcp_switch)
			local dhcp_start_ip = setdatas.lan.dhcp_start_ip or "100"
			local dhcp_stop_ip = setdatas.lan.dhcp_stop_ip or "199"
			local dhcp_limit = tonumber(dhcp_stop_ip)-tonumber(dhcp_start_ip) + 1  
			if dhcp_limit < 1 then
				dhcp_limit = 255 - tonumber(dhcp_start_ip)
			end
			LuciUci:set("dhcp","lan","start",dhcp_start_ip)                                               
			LuciUci:set("dhcp","lan","limit",dhcp_limit)
			LuciUci:save("dhcp")
			LuciUci:commit("dhcp")           
			reboot=true
		end
		
		if not commonFunc.isStrNil(setdatas.lan.upnp) then
			LuciUci:set("upnpd","config","enable_upnp",setdatas.lan.upnp)
			LuciUci:commit("upnpd")
			LuciUci:save("upnpd")
			if setdatas.lan.upnp == '1' then
				LuciOS.execute("/etc/init.d/miniupnpd enable >/dev/null 2>/dev/null && /etc/init.d/miniupnpd start >/dev/null 2>/dev/null &")
			else
				LuciOS.execute("/etc/init.d/miniupnpd stop >/dev/null 2>/dev/null && /etc/init.d/miniupnpd disable >/dev/null 2>/dev/null &")
			end
		end
	end
	
	if setdatas.wan ~= nil and type(setdatas.wan) == "table" and (havekey or initflag==0) then
		local macchanged = false
		if not commonFunc.isStrNil(setdatas.wan.wan_mac) and setdatas.wan.wan_mac ~= "notclone" then 
			if setdatas.wan.wan_mac == "default" then
			    local initmac = commonFunc.getRouterInitMac()
				if initmac ~= "00:00:00:00:00:00" then
				    setUCI("network","wan","macaddr",initmac)
				else
				    LuciUci:delete("network","wan","macaddr")
				end
			else
				setUCI("network","wan","macaddr",setdatas.wan.wan_mac) 
			end
			macchanged = true
		end
		commonFunc.setWanclone(setdatas.wan.wanclone)
		
		if setdatas.wan.advance_switch then
		    commonFunc.setAdvanceSwitch(setdatas.wan.advance_switch)
		end
		
		setUCI("network","wan","ipaddr",setdatas.wan.wan_ipaddr)
		setUCI("network","wan","netmask",setdatas.wan.wan_netmask)
		setUCI("network","wan","gateway",setdatas.wan.wan_gateway)
		setUCI("network","wan","username",setdatas.wan.wan_username)
		if setdatas.wan.wan_password and setdatas.wan.wan_password ~= "youku********" then 
			setUCI("network","wan","password",setdatas.wan.wan_password) 
		end
		
		local wan_dns=""
		if not commonFunc.isStrNil(setdatas.wan.dns_switch) then 
			if setdatas.wan.dns_switch == "1" then
				wan_dns=LuciUtil.trim((setdatas.wan.dns1 or "").." "..(setdatas.wan.dns2 or ""))
				if wan_dns ~= "" then
					LuciUci:set("network","wan","peerdns",0)
					LuciUci:set("network","wan","dns",wan_dns)
					restartnetwork=3
					restartdnsmaq = true
				end
			else
			    local dnsflag = LuciUci:get("network","wan","peerdns")
				if dnsflag ~= nil then
					LuciUci:delete("network","wan","peerdns")
					LuciUci:delete("network","wan","dns")
					restartnetwork=3
					restartdnsmaq = true
				end
			end
		end
		
		if not commonFunc.isStrNil(setdatas.wan.proto) or not commonFunc.isStrNil(setdatas.wan.wan_proto) then 
		    local oldproto = LuciUci:get("network","wan","proto")
			local wanproto = setdatas.wan.proto or setdatas.wan.wan_proto
			setUCI("network","wan","proto",wanproto) 
			LuciUci:set("network","wan","timeout","10")
			if wanproto=="pppoe" then
				LuciUtil.exec("rm -rf "..commonFunc.getpppoelogpath())
				if restartnetwork == 0 then
					restartnetwork=1
				elseif restartnetwork == 2 then
					restartnetwork=3
				end
				restartdnsmaq = true
			elseif wanproto=="dhcp" and oldproto ~= "dhcp" then
					restartnetwork=3
			elseif wanproto=="static" then
				if wan_dns=="" then
					LuciUci:set("network","wan","dns",LuciUci:get("network","wan","gateway") or "")
				end
				restartnetwork=3
				restartdnsmaq = true
			else
			    if macchanged then
				    restartnetwork=3
				end
			end
		end
		
		if not commonFunc.isStrNil(setdatas.wan.mtu) then 
			LuciUci:set("network","wan","mtu",setdatas.wan.mtu) 
			if restartnetwork <= 1 then restartnetwork=1 end
		end
		LuciUci:save("network")
		LuciUci:commit("network")
	end
	
	local networkcache = _getRouterInfo("network",true,"app")
    writenetworkfile(networkcache.data)
	
	if reboot then
		retdata.mode=2
		LuciOS.execute("nohup "..commonConf.FORK_RESTART_ROUTER.." >/dev/null 2>/dev/null")
	elseif relogin then
		retdata.mode=3
	elseif restartnetwork ~= 0 then
		local executestr="sleep 2 && "
		if restartnetwork==1 then
		   retdata.mode=0
		   executestr = "ifup wan >/dev/null 2>/dev/null "
		elseif restartnetwork==2 then
		    if guestcmdstr ~= "" then
		        executestr = executestr..guestcmdstr
			else
			    executestr = executestr.."wifi downup >/dev/null 2>/dev/null "
			end
		    retdata.mode=1
		elseif restartnetwork==3 then
		   executestr = executestr.."/etc/init.d/network restart >/dev/null 2>/dev/null "
		   retdata.mode=1
		end
		
		if restartdnsmaq then
			 executestr = executestr.."&& /etc/init.d/dnsmasq restart >/dev/null 2>/dev/null "
		end
		LuciOS.execute("nohup "..executestr.."& >/dev/null 2>/dev/null")
	elseif restartdnsmaq then
	    retdata.mode=0
		LuciOS.execute("nohup /etc/init.d/dnsmasq restart >/dev/null 2>/dev/null & >/dev/null 2>/dev/null")
	end
	result.data=retdata
	
    return result
end

function setUCI(filename, option, key, value)
    if value then return LuciUci:set(filename,option,key,value) end
end

function upgrade(paramcon)
    local result={result=0,data=nil,error=nil}
	
	if commonFunc.isStrNil(paramcon) then
	    result=seterrordata(result,ERROR_LIST["4032"])
		return result
	end
	
	if paramcon=="check" then
	    local updatedata = LuciUtil.exec(commonConf.CHECK_UPGRADE)
		local chkdata = {hasupdate="0"} 
        local updateinfo = json.decode(updatedata)     
        if updateinfo ~= nil and updateinfo["list"]["firmware"] ~= nil and updateinfo["list"]["firmware"]["level"] ~= "force" then
            chkdata["hasupdate"] = "1" 
            chkdata["newver"] = string.gsub(updateinfo["list"]["firmware"]["online_version"],"\"","")
            chkdata["size"] = commonFunc.byteFormat(tonumber(updateinfo["list"]["firmware"]["size"]))
			local updatereference = string.gsub(updateinfo["list"]["firmware"]["notify_message"],"\"","")
			chkdata["desc"] = updatereference
            chkdata["descforweb"] = commonFunc.parseEnter2br(updatereference)
			
			chkdata["popup"] = "info"
			if updateinfo["list"]["firmware"]["popup"] ~= nil and updateinfo["list"]["firmware"]["popup"] == "force" then
			    chkdata["popup"] = "force"
			end
        end
		chkdata["curver"] = commonFunc.getyoukuvertion()
		chkdata["checkupdatetime"]=commonFunc.checkUpdatetime()
		result.data = chkdata
	elseif paramcon=="start" then
	    local LuciFs = require("luci.fs")
		if LuciFs.stat(commonConf.ROM_BIN_FILE) then
		    local check = LuciUtil.exec(commonConf.VERIFY_IMAGE)
			result.result = 0
			if check ~= "" then
				result=seterrordata(result,ERROR_LIST["10030"])
			elseif not LuciFs.access(commonConf.ROM_BIN_FILE) then
				result=seterrordata(result,ERROR_LIST["10030"])
			end
			
			if result.result == 0 then
				LuciUtil.exec(commonConf.FLASH_IMAGE)
			else
			    LuciFs.unlink(commonConf.ROM_BIN_FILE)
			end
		else
		    local updatedata = LuciUtil.exec(commonConf.CHECK_UPGRADE)
			local updateinfo = json.decode(updatedata)     
            if updateinfo ~= nil and updateinfo["list"]["firmware"] ~= nil and updateinfo["list"]["firmware"]["level"] ~= "force" then
			    result.result = LuciOS.execute(commonConf.DO_UPGRADE)
			else
				result=seterrordata(result,ERROR_LIST["10031"])
			end 
		end
	elseif paramcon=="checkimage" then
	    local LuciFs = require("luci.fs")
		if LuciFs.stat(commonConf.ROM_BIN_FILE) then
		    local check = LuciUtil.exec(commonConf.VERIFY_IMAGE)
			result.result = 0
			if check ~= "" then
				result=seterrordata(result,ERROR_LIST["10030"])
			elseif not LuciFs.access(commonConf.ROM_BIN_FILE) then
				result=seterrordata(result,ERROR_LIST["10030"])
			end
			
			if result.result ~= 0 then
			    LuciFs.unlink(commonConf.ROM_BIN_FILE)
			end
		end
	elseif paramcon=="progress" then
	    local prodata = {persent=0}
        local progress = commonFunc.getupgradestatus()
		if progress == "-1" then
			result=seterrordata(result,ERROR_LIST["10032"])
		elseif progress == "-2" then
			result=seterrordata(result,ERROR_LIST["10030"])
		else
			prodata["persent"] = progress
			result.data = prodata
		end
	else
		result=seterrordata(result,ERROR_LIST["4032"])
	end
    
	return result
end

function upload(paramcon)
    local result={result=0,data=nil,error=nil}
	
	if commonFunc.isStrNil(paramcon) then
	    result=seterrordata(result,ERROR_LIST["4032"])
		return result
	end
	
	if paramcon=="firmware" then
		if luci.http.context.request then
			local LuciSys = require("luci.sys")
			local LuciFs = require("luci.fs")
			local fp = nil
			local nixio = require("nixio")

			if _check_canupload() then
				luci.http.setfilehandler(
				function(meta, chunk, eof)
					if not fp then
						if meta and meta.name == "image" then
							fp = nixio.open(commonConf.ROM_BIN_FILE, "w+")
						end
					end
					if chunk then fp:write(chunk) end
					if eof then fp:close() end
				end)
			else
				result=seterrordata(result,ERROR_LIST["10033"])
			end

			if luci.http.formvalue("image") and fp then
				result.result = 0
			else
				result=seterrordata(result,ERROR_LIST["10031"])
			end	
		else
			result=seterrordata(result,ERROR_LIST["10034"])
		end
	else
	    result=seterrordata(result,ERROR_LIST["4032"])
	end
	return result
end

function testspeed(paramcon)
    local result={result=0,data=nil,error=nil}
	
	if commonFunc.isStrNil(paramcon) then
	    result=seterrordata(result,ERROR_LIST["4032"])
		return result
	end
	
	if paramcon=="start" then
        result.result = commonFunc.startspeedtest()
	elseif paramcon=="check" then
	    result.result,result.data = commonFunc.checkspeedinfo()
	else
		result=seterrordata(result,ERROR_LIST["4032"])
	end
	return result
end

function doextend(params)
    local result={result=0,data=nil,error=nil}
	
	if commonFunc.isStrNil(params.context) then
	    result=seterrordata(result,ERROR_LIST["4032"])
		return result
	end
	
	if params.context == "activate" then
	    if commonFunc.checkActivateEnable() then
		    local ret = commonFunc.activateEnable(params.key)
			if ret ~= "0" then
			    result=seterrordata(result,ERROR_LIST[ret])
			end
		else
		    result=seterrordata(result,ERROR_LIST["4035"])
		end
	else
	    result=seterrordata(result,ERROR_LIST["4032"])
	end
    return result
end

function _check_canupload()
    local LuciHttp = require "luci.http"
    local canupload = false
    local bin_file = ""
    local fileSize = tonumber(LuciHttp.getenv("CONTENT_LENGTH"))
    local tmp_available = commonFunc.checkTmpDiskSpace(fileSize)
    if tmp_available then
        canupload = true
    else
        local disk_available = commonFunc.checkDiskSpace(fileSize)
        if disk_available then
            local link = commonFunc.exec(CommonConf.LINK_ROM_BIN_FILE)
            if link then
                canupload = true
            end
        end
    end
    return canupload
end

function manage(paramcon)
    local result={result=0,data=nil,error=nil}
	if paramcon == nil or paramcon == "" then
	    result=seterrordata(result,ERROR_LIST["4032"])
		return result
	end
	
	if paramcon=="clearfirmware" then
	    local LuciFs = require("luci.fs")
		if LuciFs.stat(commonConf.ROM_BIN_FILE) then
		    LuciUtil.exec(commonConf.DELETE_IMAGE)
		end
	else
	    result=seterrordata(result,ERROR_LIST["4032"])
	end
	return result
end

function reboot()
    local result={result=0}
    LuciOS.execute("nohup "..commonConf.FORK_RESTART_ROUTER)
	return result
end

function reset()
    local result={result=0}
    LuciOS.execute("nohup "..commonConf.FORK_RESET_ALL)
	return result
end

function pppoestop()
    local result={result=0,data=nil,error=nil}
    LuciUtil.exec("lua /usr/sbin/pppoe.lua down")
	return result
end

function seterrordata(result,errortbl)
    result.result=errortbl.code
	local errordata = {desc=""}
    errordata.desc = errortbl.desc
	result.error=errordata
	return result
end


