--!nonstrict
-- Dictionary status bar widget for Noctalia.
-- Workflow:
-- 1. Click the widget -> it arms waiting mode (pointer icon).
-- 2. Highlight any word on your screen with your mouse.
-- 3. It immediately captures the text, defines it offline, copies to clipboard, and shows definition.

local isWaiting = false
local available = noctalia.commandExists("wl-paste") and noctalia.commandExists("python3")

local function getScriptPath(scriptName)
  return noctalia.pluginDir() .. "/" .. scriptName
end

local function render()
  local glyph = noctalia.getConfig("glyph") or "vocabulary"
  local container = barWidget.isVertical() and ui.column or ui.row

  if not available then
    barWidget.setTooltip(noctalia.tr("widget.missing_deps"))
    barWidget.render(container({
      align = "center",
      gap = 4,
      onClick = function()
        noctalia.togglePanel("firomsa/dictionary:panel")
      end,
    }, {
      ui.glyph({ name = glyph, size = 15, color = "on_surface_variant" }),
    }))
  elseif isWaiting then
    barWidget.setTooltip(noctalia.tr("widget.capturing"))
    barWidget.render(container({
      align = "center",
      gap = 4,
      onClick = function()
        -- Click while waiting cancels waiting mode
        isWaiting = false
        render()
      end,
    }, {
      ui.glyph({ name = "pointer", size = 15, color = "primary" }),
    }))
  else
    barWidget.setTooltip(noctalia.tr("widget.tooltip"))
    barWidget.render(container({
      align = "center",
      gap = 4,
      onClick = function()
        startWaitingForSelection()
      end,
    }, {
      ui.glyph({ name = glyph, size = 15, color = "on_surface" }),
    }))
  end
end

local function processWord(wordText)
  local clean = noctalia.string.trim(wordText or "")
  if clean == "" then
    return
  end

  local scriptPath = getScriptPath("lookup.py")
  local cmd = 'python3 "' .. scriptPath .. '" ' .. string.format("%q", clean)

  noctalia.runAsync(cmd, function(res)
    local stdout = (res and res.stdout) or ""
    if stdout == "" then
      return
    end

    local ok, data = pcall(noctalia.json.decode, stdout)
    if not ok or type(data) ~= "table" then
      return
    end

    -- Update state for panel
    noctalia.state.set("dict_current", data)

    local copyToClipboard = noctalia.getConfig("copy_to_clipboard") ~= false
    local showNotification = noctalia.getConfig("show_notification") ~= false
    local showPanel = noctalia.getConfig("show_panel_on_lookup") ~= false

    if data.found then
      if copyToClipboard and data.summary then
        noctalia.copyToClipboard(data.summary, "text/plain")
      end

      if showNotification then
        local title = data.word
        if data.wordtype and data.wordtype ~= "" then
          title = title .. " (" .. data.wordtype .. ")"
        end
        local body = (data.definitions and data.definitions[1]) or ""
        noctalia.notify(title, body)
      end

      if showPanel then
        noctalia.togglePanel("firomsa/dictionary:panel")
      end
    else
      local err = data.error or ("No definition found for '" .. (data.word or "") .. "'")
      noctalia.notify("Dictionary", err)
      noctalia.togglePanel("firomsa/dictionary:panel")
    end

    -- Clear primary selection so it does not linger
    noctalia.runAsync("wl-copy -p -c")
  end, 15000)
end

function startWaitingForSelection()
  if not available then
    return
  end

  if isWaiting then
    isWaiting = false
    render()
    return
  end

  -- 1. Clear any old primary selection first
  noctalia.runAsync("wl-copy -p -c", function()
    -- 2. Transition to waiting mode
    isWaiting = true
    render()

    local timeoutSec = tonumber(noctalia.getConfig("selection_timeout_seconds")) or 20
    local watchScript = getScriptPath("watch_selection.py")
    local cmd = 'python3 "' .. watchScript .. '" ' .. tostring(timeoutSec)

    -- 3. Await user selection
    noctalia.runAsync(cmd, function(watchRes)
      if not isWaiting then
        return -- was cancelled by user
      end
      isWaiting = false
      render()

      if watchRes and watchRes.exitCode == 0 and watchRes.stdout and watchRes.stdout ~= "" then
        local selected = noctalia.string.trim(watchRes.stdout)
        if selected ~= "" then
          processWord(selected)
        end
      end
    end, (timeoutSec + 2) * 1000)
  end)
end

function onClick()
  startWaitingForSelection()
end

function onRightClick()
  noctalia.togglePanel("firomsa/dictionary:panel")
end

function onIpc(event, _payload)
  if event == "trigger" or event == "grab" then
    startWaitingForSelection()
  end
end

render()
