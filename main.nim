import sdl2
import tables
import std/streams, std/strformat
import types
include instructions

const
  Factor = 20
  ScreenW = 64 * Factor
  ScreenH = 32 * Factor

type SDLException = object of Defect

template sdlFailIf(condition: typed, reason: string) =
  if condition: raise SDLException.newException(
    reason & ", SDL error " & $getError()
  )

proc `/`(x, y: uint64): float = x.float / y.float


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

  loadROM(chip8, "./roms/Tetris.ch8")

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

  var running = true
  var paused = false
  while running:
    # Handle input()
    var start = getPerformanceCounter()
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
        of K_1:
          chip8.keypad[1] = true
        of K_2:
          chip8.keypad[2] = true
        of K_3:
          chip8.keypad[3] = true
        of K_4:
          chip8.keypad[0xC] = true
        of K_q:
          chip8.keypad[4] = true
        of K_w:
          chip8.keypad[5] = true
        of K_e:
          chip8.keypad[6] = true
        of K_r:
          chip8.keypad[0xD] = true
        of K_a:
          chip8.keypad[7] = true
        of K_s:
          chip8.keypad[8] = true
        of K_d:
          chip8.keypad[9] = true
        of K_f:
          chip8.keypad[0xE] = true
        of K_z:
          chip8.keypad[0xA] = true
        of K_x:
          chip8.keypad[0] = true
        of K_c:
          chip8.keypad[0xB] = true
        of K_v:
          chip8.keypad[0xF] = true
        else:
          discard
      of KeyUp:
        case event.key.keysym.sym
        of K_1:
          chip8.keypad[1] = false
        of K_2:
          chip8.keypad[2] = false
        of K_3:
          chip8.keypad[3] = false
        of K_4:
          chip8.keypad[0xC] = false
        of K_q:
          chip8.keypad[4] = false
        of K_w:
          chip8.keypad[5] = false
        of K_e:
          chip8.keypad[6] = false
        of K_r:
          chip8.keypad[0xD] = false
        of K_a:
          chip8.keypad[7] = false
        of K_s:
          chip8.keypad[8] = false
        of K_d:
          chip8.keypad[9] = false
        of K_f:
          chip8.keypad[0xE] = false
        of K_z:
          chip8.keypad[0xA] = false
        of K_x:
          chip8.keypad[0] = false
        of K_c:
          chip8.keypad[0xB] = false
        of K_v:
          chip8.keypad[0xF] = false
        else: discard
      else:
        discard
    if paused:
      continue
    for i in 0..<(floordiv(700, 60)): # 700 instructions per second
      emulateInstruction(chip8)
    var endTime = getPerformanceCounter()
    var timeElapsed = floordiv((endTime - start), 1000) /
        getPerformanceFrequency()
    delay((if 17 > timeElapsed: 17 - uint32(timeElapsed) else: 0))
    if chip8.draw:
      updateScreen(chip8, renderer)
      chip8.draw = false

main()
