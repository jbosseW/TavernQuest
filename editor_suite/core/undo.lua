local UndoStack = {}
UndoStack.__index = UndoStack

local DEFAULT_MAX_SIZE = 100
local COALESCE_WINDOW = 0.5

--- Create a new UndoStack instance.
-- @param maxSize  Maximum number of undo entries (default 100)
-- @return UndoStack
function UndoStack.new(maxSize)
    local self = setmetatable({}, UndoStack)
    self._maxSize = maxSize or DEFAULT_MAX_SIZE
    self._undoStack = {}
    self._redoStack = {}
    self._lastCoalesceId = nil
    self._lastCoalesceTime = 0
    return self
end

---------------------------------------------------------------------------
-- Internal helpers
---------------------------------------------------------------------------

--- Remove the oldest entries so the undo stack stays within maxSize.
local function trimStack(stack, maxSize)
    while #stack > maxSize do
        table.remove(stack, 1)
    end
end

--- Get a monotonic timestamp. Uses love.timer when available, falls back to
--- os.clock so the module can be unit-tested outside LOVE.
local function getTime()
    if love and love.timer then
        return love.timer.getTime()
    end
    return os.clock()
end

---------------------------------------------------------------------------
-- Core operations
---------------------------------------------------------------------------

--- Push a command onto the undo stack. The command is executed immediately
--- and the redo history is cleared.
--
-- A command table must contain:
--   execute()    - function that applies the change
--   undo()       - function that reverts the change
--   description  - human-readable string for UI display
--
-- @param command  Command table
function UndoStack:push(command)
    assert(command, "UndoStack:push() requires a command")
    assert(type(command.execute) == "function", "command.execute must be a function")
    assert(type(command.undo) == "function", "command.undo must be a function")

    command.execute()

    self._undoStack[#self._undoStack + 1] = command
    trimStack(self._undoStack, self._maxSize)

    -- Any new action invalidates the redo history
    self._redoStack = {}

    -- Reset coalesce state since this is a normal (non-coalesced) push
    self._lastCoalesceId = nil
    self._lastCoalesceTime = 0
end

--- Undo the most recent command.
-- @return true if an action was undone, false if nothing to undo
function UndoStack:undo()
    if #self._undoStack == 0 then
        return false
    end

    local command = table.remove(self._undoStack)
    command.undo()
    self._redoStack[#self._redoStack + 1] = command

    -- Reset coalesce state on manual undo
    self._lastCoalesceId = nil
    self._lastCoalesceTime = 0

    return true
end

--- Redo the most recently undone command.
-- @return true if an action was redone, false if nothing to redo
function UndoStack:redo()
    if #self._redoStack == 0 then
        return false
    end

    local command = table.remove(self._redoStack)
    command.execute()
    self._undoStack[#self._undoStack + 1] = command
    trimStack(self._undoStack, self._maxSize)

    -- Reset coalesce state on manual redo
    self._lastCoalesceId = nil
    self._lastCoalesceTime = 0

    return true
end

---------------------------------------------------------------------------
-- State queries
---------------------------------------------------------------------------

--- @return true if there is at least one action to undo
function UndoStack:canUndo()
    return #self._undoStack > 0
end

--- @return true if there is at least one action to redo
function UndoStack:canRedo()
    return #self._redoStack > 0
end

--- @return description string of the next undo action, or nil
function UndoStack:getUndoDescription()
    local top = self._undoStack[#self._undoStack]
    if top then
        return top.description
    end
    return nil
end

--- @return description string of the next redo action, or nil
function UndoStack:getRedoDescription()
    local top = self._redoStack[#self._redoStack]
    if top then
        return top.description
    end
    return nil
end

--- @return number of entries on the undo stack
function UndoStack:getUndoCount()
    return #self._undoStack
end

--- @return number of entries on the redo stack
function UndoStack:getRedoCount()
    return #self._redoStack
end

---------------------------------------------------------------------------
-- Clear
---------------------------------------------------------------------------

--- Reset the entire undo/redo history.
function UndoStack:clear()
    self._undoStack = {}
    self._redoStack = {}
    self._lastCoalesceId = nil
    self._lastCoalesceTime = 0
end

---------------------------------------------------------------------------
-- Coalescing  (stroke grouping for map painting, etc.)
---------------------------------------------------------------------------

--- Push a command that may be merged with the previous command if they share
--- the same groupId and arrive within the coalesce time window (0.5 s).
---
--- When coalescing occurs the top undo entry is replaced with a merged
--- command whose execute() replays both the old and new changes and whose
--- undo() reverts both in reverse order. The description is updated to the
--- newest command's description.
---
--- @param command  Command table (execute, undo, description)
--- @param groupId  Any comparable value identifying the stroke/group
function UndoStack:coalesce(command, groupId)
    assert(command, "UndoStack:coalesce() requires a command")
    assert(type(command.execute) == "function", "command.execute must be a function")
    assert(type(command.undo) == "function", "command.undo must be a function")
    assert(groupId ~= nil, "UndoStack:coalesce() requires a groupId")

    local now = getTime()

    -- Determine whether we should merge with the top of the undo stack
    local shouldMerge = (
        self._lastCoalesceId == groupId
        and (now - self._lastCoalesceTime) <= COALESCE_WINDOW
        and #self._undoStack > 0
    )

    if shouldMerge then
        -- Execute the new command
        command.execute()

        -- Pop the existing coalesced entry and wrap both together
        local previous = table.remove(self._undoStack)

        local merged = {
            description = command.description,
            execute = function()
                previous.execute()
                command.execute()
            end,
            undo = function()
                command.undo()
                previous.undo()
            end,
        }

        self._undoStack[#self._undoStack + 1] = merged
        -- Redo stack was already cleared on the first push of this group;
        -- no need to clear again.
    else
        -- First command in a new coalesce group -- treat as a normal push
        command.execute()
        self._undoStack[#self._undoStack + 1] = command
        trimStack(self._undoStack, self._maxSize)
        self._redoStack = {}
    end

    self._lastCoalesceId = groupId
    self._lastCoalesceTime = now
end

---------------------------------------------------------------------------
-- Batch  (group multiple commands into one undoable action)
---------------------------------------------------------------------------

--- Execute a list of commands atomically and record them as a single undo
--- entry. If any command's execute() errors, all previously executed
--- commands in the batch are undone in reverse order and the error is
--- re-raised.
---
--- @param commands    Array of command tables
--- @param description Optional description override; defaults to the first
---                    command's description with " (batch)" appended
function UndoStack:batch(commands, description)
    assert(type(commands) == "table", "UndoStack:batch() requires a table of commands")
    assert(#commands > 0, "UndoStack:batch() requires at least one command")

    for i, cmd in ipairs(commands) do
        assert(type(cmd.execute) == "function",
            "command[" .. i .. "].execute must be a function")
        assert(type(cmd.undo) == "function",
            "command[" .. i .. "].undo must be a function")
    end

    -- Build a snapshot of the commands list so external mutation cannot
    -- affect undo/redo behaviour later.
    local snapshot = {}
    for i, cmd in ipairs(commands) do
        snapshot[i] = cmd
    end

    -- Execute all commands in order; roll back on failure
    local executed = 0
    for i = 1, #snapshot do
        local ok, err = pcall(snapshot[i].execute)
        if not ok then
            -- Roll back everything that already executed, in reverse
            for j = i - 1, 1, -1 do
                pcall(snapshot[j].undo)
            end
            error("UndoStack:batch() failed at command " .. i .. ": " .. tostring(err), 2)
        end
        executed = executed + 1
    end

    local desc = description
        or ((snapshot[1].description or "action") .. " (batch)")

    local batchCommand = {
        description = desc,
        execute = function()
            for i = 1, #snapshot do
                snapshot[i].execute()
            end
        end,
        undo = function()
            for i = #snapshot, 1, -1 do
                snapshot[i].undo()
            end
        end,
    }

    self._undoStack[#self._undoStack + 1] = batchCommand
    trimStack(self._undoStack, self._maxSize)
    self._redoStack = {}

    -- Reset coalesce state
    self._lastCoalesceId = nil
    self._lastCoalesceTime = 0
end

return UndoStack
