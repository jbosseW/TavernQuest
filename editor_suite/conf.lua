function love.conf(t)
    t.identity = "tavern_editor"
    t.version = "11.4"
    t.console = true

    t.window.title = "Tavern Quest - Editor Suite"
    t.window.width = 1440
    t.window.height = 900
    t.window.resizable = true
    t.window.minwidth = 1024
    t.window.minheight = 600
    t.window.vsync = 1

    t.modules.audio = false
    t.modules.joystick = false
    t.modules.physics = false
    t.modules.sound = false
    t.modules.thread = false
    t.modules.touch = false
    t.modules.video = false
end
