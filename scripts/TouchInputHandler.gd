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
var horizontal_move_delay = 0.15 # 水平移动的间隔时间(秒)，从0.1增加到0.15
var last_horizontal_position = Vector2.ZERO # 上次水平移动时的位置
var horizontal_move_threshold = 15 # 每次水平移动的最小阈值，从10增加到15

# 状态控制变量
var last_move_direction = Vector2.ZERO
var has_moved_in_touch = false
var last_rotation_time = 0 # 上次旋转的时间
var rotation_delay = 0.3 # 旋转操作的间隔时间(秒)
var is_swiping_down = false # 下滑状态

# 手势速度感知相关变量
var last_position = Vector2.ZERO # 上一次记录的位置
var last_time = 0.0 # 上一次记录的时间
var gesture_velocity = Vector2.ZERO # 当前手势速度
var gesture_speeds = [] # 记录最近的手势速度
var max_speed_records = 5 # 最多记录的速度数量
var min_speed_threshold = 150.0 # 最小速度阈值（像素/秒），从100增加到150
var max_speed_threshold = 1500.0 # 最大速度阈值（像素/秒），从1000增加到1500
var horizontal_precision_mode = true # 启用水平精确移动模式

func _ready():
	set_process_input(true)
	reset_gesture_speed()

# 重置所有触摸状态变量的函数
func reset_touch_state():
	# 重置触摸基本状态
	touch_start_position = Vector2.ZERO
	is_touching = false
	touch_start_time = 0
	
	# 重置水平移动相关状态
	last_horizontal_move_time = 0
	last_horizontal_position = Vector2.ZERO
	
	# 重置方向和移动状态
	last_move_direction = Vector2.ZERO
	has_moved_in_touch = false
	last_rotation_time = 0
	is_swiping_down = false
	
	# 重置位置和时间记录
	last_position = Vector2.ZERO
	last_time = 0.0
	
	# 重置手势速度数据
	reset_gesture_speed()

# 重置手势速度数据
func reset_gesture_speed():
	gesture_velocity = Vector2.ZERO
	gesture_speeds = []
	last_time = Time.get_ticks_msec() / 1000.0

# 处理输入事件
func _input(event):
	# 处理触摸事件
	if event is InputEventScreenTouch:
		_handle_touch(event)
	# 处理拖动事件
	elif event is InputEventScreenDrag and is_touching:
		# 计算当前手势速度
		update_gesture_speed(event.position)
		_handle_drag(event)

# 更新手势速度
func update_gesture_speed(current_position):
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_delta = current_time - last_time
	
	# 添加最小时间阈值，防止极小的时间差导致计算不准确
	if time_delta > 0.005 and last_position != Vector2.ZERO:
		# 计算瞬时速度
		var instant_velocity = (current_position - last_position) / time_delta
		
		# 保存当前速度到历史记录
		gesture_speeds.append(instant_velocity)
		if gesture_speeds.size() > max_speed_records:
			# 移除最旧的记录
			gesture_speeds.pop_front()
		
		# 使用加权平均计算手势速度，最新的速度权重更高
		calculate_weighted_average_velocity()
	
	# 更新上次记录的位置和时间
	last_position = current_position
	last_time = current_time

# 计算加权平均速度，新数据有更高权重
func calculate_weighted_average_velocity():
	if gesture_speeds.size() == 0:
		gesture_velocity = Vector2.ZERO
		return
		
	var total_weight = 0.0
	gesture_velocity = Vector2.ZERO
	
	# 计算加权平均，最近的速度样本权重更大
	for i in range(gesture_speeds.size()):
		var weight = float(i + 1) # 权重线性增加
		gesture_velocity += gesture_speeds[i] * weight
		total_weight += weight
	
	if total_weight > 0:
		gesture_velocity /= total_weight

# 获取当前手势的速度大小
func get_gesture_speed():
	return gesture_velocity.length()

# 获取基于速度的操作因子（0.0-1.0之间）
func get_speed_factor():
	var speed = get_gesture_speed()
	# 应用平滑曲线使响应更加自然
	var normalized_speed = clamp((speed - min_speed_threshold) / (max_speed_threshold - min_speed_threshold), 0.0, 1.0)
	# 使用平方根函数使中低速度更有反应
	return sqrt(normalized_speed)

# 处理触摸事件
func _handle_touch(event):
	if event.pressed:
		# 触摸开始
		touch_start_position = event.position
		last_horizontal_position = event.position
		last_position = event.position # 初始化速度计算的起始位置
		is_touching = true
		touch_start_time = Time.get_ticks_msec() / 1000.0
		last_time = touch_start_time # 初始化速度计算的起始时间
		last_horizontal_move_time = 0
		has_moved_in_touch = false # 重置移动状态
		last_move_direction = Vector2.ZERO
		is_swiping_down = false # 重置下滑状态
		reset_gesture_speed() # 重置速度数据
	else:
		# 触摸结束
		# 只有在拖动过程中没有移动时，才在释放时处理移动
		if not has_moved_in_touch:
			handle_swipe(event.position)
		
		# 完全重置所有触摸状态变量
		reset_touch_state()

# 处理拖动事件
func _handle_drag(event):
	var current_time = Time.get_ticks_msec() / 1000.0
	var drag_direction = event.position - touch_start_position
	var speed_factor = get_speed_factor() * 0.5 # 从0.7减少到0.5，大幅降低速度因子的整体影响
	
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
		# 根据手势速度调整旋转间隔，速度越快间隔越短
		var adjusted_rotation_delay = rotation_delay * (1.0 - speed_factor * 0.5)
		if current_time - last_rotation_time > adjusted_rotation_delay:
			emit_signal("rotate")
			last_rotation_time = current_time
			touch_start_position = event.position # 更新起始位置以避免连续触发
			has_moved_in_touch = true
	
	# 处理垂直下滑
	elif drag_direction.y > swipe_threshold and is_primarily_vertical:
		# 设置为下滑状态，阻止后续水平移动
		is_swiping_down = true
		
		# 根据手势速度决定是否执行硬降落
		if speed_factor > 0.7: # 速度因子大于0.7时执行硬降落
			emit_signal("hard_drop")
		else:
			emit_signal("move_down")
			
		touch_start_position.y = event.position.y # 只更新Y坐标起始位置
		has_moved_in_touch = true
	
	# 处理水平滑动 - 只有在非下滑状态才处理
	elif is_primarily_horizontal and not is_swiping_down:
		# 计算与上次水平移动位置的差距
		var horizontal_diff = abs(event.position.x - last_horizontal_position.x)
		
		# 检查是否已经过了延迟时间并且移动距离足够
		# 根据手势速度调整延迟
		var move_delay = horizontal_move_delay
		
		# 长时间拖动时逐渐减少延迟，提升连续移动速度
		if current_time - touch_start_time > 0.5:
			move_delay *= 0.8 # 从0.7增加到0.8，减少延迟减少的幅度
		
		# 根据手势速度进一步调整延迟
		move_delay *= (1.0 - speed_factor * 0.4) # 从0.6减少到0.4，减少速度对延迟的影响
		
		# 根据手势速度调整移动阈值
		var adjusted_threshold = horizontal_move_threshold * (1.0 - speed_factor * 0.3) # 从0.5减少到0.3
		
		if current_time - last_horizontal_move_time > move_delay and horizontal_diff > adjusted_threshold:
			var new_direction = 1 if event.position.x > last_horizontal_position.x else -1
			var last_direction = 1 if last_move_direction.x > 0 else -1 if last_move_direction.x < 0 else 0
			
			# 只有方向改变或者满足移动条件时才触发移动
			if last_direction != new_direction or horizontal_diff > adjusted_threshold * 1.5:
				# 根据速度决定是否进行多次移动
				var move_count = 1
				
				# 只在非精确模式下才增加移动次数
				if not horizontal_precision_mode:
					# 速度需要更高才会触发多次移动
					if speed_factor > 0.7: # 从0.5提高到0.7
						move_count += int(speed_factor * 1.5) # 从2.5减少到1.5
					
					# 对于特别快的滑动，额外增加移动次数，但要求更高速度
					if speed_factor > 0.9: # 从0.8提高到0.9
						move_count += 1
					
					# 根据水平差值额外增加移动次数，但大幅增加阈值
					var distance_bonus = int(horizontal_diff / (horizontal_move_threshold * 3)) # 从2增加到3
					if distance_bonus > 0:
						move_count += min(distance_bonus, 2) # 从3减少到2，最多额外增加2格
				
				for i in range(move_count):
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
	var speed_factor = get_speed_factor() * 0.5 # 从0.7减少到0.5
	
	# 太短的滑动不处理，避免误触
	if (swipe_distance < swipe_threshold * 0.9): # 从0.8增加到0.9，增加触发滑动的难度
		# 检查是否为点击操作
		var touch_duration = (Time.get_ticks_msec() / 1000.0) - touch_start_time
		if swipe_distance < tap_threshold and touch_duration < tap_time_threshold:
			# 点击操作处理为旋转
			emit_signal("rotate")
		return
	
	# 使用辅助函数处理滑动方向和操作，传入速度因子
	process_swipe_direction(swipe_direction, speed_factor * 0.7) # 减少速度因子的整体影响

# 处理滑动方向并执行相应操作
func process_swipe_direction(direction, speed_factor):
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
		# 根据速度和滑动距离决定移动次数
		var move_count = 1
		
		# 只在非精确模式下才增加移动次数
		if not horizontal_precision_mode:
			# 基于速度的移动次数，但要求更高速度
			if speed_factor > 0.7: # 从0.5提高到0.7
				move_count += int(speed_factor * 2) # 从3减少到2
			
			# 根据滑动距离增加移动次数，但增加阈值
			var swipe_distance = abs(direction.x)
			var distance_bonus = int(swipe_distance / (swipe_threshold * 2.5)) # 从1.5增加到2.5
			if distance_bonus > 0:
				move_count += min(distance_bonus, 2) # 从4减少到2
		
		for i in range(move_count):
			if direction.x > 0:
				emit_signal("move_right")
			else:
				emit_signal("move_left")
	
	# 垂直向下滑动且超过阈值
	elif direction.y > swipe_threshold and is_primarily_vertical:
		# 检查是否应该执行硬降落（快速下落）
		if speed_factor > 0.8 or direction.y > swipe_threshold * 3: # 从0.7提高到0.8
			emit_signal("hard_drop")
		else:
			# 否则根据滑动距离和速度决定下落次数
			var base_distance = int(direction.y / swipe_threshold)
			var speed_bonus = int(speed_factor * 1.5) # 从2减少到1.5
			var move_count = min(base_distance + speed_bonus, 4) # 从5减少到4，减少最大下落次数
			
			for i in range(move_count):
				emit_signal("move_down")
