/*
 * Author: Glowbal
 * Sets a unit in the unconscious state.
 *
 * Arguments:
 * 0: The unit that will be put in an unconscious state <OBJECT>
 * 1: Set unconsciouns <BOOL> (default: true)
 * 2: Minimum unconscious time <NUMBER> (default: (round(random(10)+5)))
 * 3: Force AI Unconscious (skip random death chance) <BOOL> (default: false)
 *
 * Return Value:
 * None
 *
 * Example:
 * [bob, true] call ace_medical_fnc_setUnconscious;
 *
 * Public: yes
 */

#include "script_component.hpp"

#define DEFAULT_DELAY (round(random(10)+5))

// only run this after the settings are initialized
if !(EGVAR(common,settingsInitFinished)) exitWith {
    EGVAR(common,runAtSettingsInitialized) pushBack [FUNC(setUnconscious), _this];
};

private ["_animState", "_originalPos", "_startingTime", "_isDead"];
params ["_unit", ["_set", true], ["_minWaitingTime", DEFAULT_DELAY]];

// No change, fuck off. (why is there no xor?)
if (_set isEqualTo (_unit getVariable ["ACE_isUnconscious", false])) exitWith {};

if !(_set) exitWith {
    _unit setVariable ["ACE_isUnconscious", false, true];
    if (_unit getVariable [QGVAR(inReviveState), false]) then {
        _unit setVariable [QGVAR(inReviveState), nil, true];
    };
};

if !(!(isNull _unit) && {(_unit isKindOf "CAManBase") && ([_unit] call EFUNC(common,isAwake))}) exitWith{};

if (!local _unit) exitWith {
    [QGVAR(setUnconscious), [_unit, _set, _minWaitingTime, _force], _unit] call CBA_fnc_targetEvent;
};

_unit setVariable ["ACE_isUnconscious", true, true];


// If a unit has the launcher out, it will sometimes start selecting the primairy weapon while unconscious,
// therefor we force it to select the primairy weapon before going unconscious
if ((vehicle _unit) isKindOf "StaticWeapon") then {
    [_unit] call EFUNC(common,unloadPerson);
};
if (animationState _unit in ["ladderriflestatic","laddercivilstatic"]) then {
    _unit action ["ladderOff", (nearestBuilding _unit)];
};
if (vehicle _unit == _unit) then {
    if (primaryWeapon _unit == "") then {
        _unit addWeapon "ACE_FakePrimaryWeapon";
    };
    _unit selectWeapon (primaryWeapon _unit);
};

// We are storing the current animation, so we can use it later on when waking the unit up inside a vehicle
if (vehicle _unit != _unit) then {
    _unit setVariable [QGVAR(vehicleAwakeAnim), [(vehicle _unit), (animationState _unit)]];
};

_unit setUnitPos "DOWN";
[_unit, true] call EFUNC(common,disableAI);

// So the AI does not get stuck, we are moving the unit to a temp group on its own.
//Unconscious units shouldn't be put in another group #527:
if (GVAR(moveUnitsFromGroupOnUnconscious)) then {
    [_unit, true, "ACE_isUnconscious", side group _unit] call EFUNC(common,switchToGroupSide);
};
// Delay Unconscious so the AI dont instant stop shooting on the unit #3121
if (GVAR(delayUnconCaptive) == 0) then {
    [_unit, "setCaptive", "ace_unconscious", true] call EFUNC(common,statusEffect_set);
} else {
    [{
        params ["_unit"];
        if (_unit getVariable ["ACE_isUnconscious", false]) then {
            [_unit, "setCaptive", "ace_unconscious", true] call EFUNC(common,statusEffect_set);
        };
    },[_unit], GVAR(delayUnconCaptive)] call CBA_fnc_waitAndExecute;
};

_anim = [_unit] call EFUNC(common,getDeathAnim);
[_unit, _anim, 1, true] call EFUNC(common,doAnimation);
[{
    params ["_unit", "_anim"];
    if ((_unit getVariable "ACE_isUnconscious") and (animationState _unit != _anim)) then {
        [_unit, _anim, 2, true] call EFUNC(common,doAnimation);
    };
}, [_unit, _anim], 0.5, 0] call CBA_fnc_waitAndExecute;

// unconscious can't talk
[_unit, "isUnconscious"] call EFUNC(common,muteUnit);

["ace_unconscious", [_unit, true]] call CBA_fnc_globalEvent;