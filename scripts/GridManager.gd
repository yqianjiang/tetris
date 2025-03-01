extends Node2D

signal grid_updated

const GRID_WIDTH = 10
const GRID_HEIGHT = 20

const TILE_INDEX = 6  # 贴图索引

var grid = [] # 用于存储方块状态的二维数组

func _ready():
	# 初始化网格
	for y in range(GRID_HEIGHT):
		grid.append([])
		for x in range(GRID_WIDTH):
			grid[y].append(0)  # 0 代表没有方块

# 存储方块
func store_block(x: int, y: int, block: int):
	if is_inside_grid(x, y):
		grid[y][x] = block
		emit_signal("grid_updated")

# 检查某个位置是否已被占据
func is_occupied(x: int, y: int) -> bool:
	return is_inside_grid(x, y) and grid[y][x] != 0

# 判断坐标是否在网格内
func is_inside_grid(x: int, y: int) -> bool:
	return x >= 0 and x < GRID_WIDTH and y >= 0 and y < GRID_HEIGHT

# 检查指定行是否已填满所有方块
func is_full_line(y: int) -> bool:
	for x in range(GRID_WIDTH):
		if grid[y][x] == 0:
			return false
	return true

# 清除整行并让上方方块下移
func clear_line(y: int):
	for x in range(GRID_WIDTH):
		if grid[y][x] != 0:
			grid[y][x] = 0
	move_down_rows(y)
	emit_signal("grid_updated")

# 让上方的方块下移
func move_down_rows(start_y: int):
	for y in range(start_y, 1, -1):
		for x in range(GRID_WIDTH):
			if grid[y - 1][x] != 0:
				grid[y][x] = grid[y - 1][x]
				grid[y - 1][x] = 0
