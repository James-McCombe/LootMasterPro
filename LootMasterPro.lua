SLASH_AllTheThingsDebugOff1 = "/attdebugoff";
SlashCmdList.AllTheThingsDebugOff = function(cmd)
	AllTheThings.print("Force Debug Mode Off");
	AllTheThings.Debugging = false
	AllTheThings.Settings:ForceRefreshFromToggle();
	AllTheThings.Settings:SetDebugMode(false);
end

SLASH_AllTheThingsDebugOn1 = "/attdebugon";
SlashCmdList.AllTheThingsDebugOn = function(cmd)
	AllTheThings.print("Force Debug Mode On");
	AllTheThings.Debugging = true
	AllTheThings.Settings:ForceRefreshFromToggle();
	AllTheThings.Settings:SetDebugMode(true);
end

local frame = CreateFrame("Frame")

-- Functions
-- Function to filter out the original loot message
local function FilterLootMessage(self, event, message)
    if string.find(message, "You receive ") then
        return true -- This will block the original message
    end
    return false
end

-- Wait function
local function wait(delay, func, ...)
    local args = {...}
    C_Timer.After(delay, function() func(unpack(args)) end)
end

-- Latency Calculation
local function GetDecWaitDelay()
    local bandwidthIn, bandwidthOut, latencyHome, latencyWorld = GetNetStats()
    local avgLatency = ((latencyHome or 100) + (latencyWorld or 100)) / 2
    local decWaitDelay = (avgLatency * 5) / 1000
    return decWaitDelay
end

-- Define the debug flag
local isDebugMode = false -- Set to false to disable debug messages

-- Function to print debug messages
local function DebugPrint(message)
    if isDebugMode then
        print("[DEBUG]: " .. message)
    end
end


frame:RegisterEvent("CHAT_MSG_LOOT")
frame:RegisterEvent("ITEM_COUNT_CHANGED")

local pendingItemsQueue = {}
local fallbackTimer = nil
local pendingItemData = {}

-- Wait function
local function wait(delay, func, ...)
    local args = {...}
    return C_Timer.After(delay, function() func(unpack(args)) end)
end

local function fallbackCheck()
    if #pendingItemsQueue > 0 then
        local itemNumber = table.remove(pendingItemsQueue, 1)
        DebugPrint("*** Fallback ***")

		local WowApiItemCountBag = GetItemCount(itemNumber) or 0
		DebugPrint("WOW_API: No-ICC Items in Bags: " .. WowApiItemCountBag)
		DebugPrint("Original Message: " .. (pendingItemData[itemNumber].itemMessage or ""))
		DebugPrint("Item Link: " .. (pendingItemData[itemNumber].itemLink or ""))
		DebugPrint("Item Count: " .. (pendingItemData[itemNumber].itemCount or 1))
		DebugPrint("Num Bags: " .. (pendingItemData[itemNumber].numBags or 0))
		DebugPrint("Num Player: " .. (pendingItemData[itemNumber].numPlayer or 0))
		DebugPrint("Num Alts: " .. (pendingItemData[itemNumber].numAlts or 0))
		DebugPrint("Num Auctions: " .. (pendingItemData[itemNumber].numAuctions or 0))
		DebugPrint("Num Alt Auctions: " .. (pendingItemData[itemNumber].numAltAuctions or 0))
		DebugPrint("Mail: " .. (pendingItemData[itemNumber].getMail or 0))
		DebugPrint("Bank: " .. (pendingItemData[itemNumber].getBank or 0))
		DebugPrint("Guild Bank: " .. (pendingItemData[itemNumber].getGuildBank or 0))
		DebugPrint("War Bank: " .. (pendingItemData[itemNumber].getWarBankTotal or 0))

		-- Player Total: On Player, On Alts, In Warbank
		local getPlayerTotal = (pendingItemData[itemNumber].numPlayer or 0) + (pendingItemData[itemNumber].numAlts or 0) + (pendingItemData[itemNumber].getWarBankTotal or 0)
		DebugPrint("Player Total: " .. getPlayerTotal)
		local itemDifference = WowApiItemCountBag - (pendingItemData[itemNumber].numBags or 0)
		DebugPrint("Item Difference: " .. itemDifference)
		if itemDifference == (pendingItemData[itemNumber].itemCount or 0) then
			getPlayerTotal = getPlayerTotal + pendingItemData[itemNumber].itemCount
			DebugPrint("New Player Total: " .. getPlayerTotal)
			DebugPrint("Items in Bags: " .. WowApiItemCountBag)
		end

		local itemString = TSM_API.ToItemString((pendingItemData[itemNumber].itemLink or ""))

		local intPricedbMarketValue = (pendingItemData[itemNumber].itemCount or 1) * (TSM_API.GetCustomPriceValue("dbMarket", itemString) or 0)
		local strPricedbMarketString = TSM_API.FormatMoneyString(intPricedbMarketValue)
		local intPriceVendorSellValue = (pendingItemData[itemNumber].itemCount or 1) * (TSM_API.GetCustomPriceValue("VendorSell", itemString) or 0)
		local strPriceVendorSellValue = TSM_API.FormatMoneyString(intPriceVendorSellValue)
		
		if WowApiItemCountBag == 0 then
			DEFAULT_CHAT_FRAME:AddMessage("|cff009900" .. (pendingItemData[itemNumber].itemMessage or ""))
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cff009900" .. (pendingItemData[itemNumber].itemMessage or "") .. "|cffffffff [Tot: " .. getPlayerTotal .. ", Bag: " .. WowApiItemCountBag ..", Alt: " .. (pendingItemData[itemNumber].numAlts or 0) .. ", AH: " .. (pendingItemData[itemNumber].numAuctions or 0) + (pendingItemData[itemNumber].numAltAuctions or 0) .. ", WB: " .. (pendingItemData[itemNumber].getWarBankTotal or 0) .. "] [AH: " .. strPricedbMarketString .. " V: " .. strPriceVendorSellValue .. "]")
		end
		
		pendingItemData[itemNumber] = nil

    end
end

local function printTable(tbl, indent)
    if not indent then indent = 0 end
    for k, v in pairs(tbl) do
        local formatting = string.rep("  ", indent) .. k .. ": "
        if type(v) == "table" then
            print(formatting)
            printTable(v, indent + 1)
        else
            print(formatting .. tostring(v))
        end
    end
end

-- Add the filter function to the chat frame
ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", FilterLootMessage)

frame:SetScript("OnEvent", function(self, event, ...)
    DebugPrint("Event triggered: " .. event)
    if event == "CHAT_MSG_LOOT" and string.find((...), "You receive ") then
        local message = ...
        DebugPrint("CHAT_MSG_LOOT message: " .. message)
        local itemLink = message:match("|Hitem:.-|h.-|h")
        local itemCount = tonumber(message:match("x(%d+)")) or 1
        local itemString = TSM_API.ToItemString(itemLink)
        local itemNumber = itemString:gsub("i:", "")
        local numBags = TSM_API.GetBagQuantity(itemString) or 0
        local numPlayer, numAlts, numAuctions, numAltAuctions = TSM_API.GetPlayerTotals(itemString)
        local getMail = TSM_API.GetMailQuantity(itemString) or 0
		local getBank = TSM_API.GetBankQuantity(itemString) or 0
        local getGuildBank = TSM_API.GetGuildQuantity(itemString) or 0
        local getWarBankTotal = TSM_API.GetWarbankQuantity(itemString) or 0

        table.insert(pendingItemsQueue, itemNumber)
        pendingItemData[itemNumber] = {
			itemMessage = message,
            itemLink = itemLink,
            itemCount = itemCount,
            numBags = numBags,
            numPlayer = numPlayer,
            numAlts = numAlts,
            numAuctions = numAuctions,
            numAltAuctions = numAltAuctions,
            getMail = getMail,
			getBank = getBank,
            getGuildBank = getGuildBank,
            getWarBankTotal = getWarBankTotal
        }
        DebugPrint("Added item to queue: " .. itemNumber)
        if #pendingItemsQueue > 0 and not fallbackTimer then
            fallbackTimer = wait(2, fallbackCheck)
            DebugPrint("Fallback timer set")
        end

    elseif event == "ITEM_COUNT_CHANGED" then
        local itemNumber = tostring(...)
        -- DebugPrint("ITEM_COUNT_CHANGED for item number: " .. itemNumber)
        -- DebugPrint("Type of itemNumber: " .. type(itemNumber))
        -- DebugPrint("Pending item data: " .. tostring(pendingItemData[itemNumber]))
        -- DebugPrint("Current pendingItemData contents:")
        -- printTable(pendingItemData)
        --[[for k, v in pairs(pendingItemData) do
            DebugPrint("Key: " .. k .. ", Type: " .. type(k))
        end]]
        if pendingItemData[itemNumber] then
            DebugPrint("Handled ITEM_COUNT_CHANGED for item number: " .. itemNumber)
            local WowApiItemCountBag = GetItemCount(itemNumber) or 0
            DebugPrint("WOW_API: ICC Items in Bags: " .. WowApiItemCountBag)
            DebugPrint("Original Message: " .. (pendingItemData[itemNumber].itemMessage or ""))
            DebugPrint("Item Link: " .. (pendingItemData[itemNumber].itemLink or ""))
            DebugPrint("Item Count: " .. (pendingItemData[itemNumber].itemCount or 1))
            DebugPrint("Num Bags: " .. (pendingItemData[itemNumber].numBags or 0))
            DebugPrint("Num Player: " .. (pendingItemData[itemNumber].numPlayer or 0))
            DebugPrint("Num Alts: " .. (pendingItemData[itemNumber].numAlts or 0))
            DebugPrint("Num Auctions: " .. (pendingItemData[itemNumber].numAuctions or 0))
            DebugPrint("Num Alt Auctions: " .. (pendingItemData[itemNumber].numAltAuctions or 0))
            DebugPrint("Mail: " .. (pendingItemData[itemNumber].getMail or 0))
            DebugPrint("Bank: " .. (pendingItemData[itemNumber].getBank or 0))
            DebugPrint("Guild Bank: " .. (pendingItemData[itemNumber].getGuildBank or 0))
            DebugPrint("War Bank: " .. (pendingItemData[itemNumber].getWarBankTotal or 0))

			-- Player Total: On Player, On Alts, In Warbank
			local getPlayerTotal = (pendingItemData[itemNumber].numPlayer or 0) + (pendingItemData[itemNumber].numAlts or 0) + (pendingItemData[itemNumber].getWarBankTotal or 0)
			DebugPrint("Player Total: " .. getPlayerTotal)
			local itemDifference = WowApiItemCountBag - (pendingItemData[itemNumber].numBags or 0)
			DebugPrint("Item Difference: " .. itemDifference)
			if itemDifference == (pendingItemData[itemNumber].itemCount or 0) then
				getPlayerTotal = getPlayerTotal + pendingItemData[itemNumber].itemCount
				DebugPrint("New Player Total: " .. getPlayerTotal)
				DebugPrint("Items in Bags: " .. WowApiItemCountBag)
			end

			local itemString = TSM_API.ToItemString((pendingItemData[itemNumber].itemLink or ""))

			local intPricedbMarketValue = (pendingItemData[itemNumber].itemCount or 1) * (TSM_API.GetCustomPriceValue("dbMarket", itemString) or 0)
			local strPricedbMarketString = TSM_API.FormatMoneyString(intPricedbMarketValue)
			local intPriceVendorSellValue = (pendingItemData[itemNumber].itemCount or 1) * (TSM_API.GetCustomPriceValue("VendorSell", itemString) or 0)
			local strPriceVendorSellValue = TSM_API.FormatMoneyString(intPriceVendorSellValue)
			
			DEFAULT_CHAT_FRAME:AddMessage("|cff009900" .. (pendingItemData[itemNumber].itemMessage or "") .. "|cffffffff [Tot: " .. getPlayerTotal .. ", Bag: " .. WowApiItemCountBag ..", Alt: " .. (pendingItemData[itemNumber].numAlts or 0) .. ", AH: " .. (pendingItemData[itemNumber].numAuctions or 0) + (pendingItemData[itemNumber].numAltAuctions or 0) .. ", WB: " .. (pendingItemData[itemNumber].getWarBankTotal or 0) .. "] [AH: " .. strPricedbMarketString .. " V: " .. strPriceVendorSellValue .. "]")
			
            pendingItemData[itemNumber] = nil


            -- Remove the item from the queue
            for i, num in ipairs(pendingItemsQueue) do
                if num == itemNumber then
					DebugPrint("Removed Item From pendingItemsQueue: " .. num)
                    table.remove(pendingItemsQueue, i)
                    break
                end
            end

            -- Cancel the fallback check if the queue is empty
            if #pendingItemsQueue == 0 and fallbackTimer then
                fallbackTimer:Cancel()
                fallbackTimer = nil
                DebugPrint("Fallback timer canceled")
            end
        else
            DebugPrint("Item number not found in pendingItemData")
        end
    end
end)




--[[
-- Add the filter function to the chat frame
ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", FilterLootMessage)

frame:SetScript("OnEvent", function(self, event, message)
    if event == "CHAT_MSG_LOOT" and string.find(message, "You receive ") then
	
		-- Get Latency Calculated Delay
		local decWaitDelay = GetDecWaitDelay()

        -- Extract the item link from the message
        local itemLink = message:match("|Hitem:.-|h.-|h")
        local intItemCount = tonumber(message:match("x(%d+)")) or 1
        local itemString = TSM_API.ToItemString(itemLink)
        local itemNumber = itemString:gsub("i:", "")
        local intNumPlayer, intNumAlts, intNumAuctions, intNumAltAuctions = TSM_API.GetPlayerTotals(itemString)
        local intNumBags = TSM_API.GetBagQuantity(itemString) or 0
        local intMail = TSM_API.GetMailQuantity(itemString) or 0
        local intGetGuildBank = TSM_API.GetGuildQuantity(itemString) or 0
        local intWarBankTotal = TSM_API.GetWarbankQuantity(itemString) or 0
        local intNumInBagsLocal = GetItemCount(itemNumber) or 0
		
		local intPricedbMarketValue = intItemCount * (TSM_API.GetCustomPriceValue("dbMarket", itemString) or 0)
		local strPricedbMarketString = TSM_API.FormatMoneyString(intPricedbMarketValue)
		local intPriceVendorSellValue = intItemCount * (TSM_API.GetCustomPriceValue("VendorSell", itemString) or 0)
		local strPriceVendorSellValue = TSM_API.FormatMoneyString(intPriceVendorSellValue)

		DebugPrint("WOW_API: Item Number: " .. itemNumber)
		DebugPrint("WOW_API: Items Collected: " .. intItemCount)
		local WowApiItemCountBag = GetItemCount(itemNumber) or 0
		DebugPrint("WOW_API: Items in Bags: " .. WowApiItemCountBag)
		local WowApiItemCountBank = (GetItemCount(itemNumber, true) or 0) - WowApiItemCountBag
		DebugPrint("WOW_API: Items in Bank: " .. WowApiItemCountBank)
		local WowApiItemCountReagentBank = (GetItemCount(itemNumber, false, false, true) or 0) - WowApiItemCountBag
		DebugPrint("WOW_API: Items in Reagent Bank: " .. WowApiItemCountReagentBank)

		local TSMApiItemCountBag = TSM_API.GetBagQuantity(itemString) or 0
		DebugPrint("TSM_API: Items in Bags: " .. TSMApiItemCountBag)
		local TSMApiItemCountBank = TSM_API.GetBankQuantity(itemString) or 0
		DebugPrint("TSM_API: Items in Bank: " .. TSMApiItemCountBank)
		local TSMApiItemCountReagentBank = TSM_API.GetReagentBankQuantity(itemString) or 0
		DebugPrint("TSM_API: Items in Reagent Bank: " .. TSMApiItemCountReagentBank)
		


        -- Add a message before the delay
        if (intNumBags + intItemCount) ~= intNumInBagsLocal then
            wait(decWaitDelay, function()
				local intNumPlayer, intNumAlts, intNumAuctions, intNumAltAuctions = TSM_API.GetPlayerTotals(itemString)
				local intNumBags = TSM_API.GetBagQuantity(itemString) or 0
				local intNumInBagsLocal = GetItemCount(itemNumber) or 0

				if (intNumBags + intItemCount) ~= intNumInBagsLocal then
					wait(decWaitDelay, function()
						local intNumInBagsLocal = GetItemCount(itemNumber) or 0
						local intNumPlayer, intNumAlts, intNumAuctions, intNumAltAuctions = TSM_API.GetPlayerTotals(itemString)
						DEFAULT_CHAT_FRAME:AddMessage("|cff009900" .. message .. "|cffffffff [Tot: " .. intNumPlayer .. ", Bag: " .. intNumInBagsLocal ..", Alt: " .. intNumAlts .. ", AH: " .. intNumAuctions + intNumAltAuctions .. ", WB: " .. intWarBankTotal .. "] [AH: " .. strPricedbMarketString .. " V: " .. strPriceVendorSellValue .. "]")
					end)
				else
					DEFAULT_CHAT_FRAME:AddMessage("|cff009900" .. message .. "|cffffffff [Tot: " .. intNumPlayer .. ", Bag: " .. intNumInBagsLocal ..", Alt: " .. intNumAlts .. ", AH: " .. intNumAuctions + intNumAltAuctions .. ", WB: " .. intWarBankTotal .. "] [AH: " .. strPricedbMarketString .. " V: " .. strPriceVendorSellValue .. "]")
				end

            end)
        else
            -- If no delay needed, print the custom message immediately
			DEFAULT_CHAT_FRAME:AddMessage("|cff009900" .. message .. "|cffffffff [Tot: " .. intNumPlayer .. ", Bag: " .. intNumInBagsLocal ..", Alt: " .. intNumAlts .. ", AH: " .. intNumAuctions + intNumAltAuctions .. ", WB: " .. intWarBankTotal .. "] [AH: " .. strPricedbMarketString .. " V: " .. strPriceVendorSellValue .. "]")
        end
    end
end)
]]
