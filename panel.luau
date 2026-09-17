--!nonstrict
-- Dictionary panel for Noctalia.
-- Shows offline definition card, manual search input, history, and text selection trigger.

local currentData = nil
local searchInput = ""
local history = {}
local copyStatus = "Copy"
local render

local function tr(key, args)
  return noctalia.tr(key, args)
end

local function getLookupScriptPath()
  return noctalia.pluginDir() .. "/lookup.py"
end

local function recordHistory(word)
  if not word or word == "" then
    return
  end
  for i, w in ipairs(history) do
    if w:lower() == word:lower() then
      table.remove(history, i)
      break
    end
  end
  table.insert(history, 1, word)
  if #history > 8 then
    table.remove(history)
  end
end

local function doSearch(query)
  local q = noctalia.string.trim(query or "")
  if q == "" then
    return
  end

  local scriptPath = getLookupScriptPath()
  local cmd = 'python3 "' .. scriptPath .. '" ' .. string.format("%q", q)

  noctalia.runAsync(cmd, function(res)
    if res and res.stdout and res.stdout ~= "" then
      local ok, data = pcall(noctalia.json.decode, res.stdout)
      if ok and type(data) == "table" then
        currentData = data
        copyStatus = tr("panel.btn_copy")
        if data.found and data.word then
          recordHistory(data.word)
        end
        render()
      end
    end
  end, 15000)
end

local function onCopyCurrent()
  if currentData and currentData.summary then
    noctalia.copyToClipboard(currentData.summary, "text/plain")
    copyStatus = tr("panel.btn_copied")
    render()
    noctalia.setTimeout(2000, function()
      copyStatus = tr("panel.btn_copy")
      render()
    end)
  end
end

local function triggerSelection()
  panel.close()
  noctalia.setTimeout(200, function()
    noctalia.sendIpc("firo1919/dictionary:widget", "grab")
  end)
end

function render()
  local children = {}

  -- Top Header
  table.insert(
    children,
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "vocabulary", size = 20, color = "primary" }),
      ui.label({
        text = tr("panel.title"),
        fontSize = 15,
        fontWeight = "bold",
        color = "on_surface",
        flexGrow = 1,
      }),
      ui.button({
        text = tr("panel.btn_grab"),
        glyph = "crosshair",
        variant = "ghost",
        onClick = triggerSelection,
      }),
    })
  )

  -- Search Row
  table.insert(
    children,
    ui.row({ gap = 6, align = "center" }, {
      ui.input({
        placeholder = tr("panel.search_placeholder"),
        value = searchInput,
        flexGrow = 1,
        onChange = function(val)
          searchInput = val
        end,
        onSubmit = function()
          doSearch(searchInput)
        end,
      }),
      ui.button({
        glyph = "search",
        variant = "primary",
        onClick = function()
          doSearch(searchInput)
        end,
      }),
    })
  )

  -- Content Area
  local contentItems = {}

  if currentData == nil then
    table.insert(
      contentItems,
      ui.row({ paddingV = 24, align = "center", justify = "center" }, {
        ui.label({
          text = tr("panel.no_word"),
          color = "on_surface_variant",
          fontSize = 12,
        }),
      })
    )
  elseif currentData.found then
    -- Word Header
    local headerChildren = {
      ui.label({
        text = currentData.word or "",
        fontSize = 22,
        fontWeight = "bold",
        color = "on_surface",
        flexGrow = 1,
      }),
    }
    if currentData.wordtype and currentData.wordtype ~= "" then
      table.insert(
        headerChildren,
        ui.label({
          text = currentData.wordtype,
          fontSize = 12,
          fontWeight = "bold",
          color = "primary",
        })
      )
    end
    table.insert(
      headerChildren,
      ui.button({
        text = copyStatus,
        glyph = "copy",
        variant = "ghost",
        onClick = onCopyCurrent,
      })
    )

    table.insert(contentItems, ui.row({ gap = 8, align = "center" }, headerChildren))
    table.insert(contentItems, ui.separator())

    -- Definitions List
    local defs = currentData.definitions or {}
    for idx, def in ipairs(defs) do
      table.insert(
        contentItems,
        ui.row({ gap = 8, align = "start" }, {
          ui.label({
            text = tostring(idx) .. ".",
            fontSize = 12,
            fontWeight = "bold",
            color = "primary",
          }),
          ui.label({
            text = def,
            fontSize = 12,
            color = "on_surface",
            flexGrow = 1,
          }),
        })
      )
    end
  else
    -- Not found
    table.insert(
      contentItems,
      ui.row({ gap = 6, align = "center" }, {
        ui.glyph({ name = "alert-circle", size = 16, color = "error" }),
        ui.label({
          text = currentData.error or "Word not found",
          color = "error",
          fontSize = 12,
          fontWeight = "bold",
        }),
      })
    )

    local suggs = currentData.suggestions or {}
    if #suggs > 0 then
      table.insert(contentItems, ui.label({
        text = tr("panel.suggestions_title"),
        fontSize = 11,
        color = "on_surface_variant",
      }))

      local chips = {}
      for _, s in ipairs(suggs) do
        table.insert(
          chips,
          ui.button({
            text = s,
            variant = "ghost",
            onClick = function()
              searchInput = s
              doSearch(s)
            end,
          })
        )
      end
      table.insert(contentItems, ui.row({ gap = 6, align = "center" }, chips))
    end
  end

  table.insert(
    children,
    ui.scroll({ flexGrow = 1, gap = 8 }, contentItems)
  )

  -- History Footer
  if #history > 0 then
    local historyChips = {
      ui.glyph({ name = "history", size = 13, color = "on_surface_variant" }),
    }
    for _, item in ipairs(history) do
      table.insert(
        historyChips,
        ui.button({
          text = item,
          variant = "ghost",
          fontSize = 10,
          onClick = function()
            searchInput = item
            doSearch(item)
          end,
        })
      )
    end
    table.insert(children, ui.row({ gap = 4, align = "center" }, historyChips))
  end

  panel.render(ui.column({ flexGrow = 1, gap = 10, align = "stretch" }, children))
end

function onOpen(_context)
  copyStatus = tr("panel.btn_copy")
  local stateData = noctalia.state.get("dict_current")
  if stateData and type(stateData) == "table" then
    currentData = stateData
    if stateData.found and stateData.word then
      recordHistory(stateData.word)
    end
  end
  render()
end

function onClose()
  copyStatus = "Copy"
end

noctalia.state.watch("dict_current", function(val)
  if val and type(val) == "table" then
    currentData = val
    copyStatus = tr("panel.btn_copy")
    if val.found and val.word then
      recordHistory(val.word)
    end
    render()
  end
end)

render()
