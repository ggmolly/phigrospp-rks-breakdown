-- rks breakdown: a tap on the RKS of the song list's player bar shows what it's made of. the game adds the RKS of the
-- player's 27 best charts to the ones of their 3 best all perfect charts (counted twice then) and divides by 30

local UE = CS.UnityEngine
local ui = phigrospp.ui
local NAME = "rks-breakdown"
local V = ui.view(NAME)
local C = ui.colours
local SLOPE = CS.SettingItemsManager.InverseSlope -- the game's slant: sideways per unit of height
local BEST, PHI, NEXT = 27, 3, 10 -- the charts counted, and how many of the ones after them show
local ROW, STEP, HEADER = 96, 108, 76 -- a chart's row, from a row to the next, and a section's title
local ART = 170 -- a row's cover, wide
local WIDE, SUMS = 1300, 520 -- a row at most, and the sums left of the first one
local CARD, BAND, GAP = { 260, 172 }, 100, 12 -- a card of the grid, its texts' band, and between two cards
local TITLES = { "RKS breakdown", "All 30 charts" }
local SHADE, BLUE = { 0, 0, 0, 0.94 }, { 0.45, 0.75, 1, 1 }

local shown = TITLES[1] -- the screen the player last looked at

-- a record's RKS: the chart's constant at 100%, nothing under 70%
local function worth(accuracy, constant)
  return accuracy < 70 and 0 or constant * (math.min(accuracy, 100) - 55) ^ 2 / 2025
end

local function sum(charts)
  local total = 0
  for _, chart in ipairs(charts) do total = total + chart.rks end
  return total
end

-- the player's charts by RKS: { best =, phi =, next = the ones that would count after the best }
local function breakdown()
  local charts = {}
  for _, r in ipairs(records()) do
    local s = song(r.id)
    local constant = s.charts[r.difficulty].constant
    charts[#charts + 1] = { id = r.id, name = s.name, level = r.difficulty, constant = constant, accuracy = r.accuracy,
      score = r.score, grade = grade(r.score, r.fc), fc = r.fc, rks = worth(r.accuracy, constant) }
  end
  table.sort(charts, function(a, b)
    if a.rks ~= b.rks then return a.rks > b.rks end
    return a.name < b.name
  end)
  local b = { best = {}, phi = {}, next = {} }
  for i, chart in ipairs(charts) do
    if chart.accuracy >= 100 and #b.phi < PHI then b.phi[#b.phi + 1] = chart end
    if i <= BEST then b.best[i] = chart elseif i <= BEST + NEXT then b.next[#b.next + 1] = chart end
  end
  return b
end

-- a chart's RKS is gold once all perfect
local function ink(chart) return chart.accuracy >= 100 and C.gold or C.white end

-- a chart's grade, blue for a full combo and gold for φ, which hangs below the line in the game's font
local function graded(parent, pos, size, chart)
  local phi = chart.grade == "φ"
  V.text(parent, { pos[1], pos[2] + (phi and size * 0.2 or 0) }, size, chart.grade, phi and C.gold or chart.fc and BLUE
    or C.white, 4, { 0.5, 0.5 }) -- MiddleCenter
end

-- a section of the list from y down: its title, its sum, then a row per chart. returns where the next one starts
local function section(list, y, title, total, charts, first, faded)
  local w = list.width
  V.text(list.rows, { -y * SLOPE + 12, -y - HEADER / 2 }, 36, title)
  if total then V.text(list.rows, { -y * SLOPE + w - 44, -y - HEADER / 2 }, 36, total, C.dim, 5, { 1, 0.5 }) end
  y = y + HEADER
  for i, chart in ipairs(charts) do
    local shape = ui.bar(list.rows, NAME .. "-row", { -y * SLOPE, -y }, { w, ROW }, C.faint)
    if faded then shape.gameObject:AddComponent(UE.CanvasGroup).alpha = 0.45 end
    local row, x = shape.transform, ART + 104
    ui.cover(row, NAME .. "-cover", { 0, ROW }, { ART, ROW }, chart.id)
    V.text(row, { x - 20, ROW / 2 }, 28, tostring(first + i - 1), C.dim, 5, { 1, 0.5 }) -- MiddleRight
    V.text(row, { x, 66 }, 34, chart.name, C.white, 3, nil, w - x - 190)
    V.text(row, { w - 44, 64 }, 38, ("%.3f"):format(chart.rks), ink(chart), 5, { 1, 0.5 })
    -- the second line starts further left, along the row's slant
    local under = x - 38 * SLOPE
    V.plate(row, { under, 44 }, { 116, 34 }, C[chart.level], 22, ("%s %.1f"):format(chart.level, chart.constant))
    V.text(row, { under + 128, 27 }, 24, ("%.2f%%"):format(chart.accuracy), C.dim)
    V.text(row, { w - 88, 27 }, 24, ("%07d"):format(chart.score), C.dim, 5, { 1, 0.5 })
    graded(row, { w - 60, 27 }, 24, chart)
    y = y + STEP
  end
  return y
end

-- the sums, and every chart in a list to scroll
local function listed(root, b)
  -- the rows step left as they go down, which leaves the sums a place left of the first ones. on a wide screen both
  -- go to its middle
  local top, bottom = V.top - 66, 30
  local wide = math.min(WIDE, V.width - V.left - SUMS - 24)
  local left = V.left + (V.width - V.left - SUMS - 24 - wide) / 2
  local first, drift = left + SUMS, (top - bottom) * SLOPE -- the first row's left end, and how far the last is from it
  -- where a line of the sums ends at a height, the lower the further left like the rows
  local function ends(y) return first - (top - y) * SLOPE - 36 end
  local function line(y, label, value)
    V.text(root, { left, y }, 30, label, C.dim)
    V.text(root, { ends(y), y }, 38, value, C.white, 5, { 1, 0.5 }) -- MiddleRight
  end
  local best, phi = sum(b.best), sum(b.phi)
  V.text(root, { left, 800 }, 116, ("%.4f"):format((best + phi) / (BEST + PHI)))
  line(680, "Best 27", ("%.3f"):format(best))
  line(620, "Phi 3", ("%.3f"):format(phi))
  ui.rect(root, NAME .. "-rule", { left, 580 }, { ends(580) - left, 2 }, C.dim)
  line(540, "Sum of the 30", ("%.3f"):format(best + phi))

  -- ui.list centres its rows where it's half scrolled: it's as wide as they go from its top to its bottom
  local list = ui.list(root, NAME .. "-list", { first - drift - 16, bottom }, { wide + drift + 16, top - bottom }, wide)
  local y = section(list, 0, "Phi 3", ("%.3f"):format(phi), b.phi, 1)
  for _ = #b.phi + 1, PHI do
    V.plate(list.rows, { -y * SLOPE, -y }, { wide, ROW }, C.faint, 28, "Empty until another chart is all perfect", C.dim)
    y = y + STEP
  end
  y = section(list, y + 16, "Best 27", ("%.3f"):format(best), b.best, 1)
  if #b.next > 0 then y = section(list, y + 16, "Not counted", nil, b.next, BEST + 1, true) end
  list.content.sizeDelta = { 0, y + 32 }
end

-- a card of the grid from its top left corner: the cover under the chart's place and level, its texts in a band
local function card(sheet, pos, chart, place, phi)
  local w, h = CARD[1], CARD[2]
  local art = ui.cover(sheet, NAME .. "-card", pos, CARD, chart.id).transform
  V.plate(art, { 0, h }, { 64, 32 }, phi and C.gold or SHADE, 22, place, phi and C.dark or C.white)
  V.plate(art, { w - 108, h }, { 108, 32 }, C[chart.level], 22, ("%s %.1f"):format(chart.level, chart.constant))
  local band = ui.bar(art, NAME .. "-band", { -(h - BAND) * SLOPE, BAND }, { w, BAND }, SHADE).transform
  -- where a line starts at a height of the band, which leans like the card
  local function from(y) return 16 - (BAND - y) * SLOPE end
  V.text(band, { from(78), 78 }, 22, chart.name, C.white, 3, nil, w - 32)
  V.text(band, { from(48), 48 }, 30, ("%.3f"):format(chart.rks), ink(chart))
  V.text(band, { from(48) + w - 32, 48 }, 20, ("%.2f%%"):format(chart.accuracy), C.dim, 5, { 1, 0.5 }) -- MiddleRight
  local score = V.text(band, { from(18), 18 }, 20, ("%07d"):format(chart.score), C.dim)
  graded(band, { from(18) + score.preferredWidth + 20, 18 }, 20, chart)
end

-- the 30 charts at once: the phi 3 then the best 27, in rows that step left like the game's. the grid is drawn at
-- one size and scaled to the screen, in 6 columns or in 5, whichever shows it bigger
local function grid(root, b)
  local step, room = { CARD[1] + GAP, CARD[2] + GAP }, V.top - 96
  local columns, high, wide, scale
  for _, n in ipairs({ 6, 5 }) do
    local h = (BEST + PHI) / n * step[2] - GAP
    local w = n * step[1] - GAP + h * SLOPE
    local fits = math.min((V.width - 2 * V.left) / w, room / h)
    if not scale or fits > scale then columns, high, wide, scale = n, h, w, fits end
  end
  local sheet = UE.GameObject(NAME .. "-grid"):AddComponent(UE.RectTransform)
  sheet:SetParent(root, false)
  sheet.anchorMin, sheet.anchorMax, sheet.sizeDelta, sheet.localScale = { 0, 0 }, { 0, 0 }, { 0, 0 }, { scale, scale, 1 }
  sheet.anchoredPosition = { (V.width - wide * scale) / 2, 30 + (room - high * scale) / 2 }
  local i = 0
  local function add(chart, place, phi)
    local down = i // columns * step[2]
    card(sheet, { (high - down) * SLOPE + i % columns * step[1], high - down }, chart, place, phi)
    i = i + 1
  end
  for n, chart in ipairs(b.phi) do add(chart, ("P%d"):format(n), true) end
  for n, chart in ipairs(b.best) do add(chart, tostring(n)) end
  V.text(root, { V.width - V.left, V.top }, 56, ("%.4f"):format((sum(b.best) + sum(b.phi)) / (BEST + PHI)), C.white, 5,
    { 1, 0.5 })
end

local function draw(b)
  V.show(shown)
  V.part("all", "", function(root)
    V.back(root, V.hide)
    V.titles(root, TITLES, shown, function(title)
      shown = title
      draw(b)
    end)
    if #b.best == 0 then
      return V.text(root, { V.width / 2, V.height / 2 }, 44, "Play a chart to get an RKS", C.dim, 4, { 0.5, 0.5 })
    end
    if shown == TITLES[1] then listed(root, b) else grid(root, b) end
  end)
end

-- the RKS of the player's bar opens it: a square around the number takes the tap, the rest of the bar keeps its own
on("scene", function(name)
  if name ~= "SongSelector" then return end
  local box = UE.Object.FindObjectOfType(CS.PlayerBarControl).rank.transform.parent
  local size = box.sizeDelta
  V.tappable(ui.rect(box, NAME .. "-tap", { -10, -20 }, { size.x + 20, size.y + 40 }, { 0, 0, 0, 0 }, { 0, 0 }),
    function() draw(breakdown()) end)
end)
