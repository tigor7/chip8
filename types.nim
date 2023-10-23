type
  Inst* = object
    opcode*: uint16
    NNN*: uint16
    NN*: uint8
    N*: uint8
    X*: uint8
    Y*: uint8
    I*: uint16
    VN*: uint8

  Chip8* = object
    draw*: bool
    memory*: array[0x1000, uint8]
    stack*: array[16, uint16]
    SP*: uint8
    registers*: array[0x10, uint8]
    display*: array[64*32, bool]
    PC*: uint16
    I*: uint16
    inst*: Inst
    keypad*: array[16, bool]
    delayTimer*: uint8
    soundTimer*: uint8


