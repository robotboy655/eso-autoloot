
local FilterTexts = {}

local FilterOptionId = 0
local function FilterOption( label )
	FilterOptionId = FilterOptionId + 1
	table.insert( FilterTexts, label )
	return FilterOptionId
end

SALFILTER_NEVER =					FilterOption( "|cFF8888Disable|r" )
SALFILTER_ALWAYS =					FilterOption( "|c88FF88Always Loot|r" )
SALFILTER_ONLY_STOLEN =				FilterOption( "|cFFFFFFOnly|r |cFF0000Stolen|r" )
SALFILTER_ONLY_LEGAL =				FilterOption( "|cFFFFFFOnly|r |c00FF00Legal|r" )
--[[SALFILTER_PER_QUALITY = 			FilterOption( "per quality threshold" )
SALFILTER_PER_VALUE =				FilterOption( "per value threshold" )
SALFILTER_PER_QUALITY_OR_VALUE =	FilterOption( "per quality OR value" )
SALFILTER_PER_QUALITY_AND_VALUE =	FilterOption( "per quality AND value" )]]


SmarterAutoLootSettings							= ZO_Object:Subclass()
SmarterAutoLootSettings.db						= nil
SmarterAutoLootSettings.EVENT_TOGGLE_AUTOLOOT	= "SMARTERAUTOLOOT_TOGGLE_AUTOLOOT"
SmarterAutoLootSettings.defaults =
{
	enabled = true,
	printItems = false,
	closeLootWindow = false,
	minimumQuality = 4,
	minimumValue = 1000,
	lootIfInBag = true,
	allowDestroy = false,
	stealWhileVisible = false,
	filters = {
		craftingMaterials = SALFILTER_ALWAYS
	}
}

if ( not LibAddonMenu2 ) then return end

function SmarterAutoLootSettings:New( ... )
	local result = ZO_Object.New( self )
	result:Initialize( ... )
	return result
end


local choices = {}
local choicesValues = {}

for k, v in pairs( FilterTexts ) do
	table.insert( choices, v )
	table.insert( choicesValues, k )
end

function SmarterAutoLootSettings:CreateFilterDropdown( title, filterName )
	local def = self.defaults.filters[ filterName ] or SALFILTER_NEVER

	return {
		type = "dropdown",
		name = title,
		choices = choices,
		choicesValues = choicesValues,
		getFunc = function() return self.db.filters[ filterName ] end,
		setFunc = function( value ) self.db.filters[ filterName ] = value end,
		default = def,
	}
end

function SmarterAutoLootSettings:Initialize( db )
	self.db = db

	local optionsData =
	{
		{ type = "header", name = "General Settings" },
		{
			type = "checkbox",
			name = "Enable Smarter AutoLoot",
			getFunc = function() return self.db.enabled end,
			setFunc = function( value ) self:ToggleAutoLoot() end,
			default = true,
		},
		{
			type = "checkbox",
			name = "Show Item Links",
			tooltip = "If enabled, item links for each item looted will be displayed in the chat window for reference. They will not be sent to chat, only displayed for you.",
			getFunc = function() return self.db.printItems end,
			setFunc = function( value ) self.db.printItems = value end,
			default = false,
		},
		{
			type = "checkbox",
			name = "Close Loot Window",
			tooltip = "If any items are NOT autolooted due to filters, should the loot window be closed with the items still in the container?",
			getFunc = function() return self.db.closeLootWindow end,
			setFunc = function( value ) self.db.closeLootWindow = value end,
			default = false,
		},

		{ type = "header", name = "Global AutoLoot Settings" },
		{
			type = "dropdown",
			name = "Always Loot By Quality",
			choices = { "|cc5c29eDisable|r", "|cA6A6A6Trash|r", "|cFFFFFFCommon|r", "|c2DC50EFine|r", "|c3A92FFSuperior|r", "|cA02EF7Epic|r", "|cCCAA1ALegendary+|r" },
			choicesValues = { -1, 0, 1, 2, 3, 4, 5 },
			tooltip = "Always pick up items at given rarity and higher. Set to \"Do not loot\" to disable this filter.",
			getFunc = function() return self.db.minimumQuality end,
			setFunc = function( value ) self.db.minimumQuality = value end,
			default = 4,
		},
		{
			type = "slider",
			name = "Always Loot By Value",
			tooltip = "Always pick up items at given in-game value or higher. Set to 0 to disable this filter.",
			min = 0,
			max = 10000,
			getFunc = function() return self.db.minimumValue end,
			setFunc = function( value ) self.db.minimumValue = value end,
			default = 0,
		},
		{
			type = "checkbox",
			name = "Fill Existing Stacks",
			tooltip = "Bypass all filters if you already have a non full stack of the item in your inventory.",
			getFunc = function() return self.db.lootIfInBag end,
			setFunc = function( value ) self.db.lootIfInBag = value end,
			default = false
		},
		{
			type = "checkbox",
			name = "Steal When Not Hidden",
			tooltip = "By default stolen items will only be auto looted if you are currently hidden (in stealth). Turn this on if you want to steal while visible as well.",
			getFunc = function() return self.db.stealWhileVisible end,
			setFunc = function( value ) self.db.stealWhileVisible = value end,
			default = false
		},
		{
			type = "checkbox",
			name = "Destroy leftover items (USE AT YOUR OWN RISK!)",
			tooltip = "Should SmarterAutoLoot be allowed to auto destroy left over items? USE AT YOUR OWN RISK!",
			getFunc = function() return self.db.allowDestroy end,
			setFunc = function( value ) self.db.allowDestroy = value; ReloadUI() end,
			default = false,
			warning = "Requires Reload of UI! USE AT YOUR OWN RISK!"
		},

		-- TODO: Destroy 0 value and trash items when inventory is full
		-- TODO: Steal trasure when hidden

		{ type = "header", name = "Loot Filters: Consumables" },
		self:CreateFilterDropdown( "Cooking Recipes, Motifs & Runeboxes", "recipes" ),

		self:CreateFilterDropdown( "Crafting Materials", "craftingMaterials" ),
		self:CreateFilterDropdown( "Style Materials", "styleMaterials" ),
		self:CreateFilterDropdown( "Trait Materials", "traitMaterials" ),
		self:CreateFilterDropdown( "Cooking Ingredients", "ingredients" ),
		self:CreateFilterDropdown( "Potion Ingredients", "potionIngredients" ),
		self:CreateFilterDropdown( "Furniture Crafting Materials", "furnitureCraftingMaterials" ),

		self:CreateFilterDropdown( "Food & Drinks", "foodAndDrink" ),
		self:CreateFilterDropdown( "Containers, Tools & Lockpicks", "tools" ),
		self:CreateFilterDropdown( "Potions", "potions" ),
		self:CreateFilterDropdown( "Poisons", "poisons" ),
		self:CreateFilterDropdown( "Glyphs", "glyphs" ),

		{ type = "header", name = "Loot Filters: Other" },
		self:CreateFilterDropdown( "Weapons", "weapons" ),
		self:CreateFilterDropdown( "Armor & Jewelry", "armor" ),
		
		self:CreateFilterDropdown( "Fishing Bait", "fishingBait" ),
		self:CreateFilterDropdown( "Soul Gems", "soulGems" ),
		self:CreateFilterDropdown( "Costumes & Disguises", "costumes" ),

		self:CreateFilterDropdown( "Collectibles", "collectibles" ), -- What is this?

		self:CreateFilterDropdown( "Intricate Items", "intricate" ),
		self:CreateFilterDropdown( "Ornate Items", "ornate" ),
		self:CreateFilterDropdown( "Trash & Treasure", "trash" ),
		--self:CreateFilterDropdown( "Needed Research", "neededResearch" ),
	}

	LibAddonMenu2:RegisterAddonPanel( "SmarterAutoLootOptions", {
		type = "panel",
		name = "|cb8b8b8Smarter AutoLoot|r |c53fa00Revamped|r",
		author = "|cfa9f00Agathorn |rand |c75fa00Rubat|r",
		version = "1.8",
		website = "https://github.com/robotboy655/TODO",
		slashCommand = "/sal"
	} )

	LibAddonMenu2:RegisterOptionControls( "SmarterAutoLootOptions", optionsData )
end

function SmarterAutoLootSettings:ToggleAutoLoot()
	self.db.enabled = not self.db.enabled
	CALLBACK_MANAGER:FireCallbacks( self.EVENT_TOGGLE_AUTOLOOT )
end
