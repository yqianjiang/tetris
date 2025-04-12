extends Node2D

signal grid_updated
signal lines_to_clear(lines) # 新增信号，用于通知有行要被清除

const GRID_WIDTH = 10
const GRID_HEIGHT = 20

var grid = [] # 用于存储方块状态的二维数组
var lines_pending_clear = [] # 新增：存储待清除的行

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

# 标记要清除的行
func mark_lines_to_clear():
	lines_pending_clear.clear()
	for y in range(GRID_HEIGHT):
		if is_full_line(y):
			lines_pending_clear.append(y)
	
	if lines_pending_clear.size() > 0:
		emit_signal("lines_to_clear", lines_pending_clear)
		return true
	return false

# 清除整行并让上方方块下移
func clear_line(y: int):
	for x in range(GRID_WIDTH):
		if grid[y][x] != 0:
			grid[y][x] = 0

# 清除所有标记的行
func clear_marked_lines():
	# 从上往下清除，以免影响索引
	lines_pending_clear.sort()
	
	for y in lines_pending_clear:
		clear_line(y)
		move_down_rows(y)

	lines_pending_clear.clear()
	emit_signal("grid_updated")

# 让上方的方块下移
func move_down_rows(start_y: int):
	for y in range(start_y, 1, -1):
		for x in range(GRID_WIDTH):
			if grid[y - 1][x] != 0:
				grid[y][x] = grid[y - 1][x]
				grid[y - 1][x] = 0

# 清空网格，用于游戏重新开始
func clear_grid():
	# 重置网格中的所有单元格为空
	for y in range(grid.size()):
		for x in range(grid[y].size()):
			grid[y][x] = 0
	
	# 发送网格更新信号
	emit_signal("grid_updated")
	
