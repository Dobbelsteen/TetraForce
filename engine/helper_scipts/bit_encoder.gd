extends Node

var GAMESTATE := 0
var CHECK_1 = 1
var CHECK_2 = 1 << 1
var CHECK_3 = 1 << 2
var CHECK_4 = 1 << 4
var CHECK_5 = 1 << 5
var CHECK_6 = 1 << 6
var CHECK_7 = 1 << 7
var CHECK_8 = 1 << 8
var CHECK_9 = 1 << 63 
"""
We can store up to 64 bits in a single variable. 
This means we can send 64 true/false flages, in a single byte, over the network, in a single int value.
Just think about that for a moment
"""
var ELEM_FIRE = 1
var ELEM_ICE = 1 << 1
var ELEM_ELECTRIC = 1 << 2
var ELEM_WATER = 1 << 3
var weakness_library = ["Basic", "Fire", "Ice", "Electric", "Water"]
export(int, FLAGS, "1", "2", "3", "4", "5", "6", "7", "8", "9", "10") var weakness

var EXAMPLE = CHECK_1 | CHECK_3 | CHECK_5


func _ready():
    weakness = ELEM_ELECTRIC | ELEM_FIRE
    
    print(are_bits_enabled(weakness, [ELEM_ICE, ELEM_ELECTRIC, ELEM_FIRE]))
    
    var mask = ELEM_FIRE
    
    
    if ELEM_ELECTRIC & weakness == ELEM_ELECTRIC:
        print('weak to electric')
    if ELEM_FIRE & weakness == ELEM_FIRE:
        print('weak to fire')
    if weakness & (ELEM_FIRE | ELEM_ELECTRIC):
        print("weak to both")
    if !(weakness & ELEM_WATER):
        print("not weak to water")
        print(~weakness)
        print(weakness)


func is_bit_enabled(mask, index):
    return mask & (1 << index) != 0

func enable_bit(mask, index):
    return mask | (1 << index)

func disable_bit(mask, index):
    return mask & ~(1 << index)

func are_bits_enabled(mask, indexes: Array):
    var compare_mask = 0
    for index in indexes:
            compare_mask = compare_mask | index
    return compare_mask & mask == compare_mask
