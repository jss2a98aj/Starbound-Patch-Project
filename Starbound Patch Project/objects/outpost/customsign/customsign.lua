function init()
  self.signDirectiveStrings = config.getParameter("signData")
  self.lightFrames = config.getParameter("lightData")
  self.signLight = config.getParameter("signLight")
  self.signBacking = config.getParameter("signBacking")
  self.frameColors = config.getParameter("frameColors")
  storage.storedDirectiveString = storage.storedDirectiveString or ""
  animator.setAnimationState("displayedState", "idle")

  self.isWired = config.getParameter("isWired")
  self.isContainer = config.getParameter("isContainer")
  if storage.isOn == nil then storage.isOn = true end

  if self.isWired == true then
    object.setInteractive(not object.isInputNodeConnected(0))
    object.setAllOutputNodes(storage.isOn)
  end

  self.scanCooldown = config.getParameter("scanCooldown", 1)

  self.scanTimer = math.random() * self.scanCooldown
  self.drawCooldown = config.getParameter("drawCooldown", 0.5)
  self.drawTimer = self.drawCooldown

  storage.nearSpaces = {
    {{-3,-1},"bl", nil, "01"},
    {{-3,0},"ml",nil, "02"},
    {{-3,1},"ul",nil, "03"},
    {{-2,-1},"b1",nil, "0E"},
    {{-1,-1},"b2",nil, "0D"},
    {{0,-1},"b3",nil, "0C"},
    {{1,-1},"b4", nil, "0B"},
    {{2,-1},"br",nil, "0A"},
    {{-2,1},"u1",nil, "04"},
    {{-1,1},"u2",nil, "05"},
    {{0,1},"u3",nil, "06"},
    {{1,1},"u4",nil, "07"},
    {{2,1},"ur",nil, "08"},
    {{2,0},"mr", nil, "09"}
  }
  if self.signDirectiveStrings ~= nil and self.signDirectiveStrings[1] ~= nil then
    if storage.isOn and self.isWired == true then
      storage.frame = 2
    else
      storage.frame = 1
    end
    storage.storedDirectiveString = self.signDirectiveStrings[storage.frame]
    applyDirectives()
  end
end

function onNodeConnectionChange(args)
  --want wired signs to stop functioning as switches when something's feeding them input
  if self.isWired == true then
    object.setInteractive(not object.isInputNodeConnected(0))
    if object.isInputNodeConnected(0) then
    onInputNodeChange({ level = object.getInputNodeLevel(0) })
    else
    onInputNodeChange({ level = false })
    end
  end
end

function onInputNodeChange(args)
  if args.level then
    storage.isOn = true
  if self.isWired == true then storage.frame = 2 end
  else
    storage.isOn = false
  if self.isWired == true then storage.frame = 1 end
  end
  object.setAllOutputNodes(storage.isOn)
  storage.storedDirectiveString = self.signDirectiveStrings[storage.frame]
  applyDirectives()
end

function onInteraction(args)
   object.setLightColor({math.random(0,255), math.random(0,255), math.random(0,255), math.random(0,255)})
  if self.isWired == true then
    if storage.isOn then
      storage.isOn = false
      storage.frame = 1
      object.setAllOutputNodes(false)
    else
      storage.isOn = true
      storage.frame = 2
      object.setAllOutputNodes(true)
    end
    storage.storedDirectiveString = self.signDirectiveStrings[storage.frame]
    applyDirectives()
  end
end

function update(dt)
  --three behaviors: non-wired, wired and off, wired and on
  if #self.signDirectiveStrings >=2 then
    if self.drawTimer <= 0 then
      if self.isWired == true then
        if storage.isOn and #self.signDirectiveStrings > 2 then
          if storage.frame < #self.signDirectiveStrings then
            storage.frame = storage.frame + 1
          else
            storage.frame = 2
          end
          --need to handle the special cases for this string, blank frames and filler frames
          if self.signDirectiveStrings[storage.frame] == "replace=" and storage.storedDirectiveString ~= self.signDirectiveStrings[storage.frame] then
            storage.storedDirectiveString = ""
            applyDirectives()
          elseif self.signDirectiveStrings[storage.frame] ~= nil and storage.storedDirectiveString ~= self.signDirectiveStrings[storage.frame] then
            storage.storedDirectiveString = self.signDirectiveStrings[storage.frame]
            applyDirectives()
          end
        end
      else
        if storage.frame < #self.signDirectiveStrings then storage.frame = storage.frame + 1 else storage.frame = 1 end
        if self.signDirectiveStrings[storage.frame] == "replace=" and storage.storedDirectiveString ~= self.signDirectiveStrings[storage.frame] then
          storage.storedDirectiveString = ""
          applyDirectives()
        elseif self.signDirectiveStrings[storage.frame] ~= nil and storage.storedDirectiveString ~= self.signDirectiveStrings[storage.frame] then
          storage.storedDirectiveString = self.signDirectiveStrings[storage.frame]
          applyDirectives()
        end
      end
      self.drawTimer = self.drawCooldown
    else
      self.drawTimer = self.drawTimer - dt
    end
  end
  if self.scanTimer <= 0 then
    updateFrameSegments()
    self.scanTimer = self.scanCooldown
  else
    self.scanTimer = self.scanTimer - dt
  end
end

function die()
  storage = {}
end

function updateFrameSegments()
  local needsRedraw = false
  --sb.logInfo("//////////Checking frame//////////")
  --sb.logInfo("%s %s at %s", object.name(), entity.id(), object.position())
  --sb.logInfo("Old Spaces: %s", storage.nearSpaces)
  for u,v in ipairs(storage.nearSpaces) do
    local isOccupied = false
    --no frame segement bordering an occupied spaces. used to ignore non-sign objects for this, but that was wonky
    if world.tileIsOccupied({object.position()[1] + v[1][1], object.position()[2] + v[1][2]}) then
      local nearObjects = world.entityQuery({object.position()[1] + v[1][1] + 0.5, object.position()[2] + v[1][2] + 0.5}, 0.2, { includedTypes = { "object" }, boundMode = "CollisionArea", withoutEntityId = entity.id() })
      for _,objectId in pairs(nearObjects) do
        --SBPP - added check for "wiredcustomsign"
        if world.entityName(objectId) == "customsign" or world.entityName(objectId) == "wiredcustomsign" then
          local signPos = world.distance(world.entityPosition(objectId) , object.position())
          --sb.logInfo("%s, %s", v[1] ,signPos)
          if signPos[2] == v[1][2] and signPos[1] <= v[1][1] + 2 and signPos[1] >= v[1][1] - 1 then
            if v[3] ~= "tile" then
              v[3] = "tile"
              needsRedraw = true
            end
            isOccupied = true
            break
          end
        end
      end
    end
    if not isOccupied then
      if v[3] == "tile" then
        v[3] = nil
        needsRedraw = true
      end
    end
  end

  --"bl" = "bl" or "ml" or "b1"
  storage.nearSpaces[1][3] = storage.nearSpaces[1][3] or storage.nearSpaces[2][3] or storage.nearSpaces[4][3]
  --"ul" = "ul" or "ml" or "u1"
  storage.nearSpaces[3][3] = storage.nearSpaces[3][3] or storage.nearSpaces[2][3] or storage.nearSpaces[9][3]
  --"br" = "br" or "mr" or "b4"
  storage.nearSpaces[8][3] = storage.nearSpaces[8][3] or storage.nearSpaces[14][3] or storage.nearSpaces[7][3]
  --"ur" = "ur" or "mr" or "u4"
  storage.nearSpaces[13][3] = storage.nearSpaces[13][3] or storage.nearSpaces[14][3] or storage.nearSpaces[12][3]

  --sb.logInfo("New Spaces: %s", storage.nearSpaces)
  if needsRedraw then
    applyDirectives()
  end
  --sb.logInfo("----------------------------------")
end

function applyDirectives()
  -- Not using per frame lighting anymore
  -- if self.lightFrames ~= nil and self.lightFrames["f"..tostring(storage.frame)] ~= nil then
  --  local lightRGB = convertRGBAtoArray(self.lightFrames["f"..tostring(storage.frame)])
  --  object.setLightColor({lightRGB[1], lightRGB[2], lightRGB[3], 255})
  -- else
  --  object.setLightColor({0, 0, 0, 0})
  -- end
  if storage.isOn and self.signLight then
    object.setLightColor(convertRGBAtoArray(self.signLight))
  else
    object.setLightColor({0, 0, 0, 0})
  end

  storage.storedDirectiveString = storage.storedDirectiveString  or  ""
  local frameDirectiveString = "replace="
  local needsSemicolon = false
  if storage.storedDirectiveString ~= "" then
    frameDirectiveString = ""
    needsSemicolon = true
  end
  for u,v in ipairs(storage.nearSpaces) do
    if v[3] ~= "tile" then
      if needsSemicolon == true then frameDirectiveString = frameDirectiveString .. ";" else needsSemicolon = true end
      frameDirectiveString = frameDirectiveString .. "90" .. v[4] .. "0001" .. "=" .. self.frameColors[1] .. ";00" .. v[4] .. "9001=" .. self.frameColors[2]
    end
  end
  object.setProcessingDirectives(storage.storedDirectiveString..frameDirectiveString)
end

function convertRGBAtoArray(rgba)
  return {tonumber(string.sub(rgba,1,2),16),
  tonumber(string.sub(rgba,3,4),16),
  tonumber(string.sub(rgba,5,6),16),
  tonumber(string.sub(rgba,7,8),16)}
end
