module ("luci.youkucloud.config", package.seeall)

ROUTER_QQ = "260055936"
ROUTER_WX = ""
ROUTER_HOTLINE = "400-805-8811"
YOUKU_LUCI_VER = "1.0.0.1"
YOUKU_APP_DOWNLOAD_URL = "http://pcdnapi.youku.com/pcdn/entry/index?from=app_download"
YOUKU_ROUTE_BASE_URL = "http://pcdnapi.youku.com/pcdn/entry/index?"
YOUKU_ROUTE_BBS_URL = "http://pcdnapi.youku.com/pcdn/entry/index?from=bbs"
YOUKU_ROUTE_BIND_URL = "http://pcdnapi.youku.com/pcdn/entry/index?from=bind"
YOUKU_ROUTE_REBIND_URL = "http://pcdnapi.youku.com/pcdn/entry/index?from=rebind"
YOUKU_ROUTE_CREDITS_URL = "http://pcdnapi.youku.com/pcdn/entry/index?from=credits"
YOUKU_ROUTE_OFFICIAL_URL = "http://pcdnapi.youku.com/pcdn/entry/index?from=official"
YOUKU_ROUTE_YOUGOLD_URL = "http://pcdnapi.youku.com/pcdn/entry/index?from=yougold"

GET_ROUTER_VERSION = "cat /etc/youku/build/firmware | tr -d '\n'"
ROUTER_FRAMWORK_IDINFO = "http://127.0.0.1:12701/idinfo"
ROUTER_FRAMWORK_TOKEN = "http://127.0.0.1:12701/token"
DESKTOP_BINDUSER_URL = "http://pcdnapi.youku.com/pcdn/user/bind_account_v2"
DESKTOP_UNBINDUSER_URL = "http://pcdnapi.youku.com/pcdn/user/unbind_account_v2"
DESKTOP_GETCREDIT_SUMMARY_URL = "http://pcdnapi.youku.com/pcdn/credit/summary"
DESKTOP_GETCREDIT_DETAIL_URL = "http://pcdnapi.youku.com/pcdn/credit/detail"
DESKTOP_CHECKBIND_URL = "http://pcdnapi.youku.com/pcdn/user/check_bindinfo?pid="
ACC_GETUPLOAD_URL = "http://127.0.0.1:8908/peer/limit/network/get"
ACC_SETUPLOAD_URL = "http://127.0.0.1:8908/peer/limit/network/set?upload_model="
ACC_GETRATE_URL = "http://127.0.0.1:8908/peer/command/net_speed"
ACC_CHECK_CONF = "/usr/sbin/check_svc.sh check accstatus"
TXP_CHECK_CONF = "/usr/sbin/check_svc.sh check txpower"
SN_YOUKU_EXEC = "sn_youku r | tr -d '\n'"
SN_YOUKU_EXEC_CRYPT = "cat /etc/youku/idinfo | tr -d '\n'"

FORK_RESTART_WIFI = "wifi downup & >/dev/null 2>/dev/null"
FORK_RESET_ALL = "sleep 2 && jffs2reset -y && reboot & >/dev/null 2>/dev/null"
FORK_RESTART_ROUTER = "sleep 2 && reboot & >/dev/null 2>/dev/null"
FORK_RESTART_DNSMASQ = "/etc/init.d/dnsmasq restart >/dev/null 2>/dev/null"
FORK_RESET_DATACEACH = "lua check_luci.lua 1 & "
RESTART_MAC_FILTER = "/bin/sh /etc/firewall.macfilter"
RESTART_GUEST_MODE = "/etc/init.d/network restart && sleep 1 && /etc/init.d/dnsmasq restart & >/dev/null 2>/dev/null"
GUEST_MODE_UP = "wifi downup & >/dev/null 2>/dev/null"
GUEST_MODE_DOWN = "wifi downup & >/dev/null 2>/dev/null"

SET_TXPWR = "iwpriv ra0 set TxPower="
SET_SSID = "iwpriv ra0 set SSID="
SET_CHANNAL = "iwpriv ra0 set Channel="

SET_TXPWR_5G = "iwpriv rai0 set TxPower="
SET_SSID_5G = "iwpriv rai0 set SSID="
SET_CHANNAL_5G = "iwpriv rai0 set Channel="

CHECK_UPGRADE = "updater 2>/dev/null"
DO_UPGRADE = "rm -rf /tmp/updater_persent && nohup updater 1 >/tmp/updater_persent 2>/dev/null &"
GET_DOWNLOADFILE_STATUS = "tail -n 20 /tmp/updater_persent"

ROM_BIN_FILE = "/tmp/image.bin"
VERIFY_IMAGE = "sysupgrade -T "..ROM_BIN_FILE
FLASH_IMAGE = "sleep 2 && sysupgrade "..ROM_BIN_FILE.." &"
CHECK_TMPDISK = [[df -k | grep /tmp$ | awk '{print $4}']]
CHECK_DISK = [[df -k | grep /tmp/youku/mnt/tf0$ | awk '{print $4}']]
DISK_BIN_DIR = "/tmp/youku/mnt/tf0/tmp/"
LINK_ROM_BIN_FILE = "[ -d "..DISK_BIN_DIR.." ] && touch "..DISK_BIN_DIR.."image.bin && ln -fs "..DISK_BIN_DIR.."image.bin /tmp/image.bin"
DELETE_IMAGE = "rm -rf "..ROM_BIN_FILE

DELETE_ROOT_PWD = "passwd -d root"

NETMON_LOG_FILE = "/tmp/youku/stat/netmon.log"

-- DHCP lease file
DHCP_LEASE_FILEPATH = "/var/dhcp.leases"
PPPOE_LOGFILE = "/tmp/log/pppoe.log"

-- DHCP deny list file
DHCP_DENYLIST_FILEPATH = "/etc/config/firewall.mac.list"

-- MAC table file path
MACTABLE_FILEPATH = "/etc/youku/mactable"

-- Wan status
GET_WAN_DEV = "ip route list 0/0"
GET_CPU_CHIPPKG = "cat /proc/cpuinfo | grep b_chippkg"

-- UPnP
UPNP_STATUS = "/etc/init.d/miniupnpd enabled"
UPNP_ENABLE = "/etc/init.d/miniupnpd enable && /etc/init.d/miniupnpd start &"
UPNP_DISABLE = "/etc/init.d/miniupnpd stop && /etc/init.d/miniupnpd disable &"
UPNP_LEASE_FILE = "uci get upnpd.config.upnp_lease_file"

--txpower
TXPOWER_GREEN=60
TXPOWER_BASE=80
TXPOWER_STRONG=100

--change domain
CHANGE_DOMAIN_IP = "uci delete dhcp.@dnsmasq[0].address && uci add_list dhcp.@dnsmasq[0].address='/wifi.youku.com/$s' && uci commit dhcp &"
GET_DOMAIN_IP = "uci get dhcp.@dnsmasq[0].address | tr -d '\n'"

--black white table
SET_ACLPOLICY_RA0 = "iwpriv ra0 set AccessPolicy="
SET_ACLPOLICY_RA1 = "iwpriv ra1 set AccessPolicy="
SET_ACLPOLICY_RAI0 = "iwpriv rai0 set AccessPolicy="
ADD_ACL_MACLIST_RA0 = "iwpriv ra0 set ACLAddEntry="
ADD_ACL_MACLIST_RA1 = "iwpriv ra1 set ACLAddEntry="
ADD_ACL_MACLIST_RAI0 = "iwpriv rai0 set ACLAddEntry="
CLEAR_ACL_MACLIST_RA0 = "iwpriv ra0 set ACLClearAll=1"
CLEAR_ACL_MACLIST_RA1 = "iwpriv ra1 set ACLClearAll=1"
CLEAR_ACL_MACLIST_RAI0 = "iwpriv rai0 set ACLClearAll=1"

URLFILTER_ENABLE = "insmod /lib/modules/2.6.36/url-filter.ko"
URLFILTER_DISBLE = "rmmod /lib/modules/2.6.36/url-filter.ko"
URLFILTER_FILEPATH = "/etc/youku/url_file"
URLFILTER_ADDCOMMAND = "read_url_file.sh"

SPEEDINFO_FILE = "/tmp/speed_test"
SPEEDTEST_START = "ubus call_pack netmon.netmon.speed '{\"type\":\"manu\"}'"
SPEEDTEST_CHECK = "tail -n 2 "..SPEEDINFO_FILE.." 2>/dev/null | grep 'progress:'"
SPEEDTEST_GETRET = "tail -n 1 "..SPEEDINFO_FILE.." 2>/dev/null"

QOS_CONFIGFILE = "/etc/qosconfig/qosinfo.conf"
QOS_STARTCMD = "qosconfig "..QOS_CONFIGFILE
