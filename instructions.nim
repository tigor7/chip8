import types
import system
import strformat
import os

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
    echo "Jump"
    chip8.PC = chip8.inst.NNN
  of 0x2:
    # 0x2NNN Calls subroutine at NNN
    echo "call subroutine"

    chip8.stack[chip8.SP] = chip8.PC
    chip8.PC = chip8.inst.NNN
    chip8.SP += 1
  of 0x3:
    # 0x3XNN Skips next instruction if Vx == NN
    echo "Skips next"
    if chip8.registers[chip8.inst.X] == chip8.inst.NN:
      chip8.PC += 2
  of 0x6:
    # 0x6XNN Vx = NN
    echo fmt("Set register V{chip8.inst.X} to NN (0x{chip8.inst.NN:02X})")

    chip8.registers[chip8.inst.X] = chip8.inst.NN
  of 0x7:
    # 0x7XNN Vx += NN
    echo fmt("Set Vx (0x{chip8.inst.X:02X}) += NN (0x{chip8.inst.NN:02X}) result: (0x{(chip8.registers[chip8.inst.X] + chip8.inst.NN):02X})")

    chip8.registers[chip8.inst.X] += chip8.inst.NN
    echo "REgister2: ", chip8.registers[chip8.inst.X]
  of 0xA:
    # 0xANNN I = NNN
    echo fmt("Set I to NNN (0x{chip8.inst.NNN:03X})")
    chip8.I = chip8.inst.NNN
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

  else:
    echo "Unimplemented Opcode"

