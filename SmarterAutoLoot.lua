
local SmarterAutoLoot = ZO_Object:Subclass()
SmarterAutoLoot.db = nil
SmarterAutoLoot.config = nil
SmarterAutoLoot.version = "1.8"

local CBM = CALLBACK_MANAGER
local Config = SmarterAutoLootSettings

function SmarterAutoLoot:New( ... )
	local result = ZO_Object.New( self )
	result:Initialize( ... )
	return result
end

function SmarterAutoLoot:Initialize( control )
	self.control = control
	self.control:RegisterForEvent( EVENT_ADD_ON_LOADED, function( ... ) self:OnLoaded( ... ) end )
	CBM:RegisterCallback( Config.EVENT_TOGGLE_AUTOLOOT, function() self:ToggleAutoLoot() end )
end

function SmarterAutoLoot:OnLoaded( event, addon )
	if ( addon ~="SmarterAutoLoot" ) then return end

	self.db = ZO_SavedVars:New( "SAL_VARS", 1, nil, Config.defaults )
	self.config = Config:New( self.db )

	if ( self.db.allowDestroy ) then
		self.buttonDestroyRemaining = CreateControlFromVirtual( "buttonDestroyRemaining", ZO_Loot, "BTN_DestroyRemaining" )
	end
	self:ToggleAutoLoot()
end

function SmarterAutoLoot:ToggleAutoLoot()
	if( self.db.enabled ) then
		self.control:RegisterForEvent( EVENT_LOOT_UPDATED, function( eventId ) self:OnLootUpdated() end )
	else
		self.control:UnregisterForEvent( EVENT_LOOT_UPDATED )
	end
end


function SmarterAutoLoot:LootItem( item, reason )

	if ( not CheckInventorySpaceSilently( 1 ) and not self:CanStackItem( item ) ) then

		if ( not self.displayedFull ) then
			d( "Cannot auto loot " .. item.link .. ", inventory full!" )
			CheckInventorySpaceAndWarn( 1 ) -- Make noise
			self.displayedFull = true
		end

		return

	end

	LootItemById( item.lootId )

	if ( not self.db.printItems ) then return end

	local itemType = GetItemLinkItemType( item.link )
	local text = tostring( item.link )
	if ( text:len() == 0 ) then text = "|cD2B41E" .. item.name .. "|" end
	d( "|cDCDCCCYou looted| " .. text .. " (" .. tostring( reason ) .. ", type " .. tostring( itemType ) .. ") " )
end

function SmarterAutoLoot:DestroyItems()
	local num = GetNumLootItems()

	-- d( "Actually destroying" )
	self.destroying = true
	self.control:RegisterForEvent( EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function( _, ... ) self:OnInventoryUpdated( ... ) end )
	self.control:RegisterForEvent( EVENT_LOOT_CLOSED, function( _, ... ) self:OnLootClosed( ... ) end )
	for i = 1, num , 1 do
		local lootId, name, icon, quantity, quality, value, isQuest, isStolen = GetLootItemInfo( i )
		-- d( "Looting item to destroy..."..name )
		LootItemById( lootId )
	end
	self.destroying = false
	EndLooting()
end


function SmarterAutoLoot:OnInventoryUpdated( bagId, slotId, isNewItem, _, _ )
	-- d( "OnInventoryUpdated" )
	if ( not self.destroying or not self.db.allowDestroy or not isNewItem ) then return end

	--local link = GetItemLink( bagId, slotId )
	-- d( "Destroying "..link )
	if ( self.db.allowDestroy ) then
		-- d( "Actually destroying" )
		DestroyItem( bagId,slotId )
	end
end

function SmarterAutoLoot:OnLootClosed( eventCode )
	self.control:UnregisterForEvent( EVENT_INVENTORY_SINGLE_SLOT_UPDATE )
	self.control:UnregisterForEvent( EVENT_LOOT_CLOSED )
end

function SmarterAutoLoot:PassesFilter( filterType, lootId, quality, value, isStolen )

	--local link = GetLootItemLink( lootId )
	--local info1 , sellPrice, usable, equipType, style = GetItemLinkInfo( link )

	if ( filterType == nil ) then return false end

	-- Steal treasure while hidden
	local isHidden = GetUnitStealthState( "player" ) == STEALTH_STATE_HIDDEN or GetUnitStealthState( "player" ) == STEALTH_STATE_HIDDEN_ALMOST_DETECTED
	local shouldSteal = self.db.stealWhileVisible or isHidden

	if ( filterType == SALFILTER_NEVER ) then return false end
	if ( filterType == SALFILTER_ALWAYS and ( shouldSteal or not isStolen ) ) then return true end

	if ( filterType == SALFILTER_ONLY_STOLEN and isStolen and shouldSteal ) then return true end
	if ( filterType == SALFILTER_ONLY_LEGAL and not isStolen ) then return true end
	
	--[[if ( filterType == SALFILTER_PER_QUALITY and quality >= self.db.minimumQuality ) then return true end
	if ( filterType == SALFILTER_PER_VALUE and value >= self.db.minimumValue ) then return true end

	if ( filterType == SALFILTER_PER_QUALITY_OR_VALUE ) then
		if ( quality >= self.db.minimumQuality or value >= self.db.minimumValue ) then return true end
	end

	if ( filterType == SALFILTER_PER_QUALITY_AND_VALUE ) then
		if ( quality >= self.db.minimumQuality and value >= self.db.minimumValue ) then return true end
	end]]

	return false
end

local typeFilterNames = {
	[ ITEMTYPE_RECIPE ] = "recipes",
	[ ITEMTYPE_RACIAL_STYLE_MOTIF ] = "recipes",
	[ ITEMTYPE_MASTER_WRIT ] = "recipes",
	[ ITEMTYPE_TROPHY ] = "recipes", -- Runeboxes

	[ ITEMTYPE_FOOD ] = "foodAndDrink",
	[ ITEMTYPE_DRINK ] = "foodAndDrink",

	[ ITEMTYPE_POTION ] = "potions",
	[ ITEMTYPE_POISON ] = "poisons",
	[ ITEMTYPE_SOUL_GEM ] = "soulGems",

	[ ITEMTYPE_LURE ] = "fishingBait",
	[ ITEMTYPE_FISH ] = "craftingMaterials",
	[ ITEMTYPE_TOOL ] = "tools",
	[ ITEMTYPE_LOCKPICK ] = "tools",
	[ ITEMTYPE_CONTAINER_CURRENCY ] = "tools",
	[ ITEMTYPE_CONTAINER ] = "tools",
	[ ITEMTYPE_SIEGE ] = "tools", --siege thingg
	[ ITEMTYPE_AVA_REPAIR ] = "tools", --siege thingg

	[ ITEMTYPE_GLYPH_ARMOR ] = "glyphs",
	[ ITEMTYPE_GLYPH_JEWELRY ] = "glyphs",
	[ ITEMTYPE_GLYPH_WEAPON ] = "glyphs",

	[ ITEMTYPE_BLACKSMITHING_BOOSTER ] = "craftingMaterials",
	[ ITEMTYPE_BLACKSMITHING_MATERIAL ] = "craftingMaterials",
	[ ITEMTYPE_BLACKSMITHING_RAW_MATERIAL ] = "craftingMaterials",

	[ ITEMTYPE_CLOTHIER_BOOSTER  ] = "craftingMaterials",
	[ ITEMTYPE_CLOTHIER_MATERIAL ] = "craftingMaterials",
	[ ITEMTYPE_CLOTHIER_RAW_MATERIAL ] = "craftingMaterials",

	[ ITEMTYPE_WOODWORKING_BOOSTER  ] = "craftingMaterials",
	[ ITEMTYPE_WOODWORKING_MATERIAL ] = "craftingMaterials",
	[ ITEMTYPE_WOODWORKING_RAW_MATERIAL ] = "craftingMaterials",

	[ ITEMTYPE_POTION_BASE ] = "potionIngredients",
	[ ITEMTYPE_POISON_BASE ] = "potionIngredients",
	[ ITEMTYPE_REAGENT ] = "potionIngredients",

	[ ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL ] = "craftingMaterials",

	[ ITEMTYPE_ENCHANTING_RUNE_ASPECT ] = "craftingMaterials",
	[ ITEMTYPE_ENCHANTING_RUNE_ESSENCE ] = "craftingMaterials",
	[ ITEMTYPE_ENCHANTING_RUNE_POTENCY ] = "craftingMaterials",

	[ ITEMTYPE_RAW_MATERIAL ] = "styleMaterials",
	[ ITEMTYPE_STYLE_MATERIAL ] = "styleMaterials",
	[ ITEMTYPE_ENCHANTMENT_BOOSTER ] = "styleMaterials",
	
	[ ITEMTYPE_FURNISHING_MATERIAL ] = "furnitureCraftingMaterials",
	[ ITEMTYPE_FURNISHING ] = "furnitureCraftingMaterials", -- actual furniture

	[ ITEMTYPE_JEWELRY_TRAIT ] = "traitMaterials",
	[ ITEMTYPE_ARMOR_TRAIT ] = "traitMaterials",
	[ ITEMTYPE_JEWELRY_RAW_TRAIT ] = "traitMaterials",
	[ ITEMTYPE_WEAPON_TRAIT ] = "traitMaterials",

	[ ITEMTYPE_INGREDIENT ] = "ingredients",
	[ ITEMTYPE_FLAVORING ] = "ingredients",
	[ ITEMTYPE_SPICE ] = "ingredients",

	[ ITEMTYPE_COSTUME ] = "costumes",
	[ ITEMTYPE_DISGUISE ] = "costumes",

	[ ITEMTYPE_COLLECTIBLE ] = "collectibles",
	[ ITEMTYPE_WEAPON ] = "weapons",
	[ ITEMTYPE_ARMOR ] = "armor",

	[ ITEMTYPE_TRASH ] = "trash",
	[ ITEMTYPE_TREASURE ] = "trash",
}

-- Whether we can pick up this item without increasing item count in backpack
function SmarterAutoLoot:CanStackItem( item )

	local stackable = IsItemLinkStackable( item.link )
	local bagCount = GetItemLinkStacks( item.link )
	-- TODO: Doesn't check stack sizes!!!

	if ( ( bagCount > 0 and stackable ) or ( HasCraftBagAccess() and CanItemLinkBeVirtual( item.link ) and not item.isStolen ) or item.isQuest ) then
		return true
	end

	return false

end

function string.startsWith( str, teststr ) return string.sub( str, 1, string.len( teststr ) ) == teststr end
function string.endsWith( str, suffix ) return str:sub( -#suffix ) == suffix end

function SmarterAutoLoot:ShouldLootItem( item )

	--if ( not CheckInventorySpaceSilently( 1 ) and not self:CanStackItem( item ) ) then return nil end

	--local icon, sellPrice, usable, equipType, style = GetItemLinkInfo( item.link )

	-- If it is a quest item, we want it no matter what
	if ( item.isQuest ) then return "quest" end

	-- TODO: Find a better way to detect these
	if ( string.startsWith( tostring( item.name ), "Lead:" ) ) then return "lead" end
	if ( string.startsWith( tostring( item.name ), "Trophy:" ) ) then return "trophy" end
	if ( string.endsWith( tostring( item.name ), "Deck Fragment" ) ) then return "deck_frag" end

	-- We want to loot containers completely no matter what
	if ( item.isContainer ) then return "container" end

	-- Already in our bag..
	local bagCount = GetItemLinkStacks( item.link )
	local stackable = IsItemLinkStackable( item.link )
	if ( bagCount > 0 and self.db.lootIfInBag and stackable and not item.isStolen ) then return "in bag" end

	-- Can be placed in craft bag? Auto loot always
	if ( HasCraftBagAccess() and CanItemLinkBeVirtual( item.link ) and not item.isStolen ) then return "craft baggable" end

	local trait = GetItemLinkTraitInfo( item.link )

	-- Ornate
	if ( trait == ITEM_TRAIT_TYPE_ARMOR_ORNATE or trait == ITEM_TRAIT_TYPE_WEAPON_ORNATE ) then
		if ( self:PassesFilter( self.db.filters.ornate, item.lootId, item.quality, item.value, item.isStolen ) ) then
			 return "ornate"
		end
	end

	-- Intricate
	if ( trait == ITEM_TRAIT_TYPE_ARMOR_INTRICATE or trait == ITEM_TRAIT_TYPE_WEAPON_INTRICATE ) then
		if ( self:PassesFilter( self.db.filters.intricate, item.lootId, item.quality, item.value, item.isStolen ) ) then
			 return "intricate"
		end
	end

	-- Minimum Value
	if ( self.db.minimumValue > 0 and item.value >= self.db.minimumValue and not item.isStolen ) then return "min value" end

	-- Minimum quality
	if ( item.quality >= self.db.minimumQuality and self.db.minimumQuality > -1 and not item.isStolen ) then return "min quality" end

	local itemType = GetItemLinkItemType( item.link )
	local filterType = typeFilterNames[ itemType ]

	-- Item type filters
	if ( filterType ) then

		if ( self:PassesFilter( self.db.filters[ filterType ], item.lootId, item.quality, item.value, item.isStolen ) ) then

			return filterType

		end

	else
		d( "SAL: Unknown item type " .. tostring( itemType ) )
	end

end

-- TODO: Auto destroy trash or 0 value stuff? Only marked as junk?
function SmarterAutoLoot:OnLootUpdated()

	local name, targetType, actionName, isOwned = GetLootTargetInfo()
	local isContainer = ( targetType == INTERACT_TARGET_TYPE_ITEM )
	--d("ON LOOT UPDATED ", tostring( name ), tostring( targetType ), tostring( actionName ), tostring( isOwned ) )

	LootMoney()
	LootCurrency( CURT_TELVAR_STONES ) -- TELVAR STONES
	--LootCurrency( CURT_STYLE_STONES )
	LootCurrency( CURT_CHAOTIC_CREATIA ) -- Transmute Crystal

	-- Container...
	--[[if ( targetType == INTERACT_TARGET_TYPE_ITEM ) then
		d( "Looting container..." )
		LootAll( true ) -- TODO: true only when hidden?

		--EndLooting()
		--SCENE_MANAGER:ShowBaseScene()
		-- TODO: Bring back inventory somehow?
		return
	end]]

	self.displayedFull = false

	-- Pick up good items first
	local idsByQuality = {}
	for i = 1, GetNumLootItems() do
		local lootId = GetLootItemInfo( i )
		local link = GetLootItemLink( lootId )

		local lootId, name, icon, quantity, quality, value, isQuest, isStolen = GetLootItemInfo( i )
		idsByQuality[ i ] = {
			quality = GetItemLinkDisplayQuality( link ),
			item = {
				lootId = lootId,
				name = name,
				icon = icon,
				quantity = quantity,
				quality = quality,
				value = value,
				isQuest = isQuest,
				isStolen = isStolen,
				link = GetLootItemLink( lootId ),
				isContainer = isContainer,
			}
		}
	end

	local canStack = 0
	local wantLoot = 0
	for i, t in pairs( idsByQuality ) do
		if ( self:CanStackItem( t.item ) ) then -- TODO: Does not handle stack sizes!
			canStack = canStack + 1
		elseif ( self:ShouldLootItem( t.item ) ~= nil ) then
			wantLoot = wantLoot + 1
		end
	end

	-- This is so you can choose which items to get when there's not enough inventory space.
	-- TODO: Check how many of these items would be actually picked up
	if ( not CheckInventorySpaceSilently( wantLoot ) ) then
		d( "Not looting, not enough space." )
		return
	end

	table.sort( idsByQuality, function( a, b ) return a.quality > b.quality end )

	for i, t in pairs( idsByQuality ) do
		local filter = self:ShouldLootItem( t.item )
		if ( filter ~= nil ) then
			self:LootItem( t.item, filter )
		else
		
			local itemType, specialType = GetItemLinkItemType( t.item.link )
			local useType = GetItemLinkItemUseType( t.item.link )
			if ( itemType == 0 and specialType == 0 and useType == 0 ) then
				d( "SAL: NOT LOOTING Name: " .. tostring( t.item.name ) .. ", Link:".. tostring( t.item.link ) )
			end

		end
	end

	if ( self.db.closeLootWindow or GetNumLootItems() == 0 ) then
		EndLooting()
	end

end


function SmarterAutoLoot_Startup( self )
	_Instance = SmarterAutoLoot:New( self )
end

--[[
function SmarterAutoLoot_Destroy( self )
	-- d( "Destroy Contents" )
	--_Instance:DestroyItems()
end

function SmarterAutoLoot:Reset()
end
]]
