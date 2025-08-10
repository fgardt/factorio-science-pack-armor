---@type table<data.ItemID, true>
local science_packs = {}
---@type table<data.ItemID, data.TechnologyID>
local tool_2_unlocking_tech = {}

for _, tech in pairs(data.raw["technology"]) do
    if tech.hidden then goto continue end

    local effects = tech.effects
    if not effects then goto skip_effects end

    do
        ---@type table<data.ItemID, true>
        local unlocks_tool = {}
        for _, effect in pairs(effects) do
            if effect.type ~= "unlock-recipe" then goto continue end

            local recipe = data.raw["recipe"][effect.recipe] or {}
            local results = recipe.results or {}

            for _, result in pairs(results) do
                if result.type ~= "item" then goto continue end

                local res_name = result.name
                if data.raw["tool"][res_name] then
                    unlocks_tool[res_name] = true
                end

                ::continue::
            end

            ::continue::
        end

        -- if the tech only unlocks a single tool we can assume that the
        -- technology icon is a high resolution version of the tool icon
        -- and can use it for the armor instead of the low resolution item icon
        if table_size(unlocks_tool) == 1 then
            local uname, _ = next(unlocks_tool)
            ---@cast uname -?

            local existing_tech = tool_2_unlocking_tech[uname]
            if not existing_tech then
                tool_2_unlocking_tech[uname] = tech.name
            elseif uname == tech.name then
                tool_2_unlocking_tech[uname] = tech.name
            end
        end
    end

    ::skip_effects::

    local unit = tech.unit
    if not unit then goto continue end

    for _, pack in pairs(unit.ingredients) do
        local name = pack[1]

        -- only convert tool based science packs
        -- will not touch armors / repair packs
        if data.raw["tool"][name] then
            science_packs[name] = true
        end
    end

    ::continue::
end

local function icon2layers(data, scale)
    local icons = data.icons or { { icon = data.icon } }
    local layers = {}

    for _, icon in pairs(icons) do
        local img = icon.icon
        local size = icon.icon_size or data.icon_size or 64
        local scale = (64 / size) * scale * (icon.scale or 1)
        local shift = { 0, -0.5 }

        local size1 = size
        if table_size(layers) > 0 then
            size1 = layers[1].size
            local scale1 = layers[1].scale
            scale = scale1 * (icon.scale or 1)
        end

        shift[1] = shift[1] + (icon.shift and icon.shift[1] or 0) / size1
        shift[2] = shift[2] + (icon.shift and icon.shift[2] or 0) / size1

        table.insert(layers, {
            direction_count = 1,
            filename = img,
            size = size,
            scale = scale,
            shift = shift,
            tint = icon.tint
        })
    end

    return layers
end

local armors = {} ---@type data.ArmorPrototype[]
local anims = {} ---@type data.CharacterArmorAnimation[]
for name, info in pairs(science_packs) do
    local pack = table.deepcopy(data.raw["tool"][name])
    data.raw["tool"][name] = nil

    pack.type = "armor"
    ---@cast pack data.ArmorPrototype
    table.insert(armors, pack)

    local scale = 0.75
    local layers = icon2layers(pack, scale)
    local scale = 0.75

    local tech = tool_2_unlocking_tech[name]
    if name == "automation-science-pack" and not tech then
        layers = icon2layers({
            icon = "__base__/graphics/technology/automation-science-pack.png",
            icon_size = 256
        }, scale)
    elseif tech then
        layers = icon2layers(data.raw["technology"][tech], scale)
    end

    ---@type data.RotatedAnimation
    local anim = {
        layers = layers,
    }

    local anim18 = table.deepcopy(anim)
    for _, layer in pairs(anim18.layers) do
        local stripes = {}

        for _ = 1, 18 do
            table.insert(stripes, {
                filename = layer.filename,
                height_in_frames = 1,
                width_in_frames = 1
            })
        end

        layer.stripes = stripes
        layer.direction_count = 18
        layer.filename = nil
    end

    table.insert(anims, {
        armors = { pack.name },
        idle = anim,
        idle_with_gun = anim,
        running = anim,
        running_with_gun = anim18,
        mining_with_tool = anim,
    })
end

data:extend(armors)

-- if table_size(data.raw["tool"]) == 0 and table_size(armors) > 0 then
--     local dummy = table.deepcopy(armors[1])
--     dummy.type = "tool"
--     dummy.name = "SPA-dummy-tool"
--     dummy.hidden = true
--     dummy.hidden_in_factoriopedia = true
--     data:extend({ dummy })
-- end

for _, char in pairs(data.raw["character"]) do
    for _, anim in pairs(anims) do
        table.insert(char.animations, anim)
    end
end
