local DataStorage = require("datastorage")
local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage") -- luacheck:ignore
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local ffiutil = require("ffi/util")
local logger = require("logger")
local util = require("util")
local _ = require("gettext")

local path = DataStorage:getFullDataDir()
local binPath = path .. "/plugins/syncthing.koplugin/syncthing"
local dataPath = path .. "/settings/syncthing"
local logPath = path .. "/settings/syncthing/syncthing.log"
local pidFilePath = "/tmp/syncthing_koreader.pid"

if not util.pathExists(binPath) or os.execute("start-stop-daemon") == 127 then
    return { disabled = true, }
end

local Syncthing = WidgetContainer:extend {
    name = "Syncthing",
    is_doc_only = false,
}

function Syncthing:init()
    self.ui.menu:registerToMainMenu(self)
    self:onDispatcherRegisterActions()
end

function Syncthing:start()
    -- Since Syncthing doesn't start as a deamon by default and has no option to
    -- set a pidfile, we launch it using the start-stop-daemon helper. On Kobo,
    -- this command is provided by BusyBox:
    -- https://busybox.net/downloads/BusyBox.html#start_stop_daemon 
    -- The full version has slightly more options, but seems to be a superset of
    -- the BusyBox version, so it should also work with that:
    -- https://man.cx/start-stop-daemon(8)

    -- Use a pidfile to identify the process later, set --oknodo to not fail if
    -- the process is already running and set --background to start as a
    -- background process. On Syncthing itself, specify that it shouldn't open
    -- the browser, set the home directory (for configuration files) and a log
    -- file (which is rotated with max-size and max-old-files).
    local cmd = string.format(
        "start-stop-daemon --make-pidfile --pidfile %s -S --oknodo --background "
        .. "--exec %s -- --no-browser --home=%s "
        .. "--logfile=%s --log-max-size=1000 --log-max-old-files=1",
        pidFilePath,
        binPath,
        dataPath,
        logPath
    )

    -- Ensure that the home/data/configurations directory exists
    if not util.pathExists(dataPath) then
        os.execute("mkdir " .. dataPath)
    end

    -- Check if 127.0.0.1 is bound to the local loopback interface, which is not
    -- the case by default on Kobo. grep fails with exit code 1 if the IP is not
    -- found in the output.
    local checkLocalhostCmd = "/bin/sh -c 'ifconfig lo | grep 127.0.0.1'"
    logger.dbg("[Network] Check if 127.0.0.1 is bound to local loopback: ", checkLocalhostCmd)
    if os.execute(checkLocalhostCmd) ~= 0 then
        local configLocalhostCmd = "ifconfig lo 127.0.0.1"
        logger.info("[Network] Add 127.0.0.1 to local loopback interface: ", configLocalhostCmd)
        os.execute(configLocalhostCmd)
    end

    logger.dbg("[Syncthing] Launching Syncthing: ", cmd)

    local status = os.execute(cmd)
    if status == 0 then
        logger.dbg("[Syncthing] Syncthing started. Find Syncthing logs at ", logPath)
        local info = InfoMessage:new {
            timeout = 2,
            text = _("Syncthing started.")
        }
        UIManager:show(info)
    else
        logger.dbg("[Syncthing] Failed to start Syncthing, status: ", status)
        local info = InfoMessage:new {
            icon = "notice-warning",
            text = _("Failed to start Syncthing."),
        }
        UIManager:show(info)
    end
end

function Syncthing:isRunning()
    -- Use start-stop-daemon -K (to stop a process) in --test mode to find if
    -- there are any matching processes for this pidfile and executable. If
    -- there are any matching processes, this exits with status code 0.
    local cmd = string.format(
        "start-stop-daemon --pidfile %s --exec %s -K --test",
        pidFilePath,
        binPath
    )

    logger.dbg("[Syncthing] Check if Syncthing is running: ", cmd)
    
    local status = os.execute(cmd)

    logger.dbg("[Syncthing] Running status exit code (0 -> running): ", status)

    return status == 0
end

function Syncthing:stop()
    -- Use start-stop-daemon -K to stop the process, with --oknodo to exit with
    -- status code 0 if there are no matching processes in the first place.
    local cmd = string.format(
        "start-stop-daemon --pidfile %s --exec %s --oknodo -K",
        pidFilePath,
        binPath
    )

    logger.dbg("[Syncthing] Stopping Syncthing: ", cmd)

    local status = os.execute(cmd)
    if status == 0 then
        logger.dbg("[Syncthing] Syncthing stopped.")

        UIManager:show(InfoMessage:new {
            text = _("Syncthing stopped."),
            timeout = 2,
        })

        if util.pathExists(pidFilePath) then
            logger.dbg("[Syncthing] Removing PID file at ", pidFilePath)
            os.remove(pidFilePath)
        end
    else
        logger.dbg("[Syncthing] Failed to stop Syncthing, status: ", status)

        UIManager:show(InfoMessage:new {
            icon = "notice-warning",
            text = _("Failed to stop Syncthing.")
        })
    end  
end

function Syncthing:onToggleSyncthing()
    if self:isRunning() then
        self:stop()
    else
        self:start()
    end
end

function Syncthing:addToMainMenu(menu_items)
    menu_items.syncthing = {
        text = _("Syncthing"),
        sorting_hint = "network",
        keep_menu_open = true,
        checked_func = function() return self:isRunning() end,
        callback = function(touchmenu_instance)
            self:onToggleSyncthing()
            -- sleeping might not be needed, but it gives the feeling
            -- something has been done and feedback is accurate
            ffiutil.sleep(1)
            touchmenu_instance:updateItems()
        end,
    }
end

function Syncthing:onDispatcherRegisterActions()
    Dispatcher:registerAction("toggle_syncthing",
        { category = "none", event = "ToggleSyncthing", title = _("Toggle Syncthing"), general = true })
end

return Syncthing
