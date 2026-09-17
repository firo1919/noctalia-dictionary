--!nonstrict
-- Dictionary status bar widget for Noctalia.
-- Click to select any text on screen with slurp + grim, OCR with tesseract,
-- and instantly view/copy its offline dictionary definition.

local busy = false
local available = noctalia.commandExists("grim")
  and noctalia.commandExists("slurp")
  and noctalia.commandExists("tesseract")
  and noctalia.commandExists("python3")

local function getLookupScriptPath()
  return noctalia.pluginDir() .. "/lookup.py"
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
  elseif busy then
    barWidget.setTooltip(noctalia.tr("widget.capturing"))
    barWidget.render(container({
      align = "center",
      gap = 4,
      onClick = function()
        noctalia.togglePanel("firomsa/dictionary:panel")
      end,
    }, {
      ui.glyph({ name = "crosshair", size = 15, color = "primary" }),
    }))
  else
    barWidget.setTooltip(noctalia.tr("widget.tooltip"))
    barWidget.render(container({
      align = "center",
      gap = 4,
      onClick = function()
        grabWord()
      end,
    }, {
      ui.glyph({ name = glyph, size = 15, color = "on_surface" }),
    }))
  end
end

local function handleResult(res)
  busy = false
  render()

  if res == nil or res.timedOut then
    return
  end
  if res.exitCode == 40 then
    -- Cancelled by user (Escape in slurp)
    return
  end
  if res.exitCode == 42 then
    noctalia.notifyError("Dictionary", "Screenshot capture failed (grim)")
    return
  end
  if res.exitCode == 43 then
    noctalia.notifyError("Dictionary", "OCR recognition failed (tesseract)")
    return
  end

  local stdout = res.stdout or ""
  if stdout == "" then
    return
  end

  local ok, data = pcall(noctalia.json.decode, stdout)
  if not ok or type(data) ~= "table" then
    noctalia.notifyError("Dictionary", "Failed to parse lookup response")
    return
  end

  -- Update shared state for the dictionary panel
  noctalia.state.set("dict_current", data)

  if data.found then
    local copyToClipboard = noctalia.getConfig("copy_to_clipboard") ~= false
    local showNotification = noctalia.getConfig("show_notification") ~= false
    local showPanel = noctalia.getConfig("show_panel_on_lookup") ~= false

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
end

function grabWord()
  if not available or busy then
    return
  end

  busy = true
  render()

  local psm = string.gsub(tostring(noctalia.getConfig("psm") or "6"), "%D", "")
  if psm == "" then
    psm = "6"
  end

  local scriptPath = getLookupScriptPath()

  local cmd = 'geom="$(slurp)" || exit 40; '
    .. 'img="$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/noctalia-dict-XXXXXX.png")" || exit 41; '
    .. 'trap \'rm -f "$img" 2>/dev/null\' EXIT; '
    .. 'grim -g "$geom" "$img" || exit 42; '
    .. 'txt="$(tesseract "$img" stdout -l eng --psm ' .. psm .. ' 2>/dev/null)" || exit 43; '
    .. 'python3 "' .. scriptPath .. '" "$txt"'

  if not noctalia.runAsync(cmd, handleResult, 60000) then
    busy = false
    render()
    noctalia.notifyError("Dictionary", "Failed to launch screen selection")
  end
end

function onClick()
  grabWord()
end

function onRightClick()
  noctalia.togglePanel("firomsa/dictionary:panel")
end

function onIpc(event, _payload)
  if event == "grab" then
    grabWord()
  end
end

render()
