--!nonstrict
-- Dictionary status bar widget for Noctalia.
-- Implements the selection flow from omarchy-lookup:
-- If text is highlighted or copied, clicking the widget looks it up immediately.
-- If nothing is selected, clicking toggles the search panel to type in.

local busy = false
local available = noctalia.commandExists("wl-paste") and noctalia.commandExists("python3")

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
        noctalia.togglePanel("firo1919/dictionary:panel")
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
        noctalia.togglePanel("firo1919/dictionary:panel")
      end,
    }, {
      ui.glyph({ name = "search", size = 15, color = "primary" }),
    }))
  else
    barWidget.setTooltip(noctalia.tr("widget.tooltip"))
    barWidget.render(container({
      align = "center",
      gap = 4,
      onClick = function()
        handleLookupTrigger()
      end,
    }, {
      ui.glyph({ name = glyph, size = 15, color = "on_surface" }),
    }))
  end
end

local function processLookup(query)
  local q = noctalia.string.trim(query or "")
  if q == "" then
    noctalia.togglePanel("firo1919/dictionary:panel")
    return
  end

  busy = true
  render()

  local scriptPath = getLookupScriptPath()
  local cmd = 'python3 "' .. scriptPath .. '" ' .. string.format("%q", q)

  noctalia.runAsync(cmd, function(res)
    busy = false
    render()

    local stdout = (res and res.stdout) or ""
    if stdout == "" then
      noctalia.togglePanel("firo1919/dictionary:panel")
      return
    end

    local ok, data = pcall(noctalia.json.decode, stdout)
    if not ok or type(data) ~= "table" then
      noctalia.togglePanel("firo1919/dictionary:panel")
      return
    end

    -- Update shared state for panel
    noctalia.state.set("dict_current", data)

    local copyToClipboard = noctalia.getConfig("copy_to_clipboard") ~= false
    local showNotification = noctalia.getConfig("show_notification") ~= false
    local showPanel = noctalia.getConfig("show_panel_on_lookup") ~= false

    if data.found then
      if copyToClipboard and data.summary then
        noctalia.copyToClipboard(data.summary, "text/plain")
      end

      if showNotification then
        local title = data.word or q
        if data.wordtype and data.wordtype ~= "" then
          title = title .. " (" .. data.wordtype .. ")"
        end
        local body = (data.definitions and data.definitions[1]) or ""
        noctalia.notify(title, body)
      end

      if showPanel then
        noctalia.togglePanel("firo1919/dictionary:panel")
      end
    else
      local err = data.error or ("No definition found for '" .. (data.word or q) .. "'")
      noctalia.notify("Dictionary", err)
      noctalia.togglePanel("firo1919/dictionary:panel")
    end
  end, 15000)
end

function handleLookupTrigger()
  if not available or busy then
    return
  end

  -- Grab primary selection with size-cap and whitespace normalization
  -- Fall back to regular clipboard if primary is empty (e.g. copied with Ctrl+C in Chromium/Helium)
  local cmd = 'sel="$(wl-paste --primary --no-newline --type text/plain 2>/dev/null | head -c 400 || true)"; '
    .. '[ -n "$sel" ] || sel="$(wl-paste --primary --no-newline 2>/dev/null | head -c 400 || true)"; '
    .. 'if [ -z "$sel" ]; then '
    .. '  clip="$(wl-paste --no-newline 2>/dev/null | head -c 120 || true)"; '
    .. '  [ "${#clip}" -lt 80 ] && sel="$clip"; '
    .. 'fi; '
    .. 'printf "%s" "$sel" | tr "\\n\\t" "  " | sed -e "s/^ *//" -e "s/ *$//"'

  noctalia.runAsync(cmd, function(res)
    local selection = noctalia.string.trim((res and res.stdout) or "")
    if selection ~= "" then
      processLookup(selection)
    else
      -- Nothing selected or copied: toggle panel directly to type in
      noctalia.togglePanel("firo1919/dictionary:panel")
    end
  end, 2000)
end

function onClick()
  handleLookupTrigger()
end

function onRightClick()
  noctalia.togglePanel("firo1919/dictionary:panel")
end

function onIpc(event, payload)
  if event == "lookup" or event == "trigger" then
    if payload and type(payload) == "string" and payload ~= "" then
      processLookup(payload)
    else
      handleLookupTrigger()
    end
  end
end

render()
