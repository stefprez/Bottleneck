-------------------------------------------------------------------------------
--[[Bottleneck]]--
-------------------------------------------------------------------------------

local bn_signals_per_tick = settings.global["bottleneck-signals-per-tick"].value

local LIGHT = {
    off = 1, green = 2, red = 3, yellow = 4, blue = 5, redx = 6, yellowmin = 7,
    offsmall = 8,  greensmall = 9, redsmall = 10, yellowsmall = 11,
    bluesmall = 12, redxsmall = 13, yellowminsmall = 14,
}

local SPRITE = {
    off = {
        sprite = 'bottleneck_white',
        tint = {r=0, g=0, b=0},
        visible=false
    },
    green = {
        sprite = 'bottleneck_white',
        tint = {g = 1},
        visible=true
    },
    red = {
        sprite = 'bottleneck_white',
        tint = {r = 1},
        visible=true
    },
    yellow = {
        sprite = 'bottleneck_white',
        tint = {r = 1, g=1},
        visible=true
    },
    blue = {
        sprite = 'bottleneck_white',
        tint = {b = 1},
        visible=true
    },
    redx  = {
        sprite = 'bottleneck_cross',
        tint = {r = 1},
        visible=true
    },
    yellowmin = {
        sprite = 'bottleneck_minus',
        tint = {r = 1, g=1},
        visible=true
    },
    offsmall = {
        sprite = 'bottleneck_offsmall',
        visible=true
    },
    greensmall = {
        sprite = 'bottleneck_white_small',
        tint = {g = 1},
        visible=true
    },
    redsmall = {
        sprite = 'bottleneck_white_small',
        tint = {r = 1},
        visible=true
    },
    yellowsmall = {
        sprite = 'bottleneck_white_small',
        tint = {r = 1, g=1},
        visible=true
    },
    bluesmall = {
        sprite = 'bottleneck_white_small',
        visible=true
    },
    redxsmall  = {
        sprite = 'bottleneck_cross_small',
        tint = {r = 1},
        visible=true
    },
    yellowminsmall = {
        sprite = 'bottleneck_minus_small',
        tint = {r = 1, g=1},
        visible=true
    }
}

local STYLE = {}
local SPRITE_STYLE = {}

--Faster to just change the color than it is to check it first.
local function change_signal(data, style)
    data.signal.graphics_variation = style or 1
end

local function change_sprite(data, style)
    local sprite = data.sprite
    rendering.set_sprite(sprite, style.sprite)
    rendering.set_visible(sprite, style.visible)
    rendering.set_color(sprite, style.tint)
end

--[[ Remove the LIGHT]]
local function remove_signal(event)
    local entity = event.entity
    local index = entity.unit_number
    local overlays = global.overlays
    local data = overlays[index]
    if data then
        local signal = data.signal
        if signal and signal.valid then
            signal.destroy()
        end
        overlays[index] = nil
    end
end

local function remove_sprite(event)
    local entity = event.entity
    local index = entity.unit_number
    local overlays = global.overlays
    local data = overlays[index]
    if data then
        local sprite = data.sprite
        if sprite then
            rendering.destroy(sprite)
        end
    end
end

--[[ Calculates bottom center of the entity to place bottleneck there ]]
local function get_signal_position_from(entity)
    local left_top = entity.prototype.selection_box.left_top
    local right_bottom = entity.prototype.selection_box.right_bottom
    --Calculating center of the selection box
    local center = (left_top.x + right_bottom.x) / 2
    local width = math.abs(left_top.x) + right_bottom.x
    -- Set Shift here if needed, The offset looks better as it doesn't cover up fluid input information
    -- Ignore shift for 1 tile entities
    local x = (width > 1.25 and center - 0.5) or center
    local y = right_bottom.y
    --Calculating bottom center of the selection box
    return {x = entity.position.x + x, y = entity.position.y + y}
end

local function get_render_position_from(entity)
    local left_top = entity.prototype.selection_box.left_top
    local right_bottom = entity.prototype.selection_box.right_bottom
    --Calculating center of the selection box
    local center = (left_top.x + right_bottom.x) / 2
    local width = math.abs(left_top.x) + right_bottom.x
    -- Set Shift here if needed, The offset looks better as it doesn't cover up fluid input information
    -- Ignore shift for 1 tile entities
    local x = (width > 1.25 and center - 0.5) or center
    local y = right_bottom.y - 0.25
    --Calculating bottom center of the selection box
    return {x = entity.position.x + x, y = entity.position.y + y}
end


local function new_sprite(entity)
    local sprite = SPRITE_STYLE[entity.status]
    sprite['target']=get_render_position_from(entity)
    sprite['surface']=entity.surface
    sprite['render_layer']='entity-info-icon'
    return rendering.draw_sprite (sprite)
end

local function new_signal(entity, variation)
    local signal = entity.surface.create_entity{name = "bottleneck-stoplight", position = get_signal_position_from(entity), force = entity.force}
    signal.graphics_variation = (global.show_bottlenecks < 1 and LIGHT["off"]) or variation or LIGHT["red"]
    signal.destructible = false
    return signal
end

local function entity_moved(event, data)
    data = data or global.overlays[event.moved_entity.unit_number]
    if data then
        if data.signal and data.signal.valid then
            data.drill_depleted = false
            local position = get_signal_position_from(event.moved_entity)
            data.signal.teleport(position)
        end
        if data.sprite then
            data.drill_depleted = false
            local position = get_render_position_from(event.moved_entity)
            rendering.set_target(data.sprite, position)
        end
    end
end

function update_entity(data)
    local entity = data.entity
	change_signal(data, STYLE[entity.status])
    change_sprite(data, SPRITE_STYLE[entity.status])
end

--[[ A function that is called whenever an entity is built (both by player and by robots) ]]--
local function built(event)
	local entity = event.created_entity or event.entity
    local data
    -- If the entity that's been built is an assembly machine or a furnace...
    if entity.type == "assembling-machine" then
		data = {}
    elseif entity.type == "lab" then
        data = {}
    elseif entity.type == "furnace" then
        data = {}
    elseif entity.type == "mining-drill" and entity.name ~= "factory-port-marker" then
        data = {}
    end

    if data then
        data.entity = entity
        data.signal = new_signal(entity)
        data.sprite = new_sprite(entity)

        --update[data.update](data)
        global.overlays[entity.unit_number] = data
        -- if we are in the process of removing LIGHTs, we need to restart
        -- that, since inserting into the overlays table may mess up the
        -- iteration order.
        if global.show_bottlenecks == -1 then
            global.update_index = nil
        end
    end
end

local function rebuild_overlays()
    --[[Setup the global overlays table This table contains the machine entity, the signal entity and the freeze variable]]--
    global.overlays = {}
    global.update_index = nil
    --game.print("Bottleneck: Rebuilding data from scratch")

    --[[Find all assembling machines on the map. Check each surface]]--
    for _, surface in pairs(game.surfaces) do
        --find-entities-filtered with no area argument scans for all entities in loaded chunks and should
        --be more effiecent then scanning through all chunks like in previous version

        --[[destroy any existing bottleneck-signals]]--
        for _, stoplight in pairs(surface.find_entities_filtered{name="bottleneck-stoplight"}) do
            stoplight.destroy()
        end

        --[[Find all assembling machines within the bounds, and pretend that they were just built]]--
        for _, am in pairs(surface.find_entities_filtered{type="assembling-machine"}) do
            built({created_entity = am})
        end

        --[[Find all furnaces within the bounds, and pretend that they were just built]]--
        for _, am in pairs(surface.find_entities_filtered{type="furnace"}) do
            built({created_entity = am})
        end

        --[[Find all mining-drills within the bounds, and pretend that they were just built]]--
        for _, am in pairs(surface.find_entities_filtered{type="mining-drill"}) do
            built({created_entity = am})
        end
    end
end

local function on_tick()
    local show_bottlenecks = global.show_bottlenecks
    if show_bottlenecks ~= 0 then
        local next = next --very slight perfomance improvment

        local signals_per_tick = bn_signals_per_tick

        local overlays = global.overlays
        local index = global.update_index
        local data

        --check for existing data at index
        if index and overlays[index] then
            data = overlays[index]
        else
            index, data = next(overlays, index)
        end

        local numiter = 0
        while index and (numiter < signals_per_tick) do
            local entity = data.entity
            if entity.valid then -- if entity is valid, update it, otherwise remove the signal and the associated data
                if data.signal.valid then
                    if show_bottlenecks > 0 then
                        update_entity(data)
                    else
                        change_signal(data, STATES.OFF)
                    end
                else -- Rebuild the icon something broke it!
                    data.signal = new_signal(entity)
                    data.sprite = new_signal(entity)
                end
            else -- Machine is gone
                if data.signal.valid then
                    data.signal.destroy() -- Signal is there; remove it
                end
                overlays[index] = nil -- forget about the machine
            end
            numiter = numiter + 1
            index, data = next(overlays, index)
        end
        global.update_index = index
        -- if we have reached the end of the list (i.e., have removed all LIGHTs),
        -- pause updating until enabled by hotkey next
        if not index and show_bottlenecks <= 0 then
            global.show_bottlenecks = 0
            --We have cycled everything to off, disable the tick handler
            script.on_event(defines.events.on_tick, nil)
        end
    end
end

local function update_settings(event)
	bn_signals_per_tick = settings.global["bottleneck-signals-per-tick"].value
	STYLE[defines.entity_status.working] = LIGHT[settings.global["bottleneck-show-working"].value]
	STYLE[defines.entity_status.no_power] = LIGHT[settings.global["bottleneck-show-no_power"].value]
	STYLE[defines.entity_status.no_fuel] = LIGHT[settings.global["bottleneck-show-no_fuel"].value]
	STYLE[defines.entity_status.no_recipe] = LIGHT[settings.global["bottleneck-show-no_recipe"].value]
	STYLE[defines.entity_status.no_input_fluid] = LIGHT[settings.global["bottleneck-show-no_input_fluid"].value]
	STYLE[defines.entity_status.no_research_in_progress] = LIGHT[settings.global["bottleneck-show-no_research_in_progress"].value]
	STYLE[defines.entity_status.no_minable_resources] = LIGHT[settings.global["bottleneck-show-no_minable_resources"].value]
	STYLE[defines.entity_status.low_input_fluid] = LIGHT[settings.global["bottleneck-show-low_input_fluid"].value]
	STYLE[defines.entity_status.low_power] = LIGHT[settings.global["bottleneck-show-low_power"].value]
	STYLE[defines.entity_status.disabled_by_control_behavior] = LIGHT[settings.global["bottleneck-show-disabled_by_control_behavior"].value]
	STYLE[defines.entity_status.disabled_by_script] = LIGHT[settings.global["bottleneck-show-disabled_by_script"].value]
	STYLE[defines.entity_status.fluid_ingredient_shortage] = LIGHT[settings.global["bottleneck-show-fluid_ingredient_shortage"].value]
	STYLE[defines.entity_status.fluid_production_overload] = LIGHT[settings.global["bottleneck-show-fluid_production_overload"].value]
	STYLE[defines.entity_status.item_ingredient_shortage] = LIGHT[settings.global["bottleneck-show-item_ingredient_shortage"].value]
	STYLE[defines.entity_status.item_production_overload] = LIGHT[settings.global["bottleneck-show-item_production_overload"].value]
	STYLE[defines.entity_status.marked_for_deconstruction] = LIGHT[settings.global["bottleneck-show-marked_for_deconstruction"].value]
	STYLE[defines.entity_status.missing_required_fluid] = LIGHT[settings.global["bottleneck-show-missing_required_fluid"].value]
	STYLE[defines.entity_status.missing_science_packs] = LIGHT[settings.global["bottleneck-show-missing_science_packs"].value]
	STYLE[defines.entity_status.waiting_for_source_items] = LIGHT[settings.global["bottleneck-show-waiting_for_source_items"].value]
	STYLE[defines.entity_status.waiting_for_space_in_destination] = LIGHT[settings.global["bottleneck-show-waiting_for_space_in_destination"].value]

    SPRITE_STYLE[defines.entity_status.working] = SPRITE[settings.global["bottleneck-show-working"].value]
	SPRITE_STYLE[defines.entity_status.no_power] = SPRITE[settings.global["bottleneck-show-no_power"].value]
	SPRITE_STYLE[defines.entity_status.no_fuel] = SPRITE[settings.global["bottleneck-show-no_fuel"].value]
	SPRITE_STYLE[defines.entity_status.no_recipe] = SPRITE[settings.global["bottleneck-show-no_recipe"].value]
	SPRITE_STYLE[defines.entity_status.no_input_fluid] = SPRITE[settings.global["bottleneck-show-no_input_fluid"].value]
	SPRITE_STYLE[defines.entity_status.no_research_in_progress] = SPRITE[settings.global["bottleneck-show-no_research_in_progress"].value]
	SPRITE_STYLE[defines.entity_status.no_minable_resources] = SPRITE[settings.global["bottleneck-show-no_minable_resources"].value]
	SPRITE_STYLE[defines.entity_status.low_input_fluid] = SPRITE[settings.global["bottleneck-show-low_input_fluid"].value]
	SPRITE_STYLE[defines.entity_status.low_power] = SPRITE[settings.global["bottleneck-show-low_power"].value]
	SPRITE_STYLE[defines.entity_status.disabled_by_control_behavior] = SPRITE[settings.global["bottleneck-show-disabled_by_control_behavior"].value]
	SPRITE_STYLE[defines.entity_status.disabled_by_script] = SPRITE[settings.global["bottleneck-show-disabled_by_script"].value]
	SPRITE_STYLE[defines.entity_status.fluid_ingredient_shortage] = SPRITE[settings.global["bottleneck-show-fluid_ingredient_shortage"].value]
	SPRITE_STYLE[defines.entity_status.fluid_production_overload] = SPRITE[settings.global["bottleneck-show-fluid_production_overload"].value]
	SPRITE_STYLE[defines.entity_status.item_ingredient_shortage] = SPRITE[settings.global["bottleneck-show-item_ingredient_shortage"].value]
	SPRITE_STYLE[defines.entity_status.item_production_overload] = SPRITE[settings.global["bottleneck-show-item_production_overload"].value]
	SPRITE_STYLE[defines.entity_status.marked_for_deconstruction] = SPRITE[settings.global["bottleneck-show-marked_for_deconstruction"].value]
	SPRITE_STYLE[defines.entity_status.missing_required_fluid] = SPRITE[settings.global["bottleneck-show-missing_required_fluid"].value]
	SPRITE_STYLE[defines.entity_status.missing_science_packs] = SPRITE[settings.global["bottleneck-show-missing_science_packs"].value]
	SPRITE_STYLE[defines.entity_status.waiting_for_source_items] = SPRITE[settings.global["bottleneck-show-waiting_for_source_items"].value]
	SPRITE_STYLE[defines.entity_status.waiting_for_space_in_destination] = SPRITE[settings.global["bottleneck-show-waiting_for_space_in_destination"].value]
end
script.on_event(defines.events.on_runtime_mod_setting_changed, update_settings)

-------------------------------------------------------------------------------
--[[Init Events]]
local function register_conditional_events()
    if remote.interfaces["PickerDollies"] and remote.interfaces["PickerDollies"]["dolly_moved_entity_id"] then
        script.on_event(remote.call("PickerDollies", "dolly_moved_entity_id"), entity_moved)
    end
    if global.show_bottlenecks ~= 0 then
        --Register the tick handler if we are showing bottlenecks
        script.on_event(defines.events.on_tick, on_tick)
    end
end

local function init()
    global.overlays = {}
    global.show_bottlenecks = 1
    --register the tick handler if we are showing bottlenecks
    if global.show_bottlenecks then
        script.on_event(defines.events.on_tick, on_tick)
    end
    rebuild_overlays()
    register_conditional_events()
end

local function on_load()
    register_conditional_events()
end

local function on_configuration_changed(event)
    --Any MOD has been changed/added/removed, including base game updates.
    if event.mod_changes then
        --This mod has changed
        local changes = event.mod_changes["Bottleneck"]
        if changes then -- THIS Mod has changed
            game.print("Bottleneck: Updated from ".. tostring(changes.old_version) .. " to " .. tostring(changes.new_version))
            global.show_bottlenecks = global.show_bottlenecks or 1
            --Clean up old variables
            global.lights_per_tick = nil
            global.signals_per_tick = nil
            global.showbottlenecks = nil
            global.output_idle_signal = nil
            global.high_contrast = nil
        end
        global.overlays = {}
        rebuild_overlays()
    end
end

local function on_entity_cloned(event)
	if event.destination.name == "bottleneck-stoplight" then
		event.destination.destroy()
	end
end

--[[ Hotkey ]]--

local function on_hotkey(event)
	local player = game.players[event.player_index]
	if not player.admin then
		player.print('Bottleneck: You do not have privileges to toggle bottleneck')
		return
	end
	global.update_index = nil
	if global.show_bottlenecks == 1 then
		global.show_bottlenecks = -1
	else
		global.show_bottlenecks = 1
	end
	--Toggling the setting doesn't disable right way, make sure the handler gets
	--reenabled to toggle colors to their correct values.
	script.on_event(defines.events.on_tick, on_tick)
end

--[[ Setup event handlers ]]--
script.on_init(init)
script.on_configuration_changed(on_configuration_changed)
script.on_load(on_load)

local e=defines.events
local remove_events = {e.on_player_mined_entity, e.on_robot_pre_mined, e.on_entity_died, e.script_raised_destroy}
local add_events = {e.on_built_entity, e.on_robot_built_entity, e.script_raised_revive, e.script_raised_built}

script.on_event(remove_events, remove_signal)
script.on_event(remove_events, remove_sprite)
script.on_event(add_events, built)
script.on_event("bottleneck-hotkey", on_hotkey)
script.on_event({e.on_entity_cloned}, on_entity_cloned)

--[[ Setup remote interface]]--
local interface = {}
--is_enabled - return show_bottlenecks
interface.enabled = function() return global.show_bottlenecks end
--print the global to a file
interface.print_global = function () game.write_file("Bottleneck/global.lua", serpent.block(global, {nocode=true, comment=false})) end
--rebuild all icons
interface.rebuild = rebuild_overlays
--allow other mods to interact with bottleneck
interface.entity_moved = entity_moved
interface.get_lights = function() return LIGHT end
interface.get_states = function() return STATES end
interface.new_signal = new_signal
interface.new_sprite = new_sprite
interface.change_signal = change_signal --function(data, color) change_signal(signal, color) end
--get a place position for a signal
interface.get_position_for_signal = get_signal_position_from
--get the signal data associated with an entity
interface.get_signal_data = function(unit_number) return global.overlays[unit_number] end

remote.add_interface("Bottleneck", interface)
