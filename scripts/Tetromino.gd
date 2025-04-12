extends Node2D
class_name Tetromino

const CELL_SIZE = 87  # 确保使用正确的格子大小

signal game_over
signal lines_cleared(count)
signal piece_dropped(drop_height)
signal block_placed(positions)  # 新增信号：方块放置位置

var grid_manager: Node2D # 引用 GridManager
var touch_input_handler: Node # 触摸输入处理器

# 新增一个 grid_position，用于存储基于网格坐标的当前位置
var grid_position = Vector2(4, 0) # 例如初始位置

# 记录每个方块相对于 Tetromino 的局部网格偏移，相对于 grid_position
var local_blocks = [
	Vector2(0, 0),
	Vector2(1, 0),
	Vector2(-1, 0),
	Vector2(-2, 0)
]

var fall_time = 1 # 下落间隔，数字越小下落越快
var last_fall_time = 0
var current_level = 1 # 添加当前等级变量

# 增加计时器变量用于键盘输入重复控制
var left_hold_timer := 0.0
var right_hold_timer := 0.0
var down_hold_timer := 0.0

const INITIAL_DELAY = 0.1 # 初始延迟

var soft_drop_height = 0
var is_hard_dropping = false # 标记是否正在执行硬降动画
var hard_drop_target_y = 0 # 硬降的目标Y坐标
var hard_drop_speed = 180.0 # 硬降的移动速度 (格子/秒)

# 添加触摸免疫期相关变量
var touch_immunity_timer = 0.0
var touch_immunity_duration = 0.3 # 生成后0.3秒内免疫向下触摸

func _ready():
	randomize()
	
	# 根据当前等级调整下落速度
	adjust_fall_time()

	# 初始化触摸免疫计时器
	touch_immunity_timer = 0.0

	# 如果位置被占据，就不生成了
	for local in local_blocks:
		var cell = grid_position + local
		if grid_manager.is_occupied(cell.x, cell.y):
			queue_free() # 直接销毁这个方块
			return

	# 初始化触摸输入处理器
	setup_touch_input_handler()
	
	update_visual_position()

# 初始化触摸输入处理器
func setup_touch_input_handler():
	# 创建触摸输入处理器实例
	touch_input_handler = load("res://scripts/TouchInputHandler.gd").new()
	touch_input_handler.name = "TouchInputHandler"
	add_child(touch_input_handler)
	
	# 连接信号
	touch_input_handler.connect("move_left", Callable(self, "move_left"))
	touch_input_handler.connect("move_right", Callable(self, "move_right"))
	touch_input_handler.connect("move_down", Callable(self, "handle_move_down"))
	touch_input_handler.connect("rotate", Callable(self, "rotate_tetromino"))
	touch_input_handler.connect("hard_drop", Callable(self, "handle_hard_drop"))
	
	# 重置触摸处理器状态
	touch_input_handler.reset_touch_state()

# 新增：处理向下移动，增加免疫期检查
func handle_move_down():
	if touch_immunity_timer <= 0:
		soft_drop()

# 新增：处理硬降，增加免疫期检查
func handle_hard_drop():
	if touch_immunity_timer <= 0:
		hard_drop()

# 执行软降
func soft_drop():
	move_down(true)

# 刷新视觉位置
func update_visual_position():
	# 假设子节点个数与 local_blocks 数量一致
	for i in range(get_child_count()):
		var block = get_child(i)
		# 跳过非方块节点（如触摸输入处理器）
		if block.get_class() != "Sprite2D":
			continue
		# 将 grid 坐标转换为实际像素位置
		var index = min(i, local_blocks.size() - 1)
		var grid_coords = grid_position + local_blocks[index]
		block.position = grid_coords * CELL_SIZE
		
		# 设置方块可见性 - 超出顶部边界的方块不可见
		block.visible = grid_coords.y >= 0

# 每帧更新
func _process(delta):
	# 更新触摸免疫计时器
	if touch_immunity_timer > 0:
		touch_immunity_timer -= delta
	
	last_fall_time += delta
	
	# 处理硬降动画
	if is_hard_dropping:
		var step = hard_drop_speed * delta # 计算本帧应移动的格子数
		# 如果接近目标或已达到目标，完成硬降
		if abs(grid_position.y - hard_drop_target_y) <= step:
			var drop_height = hard_drop_target_y - grid_position.y
			grid_position.y = hard_drop_target_y
			update_visual_position()
			is_hard_dropping = false
			finalize_hard_drop(int(drop_height))
		else:
			# 继续向目标移动
			grid_position.y += step
			update_visual_position()
		return # 硬降过程中不处理其他输入
	
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
			move_down(true)
			down_hold_timer = 0.0
	else:
		down_hold_timer = 0.0
	
	# 旋转保持单次触发
	if Input.is_action_just_pressed("ui_up"):
		rotate_tetromino()
	
	# 按空格键硬降（直接下落到最底部）
	if Input.is_action_just_pressed("ui_select"):  # ui_select 对应空格键
		hard_drop()
	
	# 自动下落
	if last_fall_time >= fall_time:
		move_down(false)
		last_fall_time = 0

# 下落
func move_down(is_soft_drop: bool):
	if can_move_to(Vector2(0, 1)): # 注意这里传入的是 grid 单位
		grid_position.y += 1
		update_visual_position()
		# 软降时增加下落高度
		if is_soft_drop:
			soft_drop_height += 1
	else:
		lock_tetromino()
		queue_free()

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
	
	# 尝试的偏移列表 - 墙踢机制
	var offsets = [
		Vector2(0, 0),   # 原位置
		Vector2(-1, 0),  # 左移1格
		Vector2(1, 0),   # 右移1格
		Vector2(-2, 0),  # 左移2格 (I形可能需要)
		Vector2(2, 0),   # 右移2格 (I形可能需要)
		Vector2(0, -1),  # 向上偏移，适用于底部
	]
	
	# 尝试每个偏移
	for offset in offsets:
		if try_rotation_with_offset(rotated, offset):
			# 旋转成功，应用旋转和偏移
			local_blocks = rotated
			grid_position += offset
			update_visual_position()
			return

# 辅助函数：尝试使用给定偏移量旋转
func try_rotation_with_offset(rotated_blocks, offset):
	var new_grid_position = grid_position + offset
	
	for local in rotated_blocks:
		var cell = new_grid_position + local
		
		# 特殊处理顶部超出边界的情况
		if cell.y < 0:
			# 顶部可以超出边界，但水平方向仍需在边界内
			if cell.x < 0 or cell.x >= grid_manager.GRID_WIDTH:
				return false
		# 正常边界检查
		elif not grid_manager.is_inside_grid(cell.x, cell.y) or grid_manager.is_occupied(cell.x, cell.y):
			return false # 此偏移不可用
	
	return true # 此偏移可以使用

# 检查方块是否可以在当前位置移动
func can_move_to(offset: Vector2) -> bool:
	var new_grid_position = grid_position + offset
	for local in local_blocks:
		# 计算该块在网格中的新位置
		var cell = new_grid_position + local
		
		# 特殊处理顶部超出边界的情况
		if cell.y < 0:
			# 顶部可以超出边界，但水平方向仍需在边界内
			if cell.x < 0 or cell.x >= grid_manager.GRID_WIDTH:
				return false
		# 正常边界检查
		elif not grid_manager.is_inside_grid(cell.x, cell.y) or grid_manager.is_occupied(cell.x, cell.y):
			return false
	return true

# 锁定方块
func lock_tetromino():
	# 将方块存入网格
	var placed_positions = []  # 存储放置的方块位置
	for local in local_blocks:
		var cell = grid_position + local
		grid_manager.store_block(cell.x, cell.y, 1)
		placed_positions.append(cell)  # 记录放置的位置
	
	# 发出方块放置位置的信号
	emit_signal("block_placed", placed_positions)
	
	# 检查是否有满行并计算消除的行数
	var cleared_lines = 0
	if grid_manager.mark_lines_to_clear():  # 使用新方法标记要清除的行
		cleared_lines = grid_manager.lines_pending_clear.size()
		# 发出信号通知消除的行数
		if cleared_lines > 0:
			emit_signal("lines_cleared", cleared_lines)
	
	# 软降计分
	emit_signal("piece_dropped", soft_drop_height)
	soft_drop_height = 0 # 重置下落高度

	check_game_over()

func check_game_over():
	# 检查游戏结束条件：有方块锁定在顶部区域（y <= 0）
	for local in local_blocks:
		var cell = grid_position + local
		if cell.y <= 0:
			emit_signal("game_over")
			return

# 硬降（直接落到底部）
func hard_drop():
	var drop_height = calculate_drop_height()
	
	if drop_height > 0:
		# 设置硬降动画状态
		is_hard_dropping = true
		hard_drop_target_y = grid_position.y + drop_height
	else:
		# 如果不能下落，直接锁定
		finalize_hard_drop(0)

# 计算可下落的最大高度
func calculate_drop_height() -> int:
	var height = 0
	while can_move_to(Vector2(0, height + 1)):
		height += 1
	return height

# 完成硬降并锁定方块
func finalize_hard_drop(drop_height: int):
	# 发出下落高度信号
	emit_signal("piece_dropped", drop_height * 2) # 硬降得分翻倍
	
	# 锁定方块
	lock_tetromino()
	queue_free()

# 设置当前等级并调整下落速度
func set_level(level):
	current_level = level
	adjust_fall_time()

# 根据等级调整下落速度
func adjust_fall_time():
	var initial_fall_time = 1.0 # 初始下落时间
	var min_fall_time = 0.1 # 最快下落时间

	var new_fall_time = initial_fall_time / (1 + current_level * 0.3)
	fall_time = max(min_fall_time, new_fall_time)

# 设置方块形状
func set_shape(shape_index: int):
	if shape_index >= 0 and shape_index < GameConstants.TETROMINO_SHAPES.size():
		local_blocks = GameConstants.TETROMINO_SHAPES[shape_index].duplicate()
		# 确保视觉元素更新
		if is_inside_tree():
			update_visual_position()
