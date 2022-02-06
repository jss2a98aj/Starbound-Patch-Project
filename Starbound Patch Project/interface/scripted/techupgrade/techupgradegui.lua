require "/scripts/util.lua"
require "/scripts/interp.lua"

function init()
  self.techList = "techScrollArea.techList"

  self.selectorHeights = config.getParameter("selectorHeights")
  self.selectorTime = config.getParameter("selectorTime")
  self.techLockedIcon = config.getParameter("techLockedIcon")
  self.slotLabelText = config.getParameter("slotLabelText")
  self.suitImagePath = config.getParameter("suitImagePath")
  self.suitSelectedPath = config.getParameter("suitSelectedPath")
  self.selectionPulse = config.getParameter("selectionPulse")

  widget.setImage("imgSuit", string.format(self.suitImagePath, player.species(), player.gender()))

  self.techs = {}
  for _,tech in pairs(player.availableTechs()) do
    if root.hasTech(tech) then
      self.techs[tech] = root.techConfig(tech)
    else
      player.makeTechUnavailable(tech)
    end
  end

  self.animationTimer = 0

  setSelectedSlot("Head")
  updateEquippedIcons()
end

function update(dt)
  if self.tweenSelector then self.tweenSelector(dt) end

  animateSelection(dt)

  if self.selectedTech then
    local currentChips = player.hasCountOfItem("techcard")
    if not contains(player.enabledTechs(), self.selectedTech) then
      local cost = techCost(self.selectedTech)
      widget.setText("lblChipsCount", string.format("%s / %s", currentChips, cost))
      widget.setButtonEnabled("btnEnable", currentChips >= cost)
    else
      widget.setText("lblChipsCount", string.format("%s / --", currentChips))
    end
  else
      widget.setButtonEnabled("btnEnable", false)
  end
end

function techCost(techName)
  return self.techs[techName].chipCost or config.getParameter("defaultCost")
end

function populateTechList(slot)
  widget.clearListItems(self.techList)

  -- Show enabled techs at the top of the list
  local techs = player.enabledTechs()
  local disabled = util.filter(util.keys(self.techs), function(a) return not contains(techs, a) end)
  util.appendLists(techs, disabled)

  for _,techName in pairs(techs) do
    --SBPP - Prevents an error if new techs were unlocked after init. Credit goes to Silver Sokolova for this.
    if not self.techs[techName] then
      self.techs[techName] = root.hasTech(techName) and root.techConfig(techName)
    end
    if root.hasTech(techName) then
      local config = self.techs[techName]
      if root.techType(techName) == slot then
        local listItem = widget.addListItem(self.techList)
        widget.setText(string.format("%s.%s.techName", self.techList, listItem), config.shortDescription)
        widget.setData(string.format("%s.%s", self.techList, listItem), techName)

         if contains(player.enabledTechs(), techName) then
          widget.setImage(string.format("%s.%s.techIcon", self.techList, listItem), config.icon)
        else
          widget.setImage(string.format("%s.%s.techIcon", self.techList, listItem), self.techLockedIcon)
        end

        if player.equippedTech(slot) == techName then
          widget.setListSelected(self.techList, listItem)
        end
      end
    end
  end
end

function setSelectedSlot(slot)
  self.selectedSlot = slot
  widget.setText("lblDescription", config.getParameter("selectTechDescription"))
  widget.setText("lblSlot", self.slotLabelText[slot])
  populateTechList(slot)

  self.tweenSelector = coroutine.wrap(function(dt)
    local position = widget.getPosition("imgSlotSelect")
    local timer = 0
    while timer < self.selectorTime do
      timer = math.min(timer + dt, self.selectorTime)
      local ratio = timer / self.selectorTime
      widget.setPosition("imgSlotSelect", {position[1], interp.sin(ratio, position[2], self.selectorHeights[slot])})
      coroutine.yield()
    end
    self.tweenSelector = nil
  end)

  self.selectionImage = string.format(self.suitSelectedPath, player.species(), player.gender(), string.lower(slot))
  self.animationTimer = 0

  widget.setVisible("imgSelectedHead", slot == "Head")
  widget.setVisible("imgSelectedBody", slot == "Body")
  widget.setVisible("imgSelectedLegs", slot == "Legs")
end

function animateSelection(dt)
  self.animationTimer = self.animationTimer + dt
  while self.animationTimer > self.selectionPulse do
    self.animationTimer = self.animationTimer - self.selectionPulse
  end

  local ratio = (self.animationTimer / self.selectionPulse) * 2
  local opacity = interp.sin(ratio, 0, 1)
  local highlightDirectives = string.format("?multiply=FFFFFF%2x", math.floor(opacity * 255))
  widget.setImage("imgSelected", self.selectionImage..highlightDirectives)
end

function enableTech(techName)
  local cost = techCost(techName)
  if player.consumeItem({name = "techcard", count = cost}) then
    player.enableTech(techName)

    equipTech(techName)
    populateTechList(self.selectedSlot)
  end
end

function updateEquippedIcons()
  for _,slot in pairs({"Head", "Body", "Legs"}) do
    local tech = player.equippedTech(slot)
    if tech and self.techs[tech] then
      widget.setImage(string.format("techIcon%s", slot), self.techs[tech].icon)
    else
      widget.setImage(string.format("techIcon%s", slot), "")
    end
  end
end

function equipTech(techName)
  player.equipTech(techName)

  updateEquippedIcons()
end

function setSelectedTech(techName)
  local config = root.techConfig(techName)
  widget.setText("lblDescription", self.techs[techName].description)
  self.selectedTech = techName

  if contains(player.enabledTechs(), techName) then
    widget.setButtonEnabled("btnEnable", false)
    equipTech(techName)
  else
    local affordable = player.hasCountOfItem("techcard") >= techCost(techName)
    widget.setButtonEnabled("btnEnable", affordable)
  end
end

-- callbacks
function techSelected()
  local listItem = widget.getListSelected(self.techList)
  if listItem then
    local techName = widget.getData(string.format("%s.%s", self.techList, listItem))
    setSelectedTech(techName)
  end
end

function techSlotGroup(button, slot)
  setSelectedSlot(slot)
end

function doEnable()
  if self.selectedSlot and not contains(player.enabledTechs(), self.selectedSlot) then
    enableTech(self.selectedTech)
  end
end
