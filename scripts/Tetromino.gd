extends Node2D

signal tetromino_locked
signal game_over

const TETROMINO_SHAPES = [
	[Vector2(0, 0), Vector2(1, 0), Vector2(-1, 0), Vector2(-2, 0)], # I 形
	[Vector2(0, 0), Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1)], # T 形
	[Vector2(0, 0), Vector2(1, 0), Vector2(-1, 0), Vector2(-1, -1)], # L 形
	[Vector2(0, 0), Vector2(1, 0), Vector2(-1, 0), Vector2(1, -1)], # J 形
	[Vector2(0, 0), Vector2(1, 0), Vector2(0, -1), Vector2(1, -1)], # O 形
	[Vector2(0, 0), Vector2(1, 0), Vector2(1, -1), Vector2(2, -1)], # S 形
	[Vector2(0, 0), Vector2(-1, 0), Vector2(-1, -1), Vector2(-2, -1)] # Z 形
]

var grid_manager: Node2D  # 引用 GridManager

# 新增一个 grid_position，用于存储基于网格坐标的当前位置
var grid_position = Vector2(4, 0)  # 例如初始位置

# 记录每个方块相对于 Tetromino 的局部网格偏移，相对于 grid_position
var local_blocks = [
	Vector2(0, 0),
	Vector2(1, 0),
	Vector2(-1, 0),
	Vector2(-2, 0)
]

var fall_time = 0.5 # 下落间隔，数字越小下落越快
var last_fall_time = 0

# 增加计时器变量用于键盘输入重复控制
var left_hold_timer := 0.0
var right_hold_timer := 0.0
var down_hold_timer := 0.0

const INITIAL_DELAY = 0.1  # 初始延迟
const REPEAT_INTERVAL = 0.05  # 重复间隔

func _ready():
	randomize()
	var shape_index = randi() % TETROMINO_SHAPES.size()
	local_blocks = TETROMINO_SHAPES[shape_index]

	# 检查生成的位置是否合法，如果不合法则结束游戏
	for local in local_blocks:
		var cell = grid_position + local
		if grid_manager.is_occupied(cell.x, cell.y):
			emit_signal("game_over")
			queue_free()
			return

	update_visual_position()

# 刷新视觉位置
func update_visual_position():
	# 假设子节点个数与 local_blocks 数量一致
	for i in range(get_child_count()):
		var block = get_child(i)
		# 将 grid 坐标转换为实际像素位置
		block.position = (grid_position + local_blocks[i]) * 32

# 每帧更新
func _process(delta):
	last_fall_time += delta
	
	# 左移动
	if Input.is_action_just_pressed("ui_left"):
		move_left()
		left_hold_timer = 0.0
	elif Input.is_action_pressed("ui_left"):
		left_hold_timer += delta
		if left_hold_timer >= INITIAL_DELAY:
			move_left()
			left_hold_timer = 0.0
	else:
		left_hold_timer = 0.0
	
	# 右移动
	if Input.is_action_just_pressed("ui_right"):
		move_right()
		right_hold_timer = 0.0
	elif Input.is_action_pressed("ui_right"):
		right_hold_timer += delta
		if right_hold_timer >= INITIAL_DELAY:
			move_right()
			right_hold_timer = 0.0
	else:
		right_hold_timer = 0.0
	
	# 下落（手动加速下落）
	if Input.is_action_pressed("ui_down"):
		down_hold_timer += delta
		if down_hold_timer >= INITIAL_DELAY:
			move_down()
			down_hold_timer = 0.0
	else:
		down_hold_timer = 0.0
	
	# 旋转保持单次触发
	if Input.is_action_just_pressed("ui_up"):
		rotate_tetromino()
	
	# 自动下落
	if last_fall_time >= fall_time:
		move_down()
		last_fall_time = 0

# 下落
func move_down():
	if can_move_to(Vector2(0, 1)):  # 注意这里传入的是 grid 单位
		grid_position.y += 1
		update_visual_position()
	else:
		lock_tetromino()
		queue_free()
		emit_signal("tetromino_locked")

# 左移
func move_left():
	if can_move_to(Vector2(-1, 0)):
		grid_position.x -= 1
		update_visual_position()

# 右移
func move_right():
	if can_move_to(Vector2(1, 0)):
		grid_position.x += 1
		update_visual_position()


# 旋转方块（顺时针 90°）
func rotate_tetromino():
	# 如果是 O 形（方块），不执行旋转
	if local_blocks.has(Vector2(1, -1)) and local_blocks.has(Vector2(0, -1)) and local_blocks.has(Vector2(1, 0)):
		return

	var rotated = []
	for block in local_blocks:
		# 顺时针旋转公式: (x, y) -> (-y, x)
		rotated.append(Vector2(-block.y, block.x))

	# 检查旋转后的每个块是否在有效位置上
	for local in rotated:
		var cell = grid_position + local
		if not grid_manager.is_inside_grid(cell.x, cell.y) or grid_manager.is_occupied(cell.x, cell.y):
			return  # 如果发生碰撞或超出边界，则取消旋转

	local_blocks = rotated
	update_visual_position()


# 检查方块是否可以在当前位置移动
func can_move_to(offset: Vector2) -> bool:
	var new_grid_position = grid_position + offset
	for local in local_blocks:
		# 计算该块在网格中的新位置
		var cell = new_grid_position + local
		# 判断边界及是否被占用
		if not grid_manager.is_inside_grid(cell.x, cell.y) or grid_manager.is_occupied(cell.x, cell.y):
			return false
	return true

# 锁定方块
func lock_tetromino():
	for local in local_blocks:
		var cell = grid_position + local
		grid_manager.store_block(cell.x, cell.y, 1)
	# 检查是否有满行
	for y in range(grid_manager.GRID_HEIGHT):
		if grid_manager.is_full_line(y):
			grid_manager.clear_line(y)
