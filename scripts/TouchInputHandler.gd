extends Node

# 定义信号用于通知方块执行操作
signal move_left
signal move_right
signal move_down
signal rotate
signal hard_drop

# 触摸相关变量
var touch_start_position = Vector2.ZERO
var is_touching = false
var swipe_threshold = 40 # 滑动触发阈值（像素）
var tap_threshold = 10 # 点击的最大移动距离
var touch_start_time = 0 # 触摸开始时间
var tap_time_threshold = 0.2 # 点击的最大持续时间(秒)
var last_horizontal_move_time = 0 # 上次水平移动的时间
var horizontal_move_delay = 0.1 # 水平移动的间隔时间(秒)
var last_horizontal_position = Vector2.ZERO # 上次水平移动时的位置
var horizontal_move_threshold = 10 # 每次水平移动的最小阈值

# 状态控制变量
var last_move_direction = Vector2.ZERO
var has_moved_in_touch = false
var last_rotation_time = 0 # 上次旋转的时间
var rotation_delay = 0.3 # 旋转操作的间隔时间(秒)
var is_swiping_down = false # 下滑状态

func _ready():
	set_process_input(true)

# 处理输入事件
func _input(event):
	# 处理触摸事件
	if event is InputEventScreenTouch:
		_handle_touch(event)
	# 处理拖动事件
	elif event is InputEventScreenDrag and is_touching:
		_handle_drag(event)

# 处理触摸事件
func _handle_touch(event):
	if event.pressed:
		# 触摸开始
		touch_start_position = event.position
		last_horizontal_position = event.position
		is_touching = true
		touch_start_time = Time.get_ticks_msec() / 1000.0
		last_horizontal_move_time = 0
		has_moved_in_touch = false # 重置移动状态
		last_move_direction = Vector2.ZERO
		is_swiping_down = false # 重置下滑状态
	else:
		# 触摸结束
		is_touching = false
		
		# 只有在拖动过程中没有移动时，才在释放时处理移动
		if not has_moved_in_touch:
			handle_swipe(event.position)
		
		# 重置下滑状态
		is_swiping_down = false

# 处理拖动事件
func _handle_drag(event):
	var current_time = Time.get_ticks_msec() / 1000.0
	var drag_direction = event.position - touch_start_position
	
	# 首先检查是否已经处于向下滑动状态
	if is_swiping_down:
		# 如果已经在向下滑动，只处理垂直方向的移动
		if drag_direction.y > swipe_threshold:
			emit_signal("move_down")
			touch_start_position.y = event.position.y # 只更新Y坐标起始位置
			has_moved_in_touch = true
		return # 直接返回，不处理其他方向的移动
		
	# 检测主要的滑动方向
	var is_primarily_vertical = abs(drag_direction.y) > abs(drag_direction.x) * 1.2
	var is_primarily_horizontal = abs(drag_direction.x) > abs(drag_direction.y) * 1.2
	
	# 处理垂直向上滑动(旋转方块)
	if drag_direction.y < -swipe_threshold and is_primarily_vertical:
		# 添加时间间隔限制，避免连续快速旋转
		if current_time - last_rotation_time > rotation_delay:
			emit_signal("rotate")
			last_rotation_time = current_time
			touch_start_position = event.position # 更新起始位置以避免连续触发
			has_moved_in_touch = true
	
	# 处理垂直下滑
	elif drag_direction.y > swipe_threshold and is_primarily_vertical:
		# 设置为下滑状态，阻止后续水平移动
		is_swiping_down = true
		emit_signal("move_down")
		touch_start_position.y = event.position.y # 只更新Y坐标起始位置
		has_moved_in_touch = true
	
	# 处理水平滑动 - 只有在非下滑状态才处理
	elif is_primarily_horizontal and not is_swiping_down:
		# 计算与上次水平移动位置的差距
		var horizontal_diff = abs(event.position.x - last_horizontal_position.x)
		
		# 检查是否已经过了延迟时间并且移动距离足够
		var move_delay = horizontal_move_delay
		# 长时间拖动时逐渐减少延迟，提升连续移动速度
		if current_time - touch_start_time > 0.5:
			move_delay *= 0.7
		
		if current_time - last_horizontal_move_time > move_delay and horizontal_diff > horizontal_move_threshold:
			var new_direction = 1 if event.position.x > last_horizontal_position.x else -1
			var last_direction = 1 if last_move_direction.x > 0 else -1 if last_move_direction.x < 0 else 0
			
			# 只有方向改变或者满足移动条件时才触发移动
			if last_direction != new_direction or horizontal_diff > horizontal_move_threshold * 1.5:
				if new_direction > 0:
					emit_signal("move_right")
				else:
					emit_signal("move_left")
				
				# 更新上次移动的时间和位置
				last_horizontal_move_time = current_time
				last_horizontal_position = event.position
				last_move_direction = Vector2(new_direction, 0)
				has_moved_in_touch = true

# 处理滑动手势
func handle_swipe(end_position):
	var swipe_direction = end_position - touch_start_position
	var swipe_distance = swipe_direction.length()
	
	# 太短的滑动不处理，避免误触
	if swipe_distance < swipe_threshold * 0.8:
		# 检查是否为点击操作
		var touch_duration = (Time.get_ticks_msec() / 1000.0) - touch_start_time
		if swipe_distance < tap_threshold and touch_duration < tap_time_threshold:
			# 点击操作处理为旋转
			emit_signal("rotate")
		return
	
	# 使用辅助函数处理滑动方向和操作
	process_swipe_direction(swipe_direction)

# 处理滑动方向并执行相应操作
func process_swipe_direction(direction):
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# 确定主要方向
	var is_primarily_vertical = abs(direction.y) > abs(direction.x) * 1.2
	var is_primarily_horizontal = abs(direction.x) > abs(direction.y) * 1.2
	
	# 处理向上滑动(旋转)
	if direction.y < -swipe_threshold and is_primarily_vertical:
		if current_time - last_rotation_time > rotation_delay:
			emit_signal("rotate")
			last_rotation_time = current_time
	
	# 水平滑动处理
	elif is_primarily_horizontal and abs(direction.x) > swipe_threshold:
		if direction.x > 0:
			emit_signal("move_right")
		else:
			emit_signal("move_left")
	
	# 垂直向下滑动且超过阈值
	elif direction.y > swipe_threshold and is_primarily_vertical:
		var distance = int(direction.y / swipe_threshold)
		for i in range(min(distance, 3)): # 减少最大连续下落次数，提高控制精度
			emit_signal("move_down")
