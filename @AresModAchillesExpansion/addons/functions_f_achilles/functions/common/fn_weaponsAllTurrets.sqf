////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	AUTHOR: Kex
//	DATE: 8/3/16
//	VERSION: 1.0
//  DESCRIPTION: Returns all weapons of a vehicle (including turrets)
//
//	ARGUMENTS:
//	_this select 0:		OBJECT	- vehicle for which all turret weapons shall be found
//	_this select 1:		BOOL	- (default: false) if true, empty weapons are not considered
//
//	RETURNS:
//	_this:				ARRAY	- array weapon classes (string)
//
//	Example:
//	_weapons = [_vehicle] call Achilles_fnc_weaponsAllTurrets;
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

params [["_vehicle", objNull, [objNull]], ["_non_empty_only", false, [false]]];
private ["_path","_weapon","_cfgMagazines"];
private _vehicle = param [0, objNull, [objNull]];
private _non_empty_only = param [1, false, [false]];
private _weapons = [];
private _magazinesAllTurrets = ((magazinesAllTurrets _vehicle) select {x select 2 > 0}) apply {_x select 0};

{
	_path = _x;
	{
		_weapon = _x;
		if (_non_empty_only) then
		{
			_cfgMagazines = getArray (configfile >> "CfgWeapons" >> _weapon >> "magazines");
			{
				if (_x in _cfgMagazines) exitWith
				{
					_weapons pushBack _weapon;
				};
			} forEach _magazinesAllTurrets;
		} else
		{
			_weapons pushBack _weapon;
		};
	} forEach (_vehicle weaponsTurret _path);
} forEach ([[-1]] + allTurrets _vehicle);
_weapons;
