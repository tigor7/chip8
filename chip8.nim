import sdl2

const
    Factor = 20
    ScreenW = 64 * Factor
    ScreenH = 32 * Factor


type 
  Chip8 = object
    memory: array[0xFFFF, uint8]

type SDLException = object of Defect

template sdlFailIf(condition: typed, reason: string) =
  if condition: raise SDLException.newException(
    reason & ", SDL error " & $getError()
  )


proc main =
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

  let renderer = createRenderer(window, -1, Renderer_Accelerated)
  sdlFailIf renderer.isNil: "renderer could not be created"
  defer: renderer.destroy()

  # Initial screen clear
  renderer.setDrawColor(240, 231, 123)
  renderer.clear()
  var running = true
  while running:
    delay(16)
    renderer.present()

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
        else:
          discard
      else:
        discard


main()