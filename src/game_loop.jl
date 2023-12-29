"The game loop's state and parameters"
Base.@kwdef mutable struct GameLoop
    # Game stuff:
    context::Context
    service_input::Service_Input
    service_basic_graphics::Service_BasicGraphics
    service_gui::Service_GUI

    # Timing stuff:
    last_frame_time_ns::UInt64 = 0
    frame_idx::Int = 0
    delta_seconds::Float32 = 0


    ##################################
    #   Below are fields you can set!

    # The maximum framerate.
    # The game loop will wait at the end of each frame if the game is running faster than this.
    max_fps::Optional{Int} = 300

    # The maximum frame duration.
    # 'delta_seconds' will be capped at this value, even if the frame took longer.
    # This stops the game from significantly jumping after one hang.
    max_frame_duration::Float32 = 0.1
end

"""
Runs a basic game loop, with all the typical B+ services.
The syntax looks like this:

````
@game_loop begin
    INIT(
        # Pass all the usual arguments to the constructor for a `GL.Context`.
        # For example:
        v2i(1920, 1080), "My Window Title";
        debug_mode=true
    )

    SETUP = begin
        # Julia code block that runs just before the loop.
        # Initialize your assets and game state, add custom fonts to CImGui, etc.
        # You can configure loop parameters by changing certain fields
        #    of the variable `LOOP::GameLoop`.
    end
    LOOP = begin
        # Julia code block that runs inside the loop.
        # Runs in a `for` loop in the same scope as `SETUP`.
        # You should end the loop with a `break` statement --
        #   if you `return` or `throw`, then the `TEARDOWN` section won't run.
    end
    TEARDOWN = begin
        # Julia code block that runs after the loop.
        # Runs in the same scope as `SETUP`.
    end
end
````

In all the code blocks but INIT, you have access to the game loop state through the variable
    `LOOP::GameLoop`
"""
macro game_loop(block)
    if !Base.is_expr(block, :block)
        error("Game loop should be a 'begin ... end' block")
    end

    statements = block.args
    filter!(s -> !isa(s, LineNumberNode), statements)

    init_args = ()
    setup_code = nothing
    loop_code = nothing
    teardown_code = nothing
    for statement in statements
        if Base.is_expr(statement, :call) && (statement.args[1] == :INIT)
            if init_args != ()
                error("Provided INIT more than once")
            end
            init_args = statement.args[2:end]
        elseif Base.is_expr(statement, :(=)) && (statement.args[1] == :SETUP)
            if exists(setup_code)
                error("Provided SETUP more than once")
            end
            setup_code = statement.args[2]
        elseif Base.is_expr(statement, :(=)) && (statement.args[1] == :LOOP)
            if exists(loop_code)
                error("Provided LOOP more than once")
            end
            loop_code = statement.args[2]
        elseif Base.is_expr(statement, :(=)) && (statement.args[1] == :TEARDOWN)
            if exists(teardown_code)
                error("Provided TEARDOWN more than once")
            end
            teardown_code = statement.args[2]
        else
            error("Unknown code block: ", statement)
        end
    end

    loop_var = esc(:LOOP)
    do_body = :( (game_loop_impl_context::Context, ) -> begin
        # Set up the loop state object.
        $loop_var::GameLoop = GameLoop(
            context=game_loop_impl_context,
            service_input=service_Input_init(),
            service_basic_graphics=service_BasicGraphics_init(),
            service_gui=service_GUI_init()
        )
        # Set up timing.
        $loop_var.last_frame_time_ns = time_ns()
        $loop_var.delta_seconds = zero(Float32)

        # Auto-resize the GL viewport when the window's size changes.
        push!($loop_var.context.glfw_callbacks_window_resized, (new_size::v2i) ->
            set_viewport($loop_var.context, Box2Di(min=Vec(1, 1), size=new_size))
        )

        # Run the loop.
        $(esc(setup_code))
        while true
            GLFW.PollEvents()

            # Update/render.
            service_Input_update()
            service_GUI_start_frame()
            $(esc(loop_code))
            service_GUI_end_frame()
            GLFW.SwapBuffers($loop_var.context.window)

            # Advance the timer.
            $loop_var.frame_idx += 1
            new_time::UInt = time_ns()
            $loop_var.delta_seconds = Float32((new_time - $loop_var.last_frame_time_ns) / 1e9)
            # Cap the framerate, by waiting if necessary.
            if exists($loop_var.max_fps)
                wait_time = (1/$loop_var.max_fps) - $loop_var.delta_seconds
                if wait_time > 0
                    sleep(wait_time)
                    # Update the timestamp again after waiting.
                    new_time = time_ns()
                    $loop_var.delta_seconds = Float32((new_time - $loop_var.last_frame_time_ns) / 1e9)
                end
            end
            $loop_var.last_frame_time_ns = new_time
            # Cap the length of the next frame.
            $loop_var.delta_seconds = min(Float32($loop_var.max_frame_duration),
                                            $loop_var.delta_seconds)
        end
        $(esc(teardown_code))
    end )

    # Wrap the game in a lambda in case users invoke it globally.
    # Global code is very slow in Julia.
    return :( (() ->
        $(Expr(:call, bp_gl_context,
            do_body,
            esc.(init_args)...
    )))() )
end

export @game_loop

#TODO: Fixed-update increments for physics-like stuff