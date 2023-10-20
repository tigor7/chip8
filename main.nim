import sdl2
import tables
import std/streams, std/strformat
import types
include instructions

const
  Factor = 20
  ScreenW = 64 * Factor
  ScreenH = 32 * Factor



# type
#   Chip8 = object
#     memory: array[0x1000, uint8]
#     registers: array[0x10, uint8]
#     display: array[64*32, bool]
#     pc: uint16
#     nnn: uint16
#     nn: uint8
#     n: uint8
#     x: uint8
#     y: uint8
#     i: uint16
#     vn: uint8

type SDLException = object of Defect

template sdlFailIf(condition: typed, reason: string) =
  if condition: raise SDLException.newException(
    reason & ", SDL error " & $getError()
  )

proc loadFonts(chip8: var Chip8) =
  const startMemory = 0x0050
  const fonts: array[80, uint8] = [
  0xF0, 0x90, 0x90, 0x90, 0xF0, # 0
  0x20, 0x60, 0x20, 0x20, 0x70, # 1
  0xF0, 0x10, 0xF0, 0x80, 0xF0, # 2
  0xF0, 0x10, 0xF0, 0x10, 0xF0, # 3
  0x90, 0x90, 0xF0, 0x10, 0x10, # 4
  0xF0, 0x80, 0xF0, 0x10, 0xF0, # 5
  0xF0, 0x80, 0xF0, 0x90, 0xF0, # 6
  0xF0, 0x10, 0x20, 0x40, 0x40, # 7
  0xF0, 0x90, 0xF0, 0x90, 0xF0, # 8
  0xF0, 0x90, 0xF0, 0x10, 0xF0, # 9
  0xF0, 0x90, 0xF0, 0x90, 0x90, # A
  0xE0, 0x90, 0xE0, 0x90, 0xE0, # B
  0xF0, 0x80, 0x80, 0x80, 0xF0, # C
  0xE0, 0x90, 0x90, 0x90, 0xE0, # D
  0xF0, 0x80, 0xF0, 0x80, 0xF0, # E
  0xF0, 0x80, 0xF0, 0x80, 0x80  # F
  ]
  copyMem(addr chip8.memory[startMemory], addr fonts, sizeof(fonts))

proc loadROM(chip8: var Chip8, filename: string) =
  const startMemory = 0x0200
  var fileStream = newFileStream(filename, fmRead)
  if fileStream.isNil:
    raise newException(IOError, "Unable to open ROM file: " & filename)
  defer: fileStream.close()

  var buffer: array[0x1000, uint8]
  discard fileStream.readData(addr buffer, 0x1000)
  copyMem(addr chip8.memory[startMemory], addr buffer, sizeof(buffer))

proc updateScreen(chip8: var Chip8, renderer: RendererPtr) =
  renderer.setDrawColor(0, 0, 0, 0)
  renderer.clear()
  for i in 0..<64:
    for j in 0..<32:
      if chip8.display[j * 64 + i]:
        renderer.setDrawColor(255, 255, 255, 255)
        var r = rect(x = cint(i*20), y = cint(j*20), w = 20, h = 20)
        renderer.fillRect(addr r)
  renderer.present()

proc main =

  var chip8 = Chip8()
  chip8.PC = 0x200 # Roms start at 0x200
  chip8.draw = false
  loadFonts(chip8)

  loadROM(chip8, "./roms/test_opcode.ch8")

  sdlFailIf(not sdl2.init(INIT_VIDEO)):
    "SDL2 initialization failed"
  defer: sdl2.quit()

  let window = createWindow(
    title = "Chip-8",
    x = SDL_WINDOWPOS_CENTERED,
    y = SDL_WINDOWPOS_CENTERED,
    w = ScreenW,
    h = ScreenH,
    flags = SDL_WINDOW_SHOWN
  )
  sdlFailIf window.isNil: "window could ne be created"

  let renderer = createRenderer(window, 0, Renderer_Accelerated)
  sdlFailIf renderer.isNil: "renderer could not be created"
  defer: renderer.destroy()

  # Initial screen clear
  # renderer.setDrawColor(240, 231, 123)
  var running = true
  var paused = false
  var withStep = false
  while running:
    # Handle input()
    var event = defaultEvent
    while pollEvent(event):
      case event.kind
      of QuitEvent:
        running = false
        break
      of KeyDown:
        case event.key.keysym.sym
        of K_ESCAPE:
          running = false
        of K_SPACE:
          paused = not paused
        else:
          discard
      else:
        discard
    if paused:
      continue
    emulateInstruction(chip8)
    delay(16)
    if chip8.draw:
      updateScreen(chip8, renderer)
      chip8.draw = false

main()
