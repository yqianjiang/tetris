extends Node2D

const CELL_SIZE = 87  # 确保使用正确的格子大小

signal tetromino_locked
signal game_over
signal lines_cleared(count)
signal piece_dropped(drop_height)

const TETROMINO_SHAPES = [
	[Vector2(0, 0), Vector2(1, 0), Vector2(-1, 0), Vector2(-2, 0)], # I 形
	[Vector2(0, 0), Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1)], # T 形
	[Vector2(0, 0), Vector2(1, 0), Vector2(-1, 0), Vector2(-1, -1)], # L 形
	[Vector2(0, 0), Vector2(1, 0), Vector2(-1, 0), Vector2(1, -1)], # J 形
	[Vector2(0, 0), Vector2(1, 0), Vector2(0, -1), Vector2(1, -1)], # O 形
	[Vector2(0, 0), Vector2(1, 0), Vector2(1, -1), Vector2(2, -1)], # S 形
	[Vector2(0, 0), Vector2(-1, 0), Vector2(-1, -1), Vector2(-2, -1)] # Z 形
]

var grid_manager: Node2D # 引用 GridManager

# 新增一个 grid_position，用于存储基于网格坐标的当前位置
var grid_position = Vector2(4, 0) # 例如初始位置

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

const INITIAL_DELAY = 0.1 # 初始延迟
const REPEAT_INTERVAL = 0.05 # 重复间隔

# 触摸相关变量
var touch_start_position = Vector2.ZERO
var is_touching = false
var swipe_threshold = 30 # 滑动触发阈值（像素）
var tap_threshold = 10 # 点击的最大移动距离
var touch_start_time = 0 # 触摸开始时间
var tap_time_threshold = 0.2 # 点击的最大持续时间(秒)
var last_horizontal_move_time = 0 # 上次水平移动的时间
var horizontal_move_delay = 0.1 # 水平移动的间隔时间(秒)
var last_horizontal_position = Vector2.ZERO # 上次水平移动时的位置
var horizontal_move_threshold = 15 # 每次水平移动的最小阈值
# 添加旋转控制变量
var last_rotation_time = 0 # 上次旋转的时间
var rotation_delay = 0.3 # 旋转操作的间隔时间(秒)

# 在类开始处添加下滑状态变量
var is_swiping_down = false

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
		block.position = (grid_position + local_blocks[i]) * CELL_SIZE

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
	
	# 按空格键硬降（直接下落到最底部）
	if Input.is_action_just_pressed("ui_select"):  # ui_select 对应空格键
		hard_drop()
	
	# 自动下落
	if last_fall_time >= fall_time:
		move_down()
		last_fall_time = 0

# 下落
func move_down():
	if can_move_to(Vector2(0, 1)): # 注意这里传入的是 grid 单位
		grid_position.y += 1
		update_visual_position()
	else:
		# 发送下落高度信号（即使没消行，下落也有少量得分）
		var drop_height = 5
		emit_signal("piece_dropped", drop_height)
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

	# 检查旋转后的每个块是否在有效位置上
	for local in rotated:
		var cell = grid_position + local
		if not grid_manager.is_inside_grid(cell.x, cell.y) or grid_manager.is_occupied(cell.x, cell.y):
			return # 如果发生碰撞或超出边界，则取消旋转

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
	# 将方块存入网格
	for local in local_blocks:
		var cell = grid_position + local
		grid_manager.store_block(cell.x, cell.y, 1)
	
	# 检查是否有满行并计算消除的行数
	var cleared_lines = 0
	if grid_manager.mark_lines_to_clear():  # 使用新方法标记要清除的行
		cleared_lines = grid_manager.lines_pending_clear.size()
		# 发出信号通知消除的行数
		if cleared_lines > 0:
			emit_signal("lines_cleared", cleared_lines)
	
	emit_signal("tetromino_locked")

# 硬降（直接落到底部）
func hard_drop():
	var drop_height = 0
	
	# 找出可以下落的最大距离
	while can_move_to(Vector2(0, 1)):
		grid_position.y += 1
		drop_height += 1
	
	update_visual_position()
	
	# 发出下落高度信号
	emit_signal("piece_dropped", drop_height)
	
	# 锁定方块
	lock_tetromino()
	queue_free()

# 处理输入事件
func _input(event):
	# 处理触摸事件
	if event is InputEventScreenTouch:
			if event.pressed:
					# 触摸开始
					touch_start_position = event.position
					last_horizontal_position = event.position
					is_touching = true
					touch_start_time = Time.get_ticks_msec() / 1000.0
					last_horizontal_move_time = 0
			else:
					# 触摸结束，检测是点击还是滑动
					is_touching = false
					var touch_duration = Time.get_ticks_msec() / 1000.0 - touch_start_time
					var touch_distance = (event.position - touch_start_position).length()
					
					# 如果是快速点击且不在下滑状态，才旋转方块
					if touch_duration < tap_time_threshold and touch_distance < tap_threshold and not is_swiping_down:
							rotate_tetromino()
					# 否则处理滑动
					else:
							handle_swipe(event.position)
					
					# 重置下滑状态
					is_swiping_down = false
	
	# 处理拖动事件
	elif event is InputEventScreenDrag and is_touching:
			var current_time = Time.get_ticks_msec() / 1000.0
			var drag_direction = event.position - touch_start_position
			
			# 处理垂直向上滑动(旋转方块)
			if drag_direction.y < -swipe_threshold and abs(drag_direction.y) > abs(drag_direction.x):
					# 添加时间间隔限制，避免连续快速旋转
					if current_time - last_rotation_time > rotation_delay:
							rotate_tetromino()
							last_rotation_time = current_time
							touch_start_position = event.position # 更新起始位置以避免连续触发
			
			# 处理垂直下滑
			elif drag_direction.y > swipe_threshold and abs(drag_direction.x) < abs(drag_direction.y):
					# 下滑操作立即加速下落
					move_down()
					touch_start_position = event.position # 更新起始位置以避免连续触发
			
			# 处理水平滑动
			if abs(drag_direction.x) > abs(drag_direction.y):
					# 计算与上次水平移动位置的差距
					var horizontal_diff = abs(event.position.x - last_horizontal_position.x)
					
					# 检查是否已经过了延迟时间并且移动距离足够
					if current_time - last_horizontal_move_time > horizontal_move_delay and horizontal_diff > horizontal_move_threshold:
							if event.position.x > last_horizontal_position.x:
									move_right()
							else:
									move_left()
							
							# 更新上次移动的时间和位置
							last_horizontal_move_time = current_time
							last_horizontal_position = event.position

# 处理滑动手势
func handle_swipe(end_position):
	var swipe_direction = end_position - touch_start_position
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# 处理向上滑动(旋转)
	if swipe_direction.y < -swipe_threshold and abs(swipe_direction.y) > abs(swipe_direction.x):
			if current_time - last_rotation_time > rotation_delay:
					rotate_tetromino()
					last_rotation_time = current_time
	
	# 水平滑动距离大于垂直滑动距离，且超过阈值
	elif abs(swipe_direction.x) > abs(swipe_direction.y) and abs(swipe_direction.x) > swipe_threshold:
			if swipe_direction.x > 0:
					move_right()
			else:
					move_left()
	
	# 垂直向下滑动且超过阈值
	elif swipe_direction.y > swipe_threshold and abs(swipe_direction.x) < abs(swipe_direction.y):
			is_swiping_down = true
			var distance = int(swipe_direction.y / swipe_threshold)
			for i in range(min(distance, 5)): # 限制最大连续下落次数
					move_down()
	else:
			is_swiping_down = false
