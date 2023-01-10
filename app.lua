--
-- edge-app-aidon-electric-meter
--

-- local lynx = require("edge.lynx")
local edge = require("edge")
device_id = 0
dirty = true -- The device needs update

function hex_dump(buf)
	local ret = "";
	for byte=1, #buf, 16 do
		local chunk = buf:sub(byte, byte+15)
		chunk:gsub('.', function (c) ret = ret .. string.format('%02X',string.byte(c)) end)
	end
	return ret
end

function findFunctionMeta(meta)
        local match = 1
        for i, fun in ipairs(functions) do
                match = 1;
                for k, v in pairs(meta) do
                        if fun.meta[k] ~= v then
                                match = 0
                        end
                end
                if match == 1 then
                        return functions[i]
                end
        end
        return nil;
end

function findDeviceMeta(meta)
        devices, err = lynx.apiCall("GET", "/api/v2/devicex/" .. app.installation_id)
        local match = 1
        for i, dev in ipairs(devices) do
                match = 1;
                for k, v in pairs(meta) do
                        if dev.meta[k] ~= v then
                                match = 0
                        end
                end
                if match == 1 then
                        return devices[i]
                end
        end
        return nil;
end

function create_function_if_needed(metric, device)
	local func = findFunctionMeta({
		electric_meter_id = tostring(cfg.device),
		electric_meter_metric = metric
	})

	if func == nil then
		local fn

		if metric == "current_L1" or metric == "current_L2" or metric == "current_L3" then
			fn = {
				type = "current",
				installation_id = app.installation_id,
				meta = {
					name = "Electric Meter - " .. metric,
					device_id = tostring(device),
					electric_meter_id = tostring(cfg.device),
					electric_meter_metric = metric,
					unit = "A",
					format = "%0.1f A",
					topic_read = "obj/electric_meter/" .. cfg.device .. "/" .. metric
				}
			}
		elseif metric == "Uptime" then
			fn = {
				type = "uptime",
				installation_id = app.installation_id,
				meta = {
					name = "Electric Meter - " .. metric,
					device_id = tostring(device),
					electric_meter_id = tostring(cfg.device),
					electric_meter_metric = metric,
					unit = "s",
					format = "%0.0f s",
					topic_read = "obj/electric_meter/" .. cfg.device .. "/" .. metric
				}
			}
		elseif metric == "rssi" then
			fn = {
				type = "rssi",
				installation_id = app.installation_id,
				meta = {
					name = "Electric Meter - " .. metric,
					device_id = tostring(device),
					electric_meter_id = tostring(cfg.device),
					electric_meter_metric = metric,
					unit = "dB",
					format = "%0.0f dB",
					topic_read = "obj/electric_meter/" .. cfg.device .. "/" .. metric
				}
			}
		elseif metric == "voltage_L1" or metric == "voltage_L2" or metric == "voltage_L3" or 
			metric == "usbV" or metric == "Vin" then
			fn = {
				type = "voltage",
				installation_id = app.installation_id,
				meta = {
					name = "Electric Meter - " .. metric,
					device_id = tostring(device),
					electric_meter_id = tostring(cfg.device),
					electric_meter_metric = metric,
					unit = "V",
					format = "%0.1f V",
					topic_read = "obj/electric_meter/" .. cfg.device .. "/" .. metric
				}
			}
		elseif metric == "act_pow_pos" or metric == "act_pow_neg" then
			fn = {
				type = "active power",
				installation_id = app.installation_id,
				meta = {
					name = "Electric Meter - " .. metric,
					device_id = tostring(device),
					electric_meter_id = tostring(cfg.device),
					electric_meter_metric = metric,
					unit = "W",
					format = "%0.0f W",
					topic_read = "obj/electric_meter/" .. cfg.device .. "/" .. metric
				}
			}
		elseif metric == "react_pow_pos" or metric == "react_pow_neg" then
			fn = {
				type = "reactive power",
				installation_id = app.installation_id,
				meta = {
					name = "Electric Meter - " .. metric,
					device_id = tostring(device),
					electric_meter_id = tostring(cfg.device),
					electric_meter_metric = metric,
					unit = "VAr",
					format = "%0.0f VAr",
					topic_read = "obj/electric_meter/" .. cfg.device .. "/" .. metric
				}
			}

		elseif metric == "act_energy_pos" or metric == "act_energy_neg" then
			fn = {
				type = "active energy",
				installation_id = app.installation_id,
				meta = {
					name = "Electric Meter - " .. metric,
					device_id = tostring(device),
					electric_meter_id = tostring(cfg.device),
					electric_meter_metric = metric,
					unit = "Wh",
					format = "%0.0f Wh",
					topic_read = "obj/electric_meter/" .. cfg.device .. "/" .. metric
				}
			}
		elseif metric == "react_energy_pos" or metric == "react_energy_neg" then
			fn = {
				type = "reactive power",
				installation_id = app.installation_id,
				meta = {
					name = "Electric Meter - " .. metric,
					device_id = tostring(device),
					electric_meter_id = tostring(cfg.device),
					electric_meter_metric = metric,
					unit = "VArh",
					format = "%0.0f VArh",
					topic_read = "obj/electric_meter/" .. cfg.device .. "/" .. metric
				}
			}

		end

		lynx.createFunction(fn)
	end
end

function publish_data(metric, value, timestamp)
	create_function_if_needed(metric, device_id)

	local topic_read = "obj/electric_meter/" .. cfg.device .. "/" .. metric
	local data = json:encode({ timestamp = timestamp, value = value })
	mq:pub(topic_read, data);

end

function handleTrigger(topic, payload, retained)

	-- Every now and then a json-package is sent with the following.
	-- If it starts with { let's assume it is this message
	-- {
	--  "status": {
	--    "rssi": -79,
	--    "ch": 1,
	--    "ssid": "RejasDatakonsult",
	--    "usbV": "0.00",
	--    "Vin": "23.84",
	--    "Vcap": "3.65",
	--    "Vbck": "4.60",
	--    "Build": "1.1.15",
	--    "Hw": "F",
	--    "bssid": "6ccdd6a89e80",
	--    "ID": "e831cd4e3f3c",
	--    "Uptime": 133,
	--    "mqttcon": 1,
	--    "pubcnt": 0,
	--    "rxcnt": 0,
	--    "wificon": 3,
	--    "wififail": 2,
	--    "bits": 340,
	--    "cSet": 87,
	--    "Ic": 0,
	--    "crcerr": 0,
	--    "cAx": 1.282607,
	--    "cB": 15,
	--    "heap": 209552,
	--    "baud": 2400,
	--    "meter": "Aidon_V2",
	--    "ntc": -5.41,
	--    "s/w": 0,
	--    "ct": 0,
	--    "dtims": 38
	--  }
	-- }

	if payload:find("{", 1, true) == 1 then
		local obj = json:decode(payload)
		publish_data('rssi', obj.status.rssi, edge:time())
		publish_data('usbV', obj.status.usbV, edge:time())
		publish_data('Vin', obj.status.Vin, edge:time())
		publish_data('Uptime', obj.status.Uptime, edge:time())
		
		-- Save some data as metadata on the device
		update_device(obj)
		return -- No need to parse any further
	end


	--
	-- Heavily inspired from
	-- https://github.com/Csstenersen/node-red-contrib-ams-decoder
	--
	local hex = hex_dump(payload)

	if hex == nil then
		return
	end

	p = string.find(hex, "020209060000010000FF090C")
	if p then
		local year = tonumber("0x" .. string.sub(hex, p+24, p+24+3))
		local month = tonumber("0x" .. string.sub(hex, p+28, p+28+1))
		local day = tonumber("0x" .. string.sub(hex, p+30, p+30+1))
		local hour = tonumber("0x" .. string.sub(hex, p+34, p+34+1))
		local min = tonumber("0x" .. string.sub(hex, p+36, p+36+1))
		local sec = tonumber("0x" .. string.sub(hex, p+38, p+38+1))

		local timestamp = os.time({year = year, month = month, day = day, hour = hour, min = min, sec = sec})
	else
		local timestamp = os.time(os.date("!*t"))
	end


	-- current_L1 
	p = string.find(hex, "0203090601001F0700FF10")
	if p then
		local current_L1 = tonumber("0x".. string.sub(hex, p+22, p+22+3))/10
		publish_data('current_L1', current_L1, timestamp)
	end

	-- current_L2 
	p = string.find(hex, "020309060100330700FF10")
	if p then
		local current_L2 = tonumber("0x".. string.sub(hex, p+22, p+22+3))/10
		publish_data('current_L2', current_L2, timestamp)
	end
	
	-- current_L3 
	p = string.find(hex, "020309060100470700FF10")
	if p then
		local current_L3 = tonumber("0x".. string.sub(hex, p+22, p+22+3))/10
		publish_data('current_L3', current_L3, timestamp)
	end


	p = string.find(hex, "020209060101000281FF0A0B")
	if p then
		local obis_list_version = tostring("0x".. string.sub(hex, p+24, p+24+21))
		print("obis_list_version: " .. obis_list_version)
	end

	p = string.find(hex, "020209060000600100FF0A10")
	if p then
		local meter_ID = tonumber("0x".. string.sub(hex, p+24, p+24+31))
		print("meter_ID: " .. meter_ID)
	end

	p = string.find(hex, "020209060000600107FF0A04")
	if p then
		local meter_model = tostring("0x".. string.sub(hex, p+24, p+24+21))
		print("meter_model: " .. meter_model)
	end

	p = string.find(hex, "020309060100010700FF06")
	if p then
		local act_pow_pos = tonumber("0x".. string.sub(hex, p+22, p+22+7))
		publish_data('act_pow_pos', act_pow_pos, timestamp)
	end

	p = string.find(hex, "020309060100020700FF06")
	if p then
		local act_pow_neg = tonumber("0x".. string.sub(hex, p+22, p+22+7))
		publish_data('act_pow_neg', act_pow_neg, timestamp)
	end

	p = string.find(hex, "020309060100030700FF06")
	if p then
		local react_pow_pos = tonumber("0x".. string.sub(hex, p+22, p+22+7))
		publish_data('react_pow_pos', react_pow_pos, timestamp)
	end

	p = string.find(hex, "020309060100040700FF06")
	if p then
		local react_pow_neg = tonumber("0x".. string.sub(hex, p+22, p+22+7))
		publish_data('react_pow_neg', react_pow_neg, timestamp)
	end

	p = string.find(hex, "020309060100200700FF12")
	if p then
		local volt_L1 = tonumber("0x".. string.sub(hex, p+22, p+22+3))/10
		publish_data('voltage_L1', volt_L1, timestamp)
	end

	p = string.find(hex, "020309060100340700FF12")
	if p then
		local volt_L2 = tonumber("0x".. string.sub(hex, p+22, p+22+3))/10
		publish_data('voltage_L2', volt_L2, timestamp)
	end

	p = string.find(hex, "020309060100480700FF12")
	if p then
		local volt_L3 = tonumber("0x".. string.sub(hex, p+22, p+22+3))/10
		publish_data('voltage_L3', volt_L3, timestamp)
	end


	p = string.find(hex, "020309060100010800FF06")
	if p then
		local act_energy_pos = tonumber("0x".. string.sub(hex, p+22, p+22+7))
		publish_data("act_energy_pos", act_energy_pos, timestamp)
	end

	p = string.find(hex, "020309060100020800FF06")
	if p then
		local act_energy_neg = tonumber("0x".. string.sub(hex, p+22, p+22+7))
		publish_data("act_energy_neg", act_energy_neg, timestamp)
	end

	p = string.find(hex, "020309060100030800FF06")
	if p then
		local react_energy_pos = tonumber("0x".. string.sub(hex, p+22, p+22+7))
		publish_data("react_energy_pos", react_energy_pos, timestamp)
	end

	p = string.find(hex, "020309060100040800FF06")
	if p then
		local react_energy_neg = tonumber("0x".. string.sub(hex, p+22, p+22+7))
		publish_data("react_energy_neg", react_energy_neg, timestamp)
	end
end

function update_device(data) 
	print("Updating device")

	if dirty then

		local dev = setup_device(cfg.device)

		dev.meta.meter = data.status.meter
		dev.meta.ssid = data.status.ssid
		dev.meta.bssid = data.status.bssid
		dev.meta.ID = data.status.ID
		dev.updated = nil
		dev.created = nil
		dev.protected_meta = nil
		lynx.apiCall("PUT", "/api/v2/devicex/" .. app.installation_id .. "/" .. device_id, dev)
		dirty = false
	end
end


function setup_device(device) 
	local dev = findDeviceMeta({
		electric_meter_id = tostring(device)
	})

	if dev == nil then
		print("Creating device")
		local _dev = {
			type = "electric_meter",
			installation_id = app.installation_id,
			meta = {
				name = "Electric Meter: " .. device,
				electric_meter_id = tostring(device)
			}
		}
		
		lynx.apiCall("POST", "/api/v2/devicex/" .. app.installation_id , _dev)

		dev = findDeviceMeta({
			electric_meter_id = tostring(device)
		})
	end
	return dev
end

function onStart()
	print("Starting")
	device = setup_device(cfg.device);
	device_id = device.id

	mq:sub(cfg.topic_sub, 0)
	mq:bind(cfg.topic_sub, handleTrigger)
end
