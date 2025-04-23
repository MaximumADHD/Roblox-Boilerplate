local UI = script:FindFirstAncestor("UI")
local React = require(UI.Common.React)

local function useTimer(framerate: number, callback: (dt: number) -> (), deps: { any }?)
    if deps then
        table.insert(deps, framerate)
    end

    React.useEffect(function ()
        local thread = task.spawn(function ()
            local interval = 1 / framerate
            local lastStep = os.clock() - interval

            while true do
                local now = os.clock()
                local dt = now - lastStep

                lastStep = now
                callback(dt)

                task.wait(interval)
            end
        end)

        return function ()
            task.cancel(thread)
        end
    end, deps)
end

return useTimer