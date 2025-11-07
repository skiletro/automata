extends Node2D

@onready var tilemap: TileMapLayer = $TileMapLayer
var grid_size: Vector2i # cells (not pixels)
var grid: Array
var next_grid: Array
var paused := true

const CELL_SIZE := 16
const THREADS   := 4
var threads: Array[Thread]
var mutex: Mutex

func _ready() -> void:
    var vp := get_viewport().get_visible_rect().size
    grid_size = Vector2i(int(vp.x / CELL_SIZE), int(vp.y / CELL_SIZE))

    init_grid()
    queue_redraw()
    get_tree().get_root().size_changed.connect(resize)

    # thread pool
    threads = []
    for i in THREADS:
        threads.append(Thread.new())
    mutex = Mutex.new()

func resize() -> void:
    var vp := get_viewport().get_visible_rect().size
    grid_size = Vector2i(int(vp.x / CELL_SIZE), int(vp.y / CELL_SIZE))
    init_grid()
    queue_redraw()

func _on_timer_timeout() -> void:
    if not paused:
        update_grid()
        queue_redraw()

func _physics_process(_delta):
    if Input.is_action_pressed("click"):
        var mp := get_global_mouse_position()
        var c  := tilemap.local_to_map(mp)
        # stay inside array bounds
        if c.y >= 0 and c.y < grid_size.y and c.x >= 0 and c.x < grid_size.x:
            grid[c.y][c.x] = 1
            queue_redraw()

    if Input.is_action_just_released("pause"):
        paused = !paused

    if Input.is_action_just_released("clear"):
        clear_grid()
        queue_redraw()
        
    if Input.is_action_just_released("fullscreen"):
        if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
        else:
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _draw() -> void:
    for y in grid_size.y:
        for x in grid_size.x:
            var col := Color.WHITE if grid[y][x] == 1 else Color.BLACK
            draw_rect(Rect2(Vector2(x, y) * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE)), col)

func init_grid() -> void:
    grid = []
    for y in range(grid_size.y):
        var row := []
        for x in range(grid_size.x):
            row.append(1 if randf() > 0.9 else 0)
        grid.append(row)

func clear_grid() -> void:
    for y in range(grid_size.y):
        for x in range(grid_size.x):
            grid[y][x] = 0

func update_grid() -> void:
    next_grid.resize(THREADS) # pre-size slots
    var rows_per_thread := grid_size.y / THREADS

    # launch workers
    for i in THREADS:
        var start_row := i * rows_per_thread
        var end_row   := (i + 1) * rows_per_thread if i < THREADS - 1 else grid_size.y

        var ctx := {
            "grid": grid,
            "start_row": start_row,
            "end_row": end_row,
            "grid_size": grid_size
        }
        threads[i].start(Callable(self, "_update_band").bind(ctx, i))

    # wait
    for t in threads:
        t.wait_to_finish()

    # merge
    grid = []
    for band in next_grid:
        grid.append_array(band)

func _update_band(ctx: Dictionary, band_idx: int) -> void:
    var grid: Array       = ctx["grid"]
    var start_row: int  = ctx["start_row"]
    var end_row: int    = ctx["end_row"]
    var grid_size: Vector2i = ctx["grid_size"]

    var local_band := []
    for y in range(start_row, end_row):
        var row := []
        for x in range(grid_size.x):
            var alive := _next_state_conway(x, y, grid, grid_size)
            row.append(alive)
        local_band.append(row)

    mutex.lock()
    next_grid[band_idx] = local_band
    mutex.unlock()

func _next_state_conway(x: int, y: int, grid: Array, grid_size: Vector2i) -> int:
    var n := count_alive_neighbours(x, y, grid, grid_size)
    var alive: bool = grid[y][x] == 1
    return 1 if (alive and n in [2, 3]) or (not alive and n == 3) else 0
    
func _next_state_daynight(x: int, y: int, grid: Array, grid_size: Vector2i) -> int:
    var n := count_alive_neighbours(x, y, grid, grid_size)
    var alive: bool = grid[y][x] == 1
    return 1 if (alive and n in [3, 4, 6, 7, 8]) or (not alive and n in [3, 6, 7, 8]) else 0
    
func _next_state_highlife(x: int, y: int, grid: Array, grid_size: Vector2i) -> int:
    var n := count_alive_neighbours(x, y, grid, grid_size)
    var alive: bool = grid[y][x] == 1
    return 1 if (alive and n in [2, 3]) or (not alive and n in [3, 6]) else 0
    
func _next_state_withoutdeath(x: int, y: int, grid: Array, grid_size: Vector2i) -> int:
    var n := count_alive_neighbours(x, y, grid, grid_size)
    var alive: bool = grid[y][x] == 1
    return 1 if alive or (not alive and n == 3) else 0

func count_alive_neighbours(x: int, y: int, grid: Array, grid_size: Vector2i) -> int:
    var count := 0
    for dy in range(-1, 2):
        for dx in range(-1, 2):
            if dx == 0 and dy == 0:
                continue
            var nx := int(x + dx + grid_size.x) % int(grid_size.x)
            var ny := int(y + dy + grid_size.y) % int(grid_size.y)
            count += grid[ny][nx]
    return count
