/*
	Author: CreepPork_LV, modified by Kex

	Description:
		Uses a created helicopter that sling loads a Supply Crate which then is taken to the destination.

	Parameters:
    	None

	Returns:
    	Nothing
*/

#include "\A3\ui_f_curator\ui\defineResinclDesign.inc"

#define AMMO_CRATES ["CargoNet_01_barrels_F", "CargoNet_01_box_F", "I_CargoNet_01_ammo_F", "O_CargoNet_01_ammo_F", "C_IDAP_CargoNet_01_supplies_F", "B_CargoNet_01_ammo_F"]
#define FIRST_SPECIFIC_LZ_OR_RP_OPTION_INDEX	4

#define CURATOR_UNITS_IDCs 						[IDC_RSCDISPLAYCURATOR_CREATE_UNITS_EAST, IDC_RSCDISPLAYCURATOR_CREATE_UNITS_WEST, IDC_RSCDISPLAYCURATOR_CREATE_UNITS_GUER]
#define CURATOR_GROUPS_IDCs 					[IDC_RSCDISPLAYCURATOR_CREATE_GROUPS_EAST, IDC_RSCDISPLAYCURATOR_CREATE_GROUPS_WEST, IDC_RSCDISPLAYCURATOR_CREATE_GROUPS_GUER]

#include "\achilles\modules_f_ares\module_header.hpp"


// get LZs
private _allLzsUnsorted = allMissionObjects "Ares_Module_Reinforcements_Create_Lz";
if (_allLzsUnsorted isEqualTo []) exitWith {[localize "STR_AMAE_NO_LZ"] call Achilles_fnc_ShowZeusErrorMessage};
private _allLzs = [_allLzsUnsorted, [], { _x getVariable ["SortOrder", 0]; }, "ASCEND"] call BIS_fnc_sortBy;
private _lzOptions = [localize "STR_AMAE_RANDOM", localize "STR_AMAE_NEAREST", localize "STR_AMAE_FARTHEST", localize "STR_AMAE_LEAST_USED"];
_lzOptions append (_allLzs apply {name _x});

private _pos = position _logic;

disableSerialization;
// get sides
private _sides = [];
private _side_names = [];
for "_i" from 0 to 2 do
{
	_sides pushBack (_i call BIS_fnc_sideType);
	_side_names pushBack (_i call BIS_fnc_sideName);
};

// cache: find all possible vehicles and groups for reinforcements 
if (uiNamespace getVariable ["Achilles_var_supplyDrop_factions", []] isEqualTo []) then
{
	private _curator_interface = findDisplay IDD_RSCDISPLAYCURATOR;
	
	private _factions = [];
	private _categories = [];
	private _vehicles = [];
	private _cargoFactions = [];
	private _cargoCategories = [];
	private _cargoVehicles = [];
	
	for "_side_id" from 0 to (count _sides - 1) do
	{
		// find vehicles
		private _tree_ctrl = _curator_interface displayCtrl (CURATOR_UNITS_IDCs select _side_id);
		_factions pushBack [];
		_categories pushBack [];
		_vehicles pushBack [];
		_cargoFactions pushBack [];
		_cargoCategories pushBack [];
		_cargoVehicles pushBack [];
		private _faction_id = -1;
		private _cargoFaction_id = -1;
		for "_faction_tvid" from 0 to ((_tree_ctrl tvCount []) - 1) do
		{
			private _factionIncludedInTransport = false;
			private _factionIncludedInCargo = false;
			private _faction = _tree_ctrl tvText [_faction_tvid];
			private _category_id = -1;
			private _cargoCategory_id = -1;
			for "_category_tvid" from 0 to ((_tree_ctrl tvCount [_faction_tvid]) - 1) do
			{
				private _categoryIncludedInTransport = false;
				private _categoryIncludedInCargo = false;
				private _category = _tree_ctrl tvText [_faction_tvid,_category_tvid];
				for "_vehicle_tvid" from 0 to ((_tree_ctrl tvCount [_faction_tvid,_category_tvid]) - 1) do
				{
					private _vehicle = _tree_ctrl tvData [_faction_tvid,_category_tvid,_vehicle_tvid];
					if (_vehicle isKindOf "Air" and {count getArray (configFile >> "CfgVehicles" >> _vehicle >> "slingCargoAttach") > 0 or {isClass (configFile >> "CfgVehicles" >> _vehicle >> "VehicleTransport" >> "Carrier")}}) then
					{
						if (not _factionIncludedInTransport) then
						{
							_factionIncludedInTransport = true;
							(_factions select _side_id) pushBack _faction;
							_faction_id = _faction_id + 1;
							(_categories select _side_id) pushBack [];
							(_vehicles select _side_id) pushBack [];
						};
						if (not _categoryIncludedInTransport) then
						{
							_categoryIncludedInTransport = true;
							(_categories select _side_id select _faction_id) pushBack _category;
							_category_id = _category_id + 1;
							(_vehicles select _side_id select _faction_id) pushBack [];
						};
						(_vehicles select _side_id select _faction_id select _category_id) pushBack _vehicle;
					};
					if (count getArray (configFile >> "CfgVehicles" >> _vehicle >> "slingLoadCargoMemoryPoints") > 0 or {isClass (configFile >> "CfgVehicles" >> _vehicle >> "VehicleTransport" >> "Cargo")}) then
					{
						if (not _factionIncludedInCargo) then
						{
							_factionIncludedInCargo = true;
							(_cargoFactions select _side_id) pushBack _faction;
							_cargoFaction_id = _cargoFaction_id + 1;
							(_cargoCategories select _side_id) pushBack [];
							(_cargoVehicles select _side_id) pushBack [];
						};
						if (not _categoryIncludedInCargo) then
						{
							_categoryIncludedInCargo = true;
							(_cargoCategories select _side_id select _cargoFaction_id) pushBack _category;
							_cargoCategory_id = _cargoCategory_id + 1;
							(_cargoVehicles select _side_id select _cargoFaction_id) pushBack [];
						};
						(_cargoVehicles select _side_id select _cargoFaction_id select _cargoCategory_id) pushBack _vehicle;
					};
				};
			};
		};
	};
	
	// get ammo boxes
	private _targetCategory = getText (configfile >> "CfgEditorCategories" >> "EdCat_Supplies" >> "displayName");
	private _supplySubCategory = [];
	private _supplies = [];
	private _tree_ctrl = _curator_interface displayCtrl IDC_RSCDISPLAYCURATOR_CREATE_UNITS_EMPTY;
	for "_supplyCategory_id" from 0 to ((_tree_ctrl tvCount []) - 1) do
	{
		if (_targetCategory == _tree_ctrl tvText [_supplyCategory_id]) exitWith
		{
			for "_supplySubCategory_id" from 0 to ((_tree_ctrl tvCount [_supplyCategory_id]) - 1) do
			{
				_supplySubCategory pushBack (_tree_ctrl tvText [_supplyCategory_id,_supplySubCategory_id]);
				_supplies pushBack [];
				for "_supply_id" from 0 to ((_tree_ctrl tvCount [_supplyCategory_id,_supplySubCategory_id]) - 1) do
				{
					(_supplies select _supplySubCategory_id) pushBack (_tree_ctrl tvData [_supplyCategory_id,_supplySubCategory_id,_supply_id]);
				};
			};
		};
	};
	
	// cache
	uiNamespace setVariable ["Achilles_var_supplyDrop_factions", _factions];
	uiNamespace setVariable ["Achilles_var_supplyDrop_categories", _categories];
	uiNamespace setVariable ["Achilles_var_supplyDrop_vehicles", _vehicles];
	uiNamespace setVariable ["Achilles_var_supplyDrop_cargoFactions", _cargoFactions];
	uiNamespace setVariable ["Achilles_var_supplyDrop_cargoCategories", _cargoCategories];
	uiNamespace setVariable ["Achilles_var_supplyDrop_cargoVehicles", _cargoVehicles];
	uiNamespace setVariable ["Achilles_var_supplyDrop_supplySubCategories", _supplySubCategory];
	uiNamespace setVariable ["Achilles_var_supplyDrop_supplies", _supplies];
};

// Show the user the dialog
private _dialogResult =
[
	localize "STR_AMAE_SPAWN_UNITS",
	[
		["COMBOBOX", localize "STR_AMAE_SIDE", _side_names, 0, false, [["LBSelChanged","SIDE"]]],
		["COMBOBOX", localize "STR_AMAE_FACTION", [], 0, false, [["LBSelChanged","FACTION"]]],
		["COMBOBOX", localize "STR_AMAE_VEHICLE_CATEGORY", [], 0, false, [["LBSelChanged","CATEGORY"]]],
		["COMBOBOX", localize "STR_AMAE_VEHICLE", []],
		["COMBOBOX", localize "STR_AMAE_VEHICLE_BEHAVIOUR", [localize "STR_AMAE_RTB_DESPAWN", localize "STR_AMAE_STAY_AT_LZ"]],
		["COMBOBOX", localize "STR_AMAE_LZ_DZ", _lzOptions],
		["COMBOBOX", localize "STR_AMAE_AMMUNITION_CRATE_OR_VEHICLE", [localize "STR_AMAE_AMMUNITION_CRATE", localize "STR_AMAE_VEHICLE"], 0, false, [["LBSelChanged","CARGO_TYPE"]]],
		["COMBOBOX", localize "STR_AMAE_CARGO_LW", [localize "STR_AMAE_DEFAULT", localize "STR_AMAE_EDIT_CARGO", localize "STR_AMAE_VIRTUAL_ARSENAL", localize "STR_AMAE_EMPTY"]],
		["COMBOBOX", localize "STR_AMAE_SIDE", _side_names, 0, false, [["LBSelChanged","CARGO_SIDE"]]],
		["COMBOBOX", localize "STR_AMAE_FACTION", [], 0, false, [["LBSelChanged","CARGO_FACTION"]]],
		["COMBOBOX", localize "STR_AMAE_CATEGORY", [], 0, false, [["LBSelChanged","CARGO_CATEGORY"]]],
		["COMBOBOX", localize "STR_AMAE_VEHICLE", []]
	],
	"Achilles_fnc_RscDisplayAttributes_SupplyDrop"
] call Achilles_fnc_ShowChooseDialog;

if (_dialogResult isEqualTo []) exitWith {};

_dialogResult params
[
	"_side_id",
	"_faction_id",
	"_category_id",
	"_vehicle_id",
	"_aircraftBehaviour",
	"_lzdz_algorithm",
	"_cargoType",
	"_cargoBoxInventory",
	"_cargoSide_id",
	"_cargoFaction_id",
	"_cargoCategory_id",
	"_cargoVehicle_id"
];

// Choose the LZ based on what the user indicated
private _LZ = switch (_lzdz_algorithm) do
{
	case 0: // Random
	{
		_allLzs call BIS_fnc_selectRandom
	};
	case 1: // Nearest
	{
		[_spawn_position, _allLzs] call Ares_fnc_GetNearest
	};
	case 2: // Furthest
	{
		[_spawn_position, _allLzs] call Ares_fnc_GetFarthest
	};
	case 3: // Least used
	{
		private _temp = _allLzs call BIS_fnc_selectRandom; // Choose randomly to start.
		{
			if (_x getVariable ["Ares_Lz_Count", 0] < _temp getVariable ["Ares_Lz_Count", 0]) then
			{
				_temp = _x;
			};
		} forEach _allLzs;
        _temp
	};
	default // Specific LZ.
	{
		_allLzs select (_lzdz_algorithm - FIRST_SPECIFIC_LZ_OR_RP_OPTION_INDEX)
	};
};

private _aircraftClassname = (uiNamespace getVariable "Achilles_var_supplyDrop_vehicles") select _side_id select _faction_id select _category_id select _vehicle_id;

_aircraftSide = _side_id call BIS_fnc_sideType;

private _spawnedAircraftArray = [_pos, _pos getDir _LZ, _aircraftClassname, _aircraftSide] call BIS_fnc_spawnVehicle;

_spawnedAircraftArray params ["_aircraft", "_aircraftCrew", "_aircraftGroup"];

[[_aircraft]] call Ares_fnc_AddUnitsToCurator;

{
	[[_x]] call Ares_fnc_AddUnitsToCurator;
} forEach _aircraftCrew;

private _aircraftDriver = driver _aircraft;

_aircraftDriver setSkill 1;
_aircraftGroup allowFleeing 0;

// If the selected cargo is the ammo box.
if (_cargoType == 0) then
{
	private _cargoBoxClassname = (uiNamespace getVariable "Achilles_var_supplyDrop_supplies") select _cargoCategory_id select _cargoVehicle_id;

	private _cargoBox = _cargoBoxClassname createVehicle _pos;

	[[_cargoBox]] call Ares_fnc_AddUnitsToCurator;

	private _hasAttached = _aircraft setSlingLoad _cargoBox;
	if (!_hasAttached) exitWith 
	{
		[localize "STR_AMAE_FAILED_TO_ATTACH_CARGO"] call Achilles_fnc_showZeusErrorMessage;
		{deleteVehicle _x} forEach _aircraftCrew;
		deleteVehicle _aircraft;
		deleteVehicle _cargoBox;
	};

	switch (_cargoBoxInventory) do
	{
		case 1:
		{
			missionNamespace setVariable ["BIS_fnc_initCuratorAttributes_target", _cargoBox];
			createDialog "RscDisplayAttributesInventory";
			waitUntil {isNull ((uiNamespace getVariable "RscDisplayAttributesInventory") displayCtrl IDC_RSCATTRIBUTEINVENTORY_RSCATTRIBUTEINVENTORY)};
		};
		case 2:
		{
			["AmmoboxInit", [_cargoBox, true]] spawn BIS_fnc_Arsenal;
		};
		case 3:
		{
			clearItemCargoGlobal _cargoBox;
			clearWeaponCargoGlobal _cargoBox;
			clearBackpackCargoGlobal _cargoBox;
			clearMagazineCargoGlobal _cargoBox;
		};
	};
};

if (_cargoType == 1) then
{
	private _cargoClassname = (uiNamespace getVariable "Achilles_var_supplyDrop_cargoVehicles") select _cargoSide_id select _cargoFaction_id select _cargoCategory_id select _cargoVehicle_id;
	
	private _cargo = _cargoClassname createVehicle _pos;

	[[_cargo]] call Ares_fnc_AddUnitsToCurator;

	if (isClass (configFile >> "CfgVehicles" >> _aircraftClassname >> "VehicleTransport" >> "Carrier")) then
	{
		private _hasLoaded = _aircraft setVehicleCargo _cargo;
		if (!_hasLoaded) exitWith
		{
			[localize "STR_AMAE_FAILED_TO_ATTACH_CARGO"] call Achilles_fnc_showZeusErrorMessage;
			{deleteVehicle _x} forEach _aircraftCrew;
			deleteVehicle _aircraft;
			deleteVehicle _cargo;
		};
	} else
	{
		private _hasAttached = _aircraft setSlingLoad _cargo;
		if (!_hasAttached) exitWith
		{
			[localize "STR_AMAE_FAILED_TO_ATTACH_CARGO"] call Achilles_fnc_showZeusErrorMessage;
			{deleteVehicle _x} forEach _aircraftCrew;
			deleteVehicle _aircraft;
			deleteVehicle _cargo;
		};
	};
};

private _LZWaypoint = _aircraftGroup addWaypoint [_LZ, 20];
_aircraftGroup setSpeedMode "FULL";

if (!((getVehicleCargo _aircraft) isEqualTo [])) then
{
	_LZWaypoint setWaypointStatements ["true", "objNull setVehicleCargo ((getVehicleCargo (vehicle this)) select 0);"];
}
else
{
	_LZWaypoint setWaypointType "UNHOOK";
};

// If the aircraft is set to return back
if (_aircraftBehaviour == 0) then
{
	private _returnWaypoint = _aircraftGroup addWaypoint [(getPos _aircraft), 0];
	_returnWaypoint setWaypointTimeout [2, 2, 2];
	_returnWaypoint setWaypointStatements ["true", "deleteVehicle (vehicle this); {deleteVehicle _x} foreach thisList;"];
};

#include "\achilles\modules_f_ares\module_footer.hpp"
