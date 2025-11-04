extends Node2D

@onready var tilemap: TileMapLayer = $TileMapLayer

@warning_ignore("integer_division")
var grid_size = Vector2(1920/8, 1080/8)
var grid = []
var next_grid = []

var paused = true

func _ready() -> void:
	init_grid()
	draw_grid()
	
func _on_timer_timeout() -> void:
	if !paused:
		update_grid()
		draw_grid()
	
func _physics_process(_delta):
	if Input.is_action_pressed("click"):
		var coords = tilemap.local_to_map(get_global_mouse_position())
		grid[coords.x][coords.y] = 1
		draw_grid()
	
	if Input.is_action_just_released("pause"):
		paused = !paused
		
	if Input.is_action_just_released("clear"):
		clear_grid()
		draw_grid()
	
func init_grid():
	grid = []
	for x in range(grid_size.x):
		var row = []
		for y in range(grid_size.y):
			row.append(1 if randf() > 0.9 else 0)
		grid.append(row)
		
func clear_grid():
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			grid[x][y] = 0
		
func draw_grid():
	for x in (grid_size.x):
		for y in (grid_size.y):
			tilemap.set_cell(Vector2i(x, y), 0, Vector2i(0, grid[x][y]))

func update_grid():
	next_grid = []
	
	for x in (grid_size.x):
		var row = []
		for y in (grid_size.y):
			var alive_neighbours = count_alive_neighbours(x, y)
			
			if grid[x][y] == 1:
				if alive_neighbours == 2 or alive_neighbours == 3:
					row.append(1)
				else:
					row.append(0)
			else:
				if alive_neighbours == 3:
					row.append(1)
				else:
					row.append(0)
		next_grid.append(row)
	grid = next_grid

func count_alive_neighbours(x, y):
	var count = 0
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue  # Skip the current cell
			var nx = int(x + dx + grid_size.x) % int(grid_size.x)
			var ny = int(y + dy + grid_size.y) % int(grid_size.y)
			count += grid[nx][ny]
	return count
