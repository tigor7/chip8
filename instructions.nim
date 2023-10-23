import types
import system
import strformat
import std/random
import std/math

randomize()

proc emulateInstruction*(chip8: var Chip8) =
  # Fetch instruction
  chip8.inst.opcode = (uint16(chip8.memory[chip8.PC]) shl 8) or chip8.memory[
      chip8.PC + 1]

  chip8.PC += 2

  # Split params
  chip8.inst.NNN = chip8.inst.opcode and 0x0FFF
  chip8.inst.NN = uint8(chip8.inst.opcode and 0xFF)
  chip8.inst.N = uint8(chip8.inst.opcode and 0x0F)
  chip8.inst.X = uint8((chip8.inst.opcode shr 8) and 0xF)
  chip8.inst.Y = uint8((chip8.inst.opcode shr 4) and 0xF)

  stdout.write fmt("Address: 0x{(chip8.PC - 2):X}, Opcode: 0x{(chip8.inst.opcode):04X}, Desc:")
  #Dispatch
  case (chip8.inst.opcode shr 12) and 0xF
  of 0x0:
    if chip8.inst.NN == 0xE0:
      # 0x0E0 Clears the screen
      echo "Clear screen"
      zeroMem(addr chip8.display, 64*32)
    elif chip8.inst.NN == 0xEE:
      # 0x0EE Returns from subroutine
      echo "Returns from subroutine"
      chip8.SP -= 1
      chip8.PC = chip8.stack[chip8.SP]
    else:
      echo "Unimplemented"
  of 0x1:
    # 0x1NNN Jump to NNN
    echo "Jump"
    chip8.PC = chip8.inst.NNN
  of 0x2:
    # 0x2NNN Calls subroutine at NNN
    echo "call subroutine"

    chip8.stack[chip8.SP] = chip8.PC
    chip8.PC = chip8.inst.NNN
    chip8.SP += 1
  of 0x3:
    # 0x3XNN Skips the next instruction if Vx == NN
    echo "Skips next 0x3"
    if chip8.registers[chip8.inst.X] == chip8.inst.NN:
      chip8.PC += 2
  of 0x4:
    # 0x4XNN Skips the next instruction if Vx != NN
    echo "Skips next 0x4"
    if chip8.registers[chip8.inst.X] != chip8.inst.NN:
      chip8.PC += 2
  of 0x5:
    # 0x5XY0 Skips the next instruction if Vx == Vy
    echo "Skips next 0x5"
    if chip8.registers[chip8.inst.X] == chip8.registers[chip8.inst.Y]:
      chip8.PC += 2
  of 0x6:
    # 0x6XNN  if Vx = NN
    echo fmt("Set register V{chip8.inst.X} to NN (0x{chip8.inst.NN:02X})")
    chip8.registers[chip8.inst.X] = chip8.inst.NN
  of 0x7:
    # 0x7XNN Vx += NN
    echo fmt("Set Vx (0x{chip8.inst.X:02X}) += NN (0x{chip8.inst.NN:02X}) result: (0x{(chip8.registers[chip8.inst.X] + chip8.inst.NN):02X})")
    chip8.registers[chip8.inst.X] += chip8.inst.NN
  of 0x8:
    if chip8.inst.N == 0x0:
      # 0x8XY0 Vx = Vy
      chip8.registers[chip8.inst.X] = chip8.registers[chip8.inst.Y]
    if chip8.inst.N == 0x1:
      # 0x8XY1 Vx |= Vy
      chip8.registers[chip8.inst.X] = chip8.registers[chip8.inst.X] or
          chip8.registers[chip8.inst.Y]
    if chip8.inst.N == 0x2:
      # 0x8XY2
      chip8.registers[chip8.inst.X] = chip8.registers[chip8.inst.X] and
          chip8.registers[chip8.inst.Y]
    if chip8.inst.N == 0x3:
      # 0x8XY3
      chip8.registers[chip8.inst.X] = chip8.registers[
          chip8.inst.X] xor chip8.registers[chip8.inst.Y]
    if chip8.inst.N == 0x4:
      # 0x8XY4
      if (uint16(chip8.registers[chip8.inst.X]) + uint16(chip8.registers[
          chip8.inst.Y]) > 255):
        chip8.registers[0xF] = 1
      else:
        chip8.registers[0xF] = 0
      chip8.registers[chip8.inst.X] += chip8.registers[chip8.inst.Y]

    if chip8.inst.N == 0x5:
      if (chip8.registers[chip8.inst.X] < chip8.registers[chip8.inst.Y]):
        chip8.registers[0xF] = 0
      else:
        chip8.registers[0xF] = 1
      chip8.registers[chip8.inst.X] -= chip8.registers[chip8.inst.Y]
    if chip8.inst.N == 0x6:
      chip8.registers[0xF] = chip8.registers[chip8.inst.X] and 1
      chip8.registers[chip8.inst.X] = chip8.registers[chip8.inst.X] shr 1
    if chip8.inst.N == 0x7:
      if (chip8.registers[chip8.inst.Y] < chip8.registers[chip8.inst.X]):
        chip8.registers[0xF] = 0
      else:
        chip8.registers[0xF] = 1
      chip8.registers[chip8.inst.X] = chip8.registers[chip8.inst.Y] -
          chip8.registers[chip8.inst.X]
    if chip8.inst.N == 0xE:
      chip8.registers[0xF] = (chip8.registers[chip8.inst.X] and 0x80) shr 7
      chip8.registers[chip8.inst.X] = chip8.registers[chip8.inst.X] shl 1
  of 0x9:
    # 0x9XY0 Skips the fnext instruction if Vx != Vy
    if chip8.registers[chip8.inst.X] != chip8.registers[chip8.inst.Y]:
      chip8.PC += 2
  of 0xA:
    # 0xANNN I = NNN
    echo fmt("Set I to NNN (0x{chip8.inst.NNN:03X})")
    chip8.I = chip8.inst.NNN
  of 0xB:
    # 0xBNNN
    chip8.PC = chip8.registers[0] + chip8.inst.NNN
  of 0xC:
    # 0xCXNN returns random
    chip8.registers[chip8.inst.X] = uint8(rand(0..255)) and chip8.inst.NN
  of 0xD:
    # 0xDXYN Draw at X, Y coordinates
    echo fmt("Draw N {chip8.inst.N} height sprite at coords V{chip8.inst.X} (0x{chip8.registers[chip8.inst.X]:04X}), V{chip8.inst.Y} (0x{chip8.registers[chip8.inst.Y]:04X}) from location I (0x{chip8.I:04X})")
    var x = chip8.registers[chip8.inst.X] mod 64
    var y = chip8.registers[chip8.inst.Y] mod 32
    chip8.registers[0xF] = 0

    for i in 0 ..< int(chip8.inst.N):
      if y + uint8(i) >= 32: break
      var sprite = chip8.memory[chip8.I + uint16(i)]
      x = chip8.registers[chip8.inst.X]
      for j in 0..<8:
        if x + uint8(j) >= 64:
          break
        if (sprite and uint8(0x80 shr j)) != 0:
          if chip8.display[(y + uint8(i)) * 64 + x + uint8(j)]:
            chip8.registers[0xF] = 1

          chip8.display[((uint16(y + uint8(i)) * 64) + x + uint8(
              j))] = chip8.display[((uint16(y + uint8(i)) * 64) + x + uint8(j))] xor true
    chip8.draw = true
  of 0xE:
    if chip8.inst.NN == 0x9E:
      if chip8.keypad[chip8.registers[chip8.inst.X]]:
        chip8.PC += 2
    elif chip8.inst.NN == 0xA1:
      if not chip8.keypad[chip8.registers[chip8.inst.X]]:
        chip8.PC += 2
  of 0xF:
    if chip8.inst.NN == 0x0A:
      chip8.PC -= 2
      for i in 0..<chip8.keypad.len:
        if chip8.keypad[i]:
          chip8.registers[chip8.inst.X] = uint8(i)
          chip8.PC += 4

    if chip8.inst.NN == 0x07:
      chip8.registers[chip8.inst.X] = chip8.delayTimer

    if chip8.inst.NN == 0x15:
      chip8.delayTimer = chip8.registers[chip8.inst.X]

    if chip8.inst.NN == 0x18:
      chip8.soundTimer = chip8.registers[chip8.inst.X]

    if chip8.inst.NN == 0x1E:
      chip8.I += chip8.registers[chip8.inst.X]

    if chip8.inst.NN == 0x229:
      chip8.I = chip8.registers[chip8.inst.X] * 5

    if chip8.inst.NN == 0x33:
      var bcd: uint8 = chip8.registers[chip8.inst.X]
      chip8.memory[chip8.I + 2] = bcd mod 10
      bcd = floordiv(bcd, 10)
      chip8.memory[chip8.I + 1] = bcd mod 10
      bcd = floordiv(bcd, 10)
      chip8.memory[chip8.I] = bcd

    if chip8.inst.NN == 0x55:
      for i in uint16(0)..chip8.inst.X:
        chip8.memory[chip8.I + i] = chip8.registers[i]

    if chip8.inst.NN == 0x65:
      for i in uint16(0)..chip8.inst.X:
        chip8.registers[i] = chip8.memory[chip8.I + i]

  else:
    echo "Unimplemented Opcode"

