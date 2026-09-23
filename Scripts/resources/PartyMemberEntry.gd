# File: res://Scripts/resources/PartyMemberEntry.gd
# One character the player OWNS. Edit these in the Inspector on the
# PartyRoster node (game.tscn). Later the story / a menu flips the flags.
class_name PartyMemberEntry
extends Resource

@export var member_id: String = "ilia"
@export var display_name: String = "Ilia"
## The character's combat scene (a PartyNPC scene, e.g. res://scenes/Ilia.tscn).
@export var character_scene: PackedScene
## Story-unlocked. Locked characters can't be put in the party.
@export var unlocked: bool = false
## Selected in the party menu. Only used if unlocked. (Max Global.MAX_PARTY_SIZE.)
@export var in_party: bool = false
