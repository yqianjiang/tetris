extends Node

const VERTICAL_DOMINANCE_FACTOR = 1.3 # 垂直分量比水平大多少倍才会被认为是垂直滑动，值越大代表越难触发垂直滑动
const SPEED_WEIGHT_FACTOR = 0.6 # 值越大代表速度对操作的影响越大
const HARD_DROP_SPEED_THRESHOLD = 0.5 # 硬降落速度阈值（值越低越容易触发 hard drop）

# 为滑动阈值创建可配置参数
@export var swipe_threshold: int = 40 # 滑动的最小距离（像素），值越高代表越难触发滑动
@export var tap_threshold: int = 8 # 点击的最大移动距离，值越高代表越容易触发点击
@export var rotation_delay: float = 0.3 # 旋转操作的间隔时间(秒)

# 定义信号用于通知方块执行操作
signal move_left
signal move_right
signal move_down
signal rotate
signal hard_drop

# 触摸相关变量
var touch_start_position = Vector2.ZERO
var is_touching = false
var touch_start_time = 0 # 触摸开始时间
var tap_time_threshold = 0.2 # 点击的最大持续时间(秒)
var last_horizontal_move_time = 0 # 上次水平移动的时间
var horizontal_move_delay = 0.2 # 水平移动的间隔时间(秒)，防止过快连续移动
var horizontal_move_threshold = 10 # 每次水平移动的最小阈值，防止误触发
var last_horizontal_position = Vector2.ZERO # 上次水平移动时的位置

# 状态控制变量
var last_move_direction = Vector2.ZERO
var has_moved_in_touch = false
var has_moved_horizontally = false # 新增：用于跟踪是否已经进行了水平移动
var last_rotation_time = 0 # 上次旋转的时间
var is_swiping_down = false # 下滑状态
var rotation_precision_lock = false # 旋转后强制精确移动的锁定状态
var rotation_precision_timeout = 0.0 # 旋转后精确移动锁定的超时时间

# 手势速度感知相关变量
var last_position = Vector2.ZERO # 上一次记录的位置
var last_time = 0.0 # 上一次记录的时间
var gesture_velocity = Vector2.ZERO # 当前手势速度
var gesture_speeds = [] # 记录最近的手势速度
var max_speed_records = 5 # 最多记录的速度数量
var min_speed_threshold = 150.0 # 最小速度阈值（像素/秒）
var max_speed_threshold = 1500.0 # 最大速度阈值（像素/秒）
var horizontal_precision_mode = true # 默认启用精确移动模式

# 持续移动相关变量
var hold_time_threshold = 0.4 # 长按触发时间(秒)，从0.3增加到0.4，降低误触发
var is_holding = false # 是否处于长按状态
var continuous_move_delay = 0.08 # 长按状态下的移动间隔(秒)
var hold_direction = 0 # 当前长按的方向 (-1:左, 0:无, 1:右)
var hold_start_time = 0 # 开始长按的时间
var rapid_move_count = 0 # 连续移动的计数器
var quick_move_threshold = 5 # 触发快速移动模式的连续移动次数
var is_in_quick_move = false # 是否处于快速移动模式
var continuous_move_ramp_up = true # 是否启用连续移动加速

# 快速滑动模式相关变量
var quick_swipe_threshold = 650.0 # 触发快速滑动的速度阈值，从400提高到650，大幅提高门槛
var quick_swipe_mode_duration = 0.5 # 快速滑动模式持续时间(秒)
var quick_swipe_mode_active = false # 是否处于快速滑动模式
var quick_swipe_mode_end_time = 0 # 快速滑动模式结束时间
var quick_swipe_move_count = 3 # 快速滑动模式下的移动次数

# 模式切换相关变量
var last_tap_time = 0 # 上次单击的时间，用于检测双击
var double_tap_threshold = 0.3 # 双击的时间阈值(秒)
var last_tap_position = Vector2.ZERO # 上次单击的位置
var double_tap_distance_threshold = 50 # 双击的最大距离阈值(像素)
var precision_toggle_cooldown = 0.0 # 精确模式切换冷却时间
var precision_toggle_cooldown_duration = 0.5 # 切换冷却持续时间(秒)
var movement_precision_indicator_visible = false # 是否显示移动精确度指示器
var movement_precision_indicator_fade_time = 0.0 # 指示器淡出时间

# 自定义信号，用于显示模式切换指示器
signal mode_changed(is_precision_mode) # 当移动模式切换时触发

func _ready():
	set_process_input(true)
	set_process(true) # 启用_process处理
	reset_gesture_speed()
	
	# 发送初始模式信号
	emit_signal("mode_changed", horizontal_precision_mode)

# 添加_process函数处理持续移动
func _process(_delta):
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# 检查并解除旋转后的精确移动锁定
	if rotation_precision_lock and current_time > rotation_precision_timeout:
		rotation_precision_lock = false
	
	# 处理长按持续移动
	if is_holding and hold_direction != 0:
		var move_delay = continuous_move_delay
		
		# 连续移动加速机制：随着持续移动次数增加，移动间隔减少
		if continuous_move_ramp_up and rapid_move_count > quick_move_threshold:
			# 在精确模式下，加速更慢，防止意外多格移动
			var acceleration_factor = 0.03 if horizontal_precision_mode else 0.05
			move_delay *= max(0.5, 1.0 - (rapid_move_count - quick_move_threshold) * acceleration_factor)
			move_delay = max(0.05, move_delay) # 设置最小延迟，精确模式下延迟更长
		
		if current_time - last_horizontal_move_time > move_delay:
			# 执行移动
			if hold_direction > 0:
				emit_signal("move_right")
			else:
				emit_signal("move_left")
				
			last_horizontal_move_time = current_time
			rapid_move_count += 1
			
			# 达到阈值后进入快速移动模式，但在精确模式下需要更多次数
			var threshold = quick_move_threshold * (2 if horizontal_precision_mode else 1)
			if rapid_move_count >= threshold:
				is_in_quick_move = true
	
	# 处理快速滑动模式超时
	if quick_swipe_mode_active and current_time > quick_swipe_mode_end_time:
		quick_swipe_mode_active = false
	
	# 处理模式指示器淡出
	if movement_precision_indicator_visible and current_time > movement_precision_indicator_fade_time:
		movement_precision_indicator_visible = false
		emit_signal("mode_changed", horizontal_precision_mode)

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
	has_moved_horizontally = false # 重置水平移动标志
	is_swiping_down = false
	
	# 重置位置和时间记录
	last_position = Vector2.ZERO
	last_time = 0.0
	
	# 重置手势速度数据
	reset_gesture_speed()
	
	# 重置持续移动相关变量
	is_holding = false
	hold_direction = 0
	hold_start_time = 0
	rapid_move_count = 0
	is_in_quick_move = false
	
	# 重置快速滑动模式
	quick_swipe_mode_active = false

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
	var current_time = Time.get_ticks_msec() / 1000.0
	
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
		
		# 初始化长按相关变量
		is_holding = false
		hold_start_time = touch_start_time
		hold_direction = 0
		rapid_move_count = 0
		is_in_quick_move = false
		
		# 更新最后一次点击信息
		last_tap_time = current_time
		last_tap_position = event.position
	else:
		# 触摸结束
		# 只有在拖动过程中没有移动时，才在释放时处理移动
		if not has_moved_in_touch:
			handle_swipe(event.position)
		
		# 完全重置所有触摸状态变量
		reset_touch_state()

# 将拖动处理拆分为更小的函数，提高可读性
func _handle_drag(event):
	var current_time = Time.get_ticks_msec() / 1000.0
	var drag_direction = event.position - touch_start_position
	var speed_factor = get_speed_factor() * SPEED_WEIGHT_FACTOR
	
	# 检测快速滑动手势
	_check_quick_swipe_mode(current_time)
	
	# 已经处于向下滑动状态
	if is_swiping_down:
		_handle_vertical_down_swipe(event)
		return
		
	# 检测主要的滑动方向
	var is_primarily_vertical = abs(drag_direction.y) > abs(drag_direction.x) * VERTICAL_DOMINANCE_FACTOR
	var is_primarily_horizontal = abs(drag_direction.x) > abs(drag_direction.y) * VERTICAL_DOMINANCE_FACTOR
	
	# 处理各个方向的滑动
	if is_primarily_vertical and not has_moved_horizontally: # 仅当没有水平移动时处理垂直滑动
		if drag_direction.y < -swipe_threshold:
			_handle_vertical_up_swipe(event, current_time, speed_factor)
		elif drag_direction.y > swipe_threshold:
			_handle_vertical_down_swipe(event, speed_factor)
	elif is_primarily_horizontal and not is_swiping_down:
		_handle_horizontal_swipe(event, current_time, speed_factor)

# 处理向上滑动(旋转)
func _handle_vertical_up_swipe(event, current_time, speed_factor):
	var adjusted_rotation_delay = rotation_delay * (1.0 - speed_factor * 0.5)
	if current_time - last_rotation_time > adjusted_rotation_delay:
		emit_signal("rotate")
		reset_after_rotation(current_time)
		touch_start_position = event.position
		has_moved_in_touch = true

# 处理向下滑动
func _handle_vertical_down_swipe(event, speed_factor = 0.0):
	# 如果已经进行了水平移动，则不允许向下滑动
	if has_moved_horizontally:
		return
		
	is_swiping_down = true
	
	if speed_factor > HARD_DROP_SPEED_THRESHOLD:
		emit_signal("hard_drop")
	else:
		emit_signal("move_down")
		
	touch_start_position.y = event.position.y
	has_moved_in_touch = true

# 处理水平滑动
func _handle_horizontal_swipe(event, current_time, speed_factor):
	var horizontal_diff = abs(event.position.x - last_horizontal_position.x)
	var move_delay = _calculate_horizontal_move_delay(current_time, speed_factor)
	var adjusted_threshold = _calculate_horizontal_threshold(speed_factor)
	
	# 检查是否已经过了延迟时间并且移动距离足够
	if current_time - last_horizontal_move_time > move_delay and horizontal_diff > adjusted_threshold:
		var new_direction = 1 if event.position.x > last_horizontal_position.x else -1
		var last_direction = 1 if last_move_direction.x > 0 else -1 if last_move_direction.x < 0 else 0
		
		# 检查长按状态 - 在精确模式下需要更长时间和更少移动才能触发
		var hold_threshold_multiplier = 1.2 if horizontal_precision_mode else 0.7
		var small_movement = horizontal_diff < swipe_threshold * hold_threshold_multiplier
		if small_movement and current_time - hold_start_time > hold_time_threshold:
			# 进入长按状态或更新长按方向
			is_holding = true
			hold_direction = new_direction
		
		# 只有方向改变或者满足移动条件时才触发移动
		if last_direction != new_direction or horizontal_diff > adjusted_threshold * 1.5:
			# 根据速度决定是否进行多次移动
			var move_count = 1
			
			# 在以下情况允许多格移动：
			# 1. 不使用精确模式
			# 2. 处于快速滑动模式
			# 3. 已经进入快速移动模式（连续移动多次后）
			if (not horizontal_precision_mode and (quick_swipe_mode_active or is_in_quick_move)):
				# 速度需要更高才会触发多次移动
				if speed_factor > 0.65:
					move_count += int(speed_factor * 1.5)
				
				# 对于特别快的滑动，额外增加移动次数
				if speed_factor > 0.85:
					move_count += 1
				
				# 快速滑动模式下额外增加移动次数
				if quick_swipe_mode_active:
					move_count += quick_swipe_move_count
			
			for i in range(move_count):
				if new_direction > 0:
					emit_signal("move_right")
				else:
					emit_signal("move_left")
			
			# 标记已进行水平移动
			has_moved_horizontally = true
			
			# 更新上次移动的时间和位置
			last_horizontal_move_time = current_time
			last_horizontal_position = event.position
			last_move_direction = Vector2(new_direction, 0)
			has_moved_in_touch = true
		
		# 如果移动距离较大，重置长按状态
		if horizontal_diff > swipe_threshold:
			is_holding = false
			hold_direction = 0
	
	# 如果水平移动距离较小，可能是尝试长按
	elif not is_holding and horizontal_diff < swipe_threshold * 0.5:
		# 检查是否满足长按触发条件，在精确模式下要求更长时间
		var adjusted_hold_threshold = hold_time_threshold * (1.2 if horizontal_precision_mode else 1.0)
		if current_time - hold_start_time > adjusted_hold_threshold:
			is_holding = true
			hold_direction = 1 if event.position.x > touch_start_position.x else -1 if event.position.x < touch_start_position.x else 0
			# 标记已进行水平移动
			has_moved_horizontally = true

# 计算水平移动阈值
func _calculate_horizontal_threshold(speed_factor):
	# 根据手势速度调整移动阈值
	return horizontal_move_threshold * (1.0 - speed_factor * 0.3)

# 根据速度和当前状态计算水平移动延迟
func _calculate_horizontal_move_delay(current_time, speed_factor):
	var move_delay = horizontal_move_delay
	
	if current_time - touch_start_time > 0.5:
		move_delay *= 0.8
	
	move_delay *= (1.0 - speed_factor * 0.4)
	
	if quick_swipe_mode_active:
		move_delay *= 0.5
		
	return move_delay

# 检查是否进入快速滑动模式
func _check_quick_swipe_mode(current_time):
	var current_speed = get_gesture_speed()
	var speed_threshold = quick_swipe_threshold * (1.0 if horizontal_precision_mode else 0.8)
	
	if current_speed > speed_threshold and not quick_swipe_mode_active:
		if not horizontal_precision_mode or current_speed > quick_swipe_threshold * 1.2:
			quick_swipe_mode_active = true
			quick_swipe_mode_end_time = current_time + quick_swipe_mode_duration

# 处理滑动手势
func handle_swipe(end_position):
	var swipe_direction = end_position - touch_start_position
	var swipe_distance = swipe_direction.length()
	var speed_factor = get_speed_factor() * SPEED_WEIGHT_FACTOR
	
	# 检查是否是快速滑动
	var current_speed = get_gesture_speed()
	var is_quick_swipe = current_speed > quick_swipe_threshold
	
	# 太短的滑动不处理，避免误触
	if (swipe_distance < swipe_threshold * 0.9): # 从0.8增加到0.9，增加触发滑动的难度
		# 检查是否为点击操作
		var touch_duration = (Time.get_ticks_msec() / 1000.0) - touch_start_time
		if swipe_distance < tap_threshold and touch_duration < tap_time_threshold:
			# 点击操作处理为旋转
			emit_signal("rotate")
			reset_after_rotation(Time.get_ticks_msec() / 1000.0)
		return
	
	# 使用辅助函数处理滑动方向和操作，传入速度因子
	var current_time = Time.get_ticks_msec() / 1000.0
	var effective_precision = horizontal_precision_mode
	if rotation_precision_lock and current_time < rotation_precision_timeout:
		effective_precision = true
	process_swipe_direction(swipe_direction, speed_factor * 0.7, is_quick_swipe, effective_precision)

# 处理滑动方向并执行相应操作
func process_swipe_direction(direction, speed_factor, is_quick_swipe = false, is_precision = true):
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# 确定主要方向
	var is_primarily_vertical = abs(direction.y) > abs(direction.x) * 1.2
	var is_primarily_horizontal = abs(direction.x) > abs(direction.y) * 1.2
	
	# 处理向上滑动(旋转)
	if direction.y < -swipe_threshold and is_primarily_vertical:
		if current_time - last_rotation_time > rotation_delay:
			emit_signal("rotate")
			reset_after_rotation(current_time)
	
	# 水平滑动处理
	elif is_primarily_horizontal and abs(direction.x) > swipe_threshold:
		# 根据速度和滑动距离决定移动次数
		var move_count = 1
		
		# 检查是否在旋转后的精确移动锁定期
		var effective_precision = is_precision
		if rotation_precision_lock and current_time < rotation_precision_timeout:
			effective_precision = true
		
		# 在非精确模式或快速滑动时允许多格移动
		if (not effective_precision and (is_quick_swipe)):
			# 基于速度的移动次数，但要求更高速度
			if speed_factor > 0.65:
				move_count += int(speed_factor * 2)
			
			# 根据滑动距离增加移动次数
			var swipe_distance = abs(direction.x)
			var distance_bonus = int(swipe_distance / (swipe_threshold * 2.0))
			if distance_bonus > 0:
				move_count += min(distance_bonus, 3)
			
			# 快速滑动额外增加移动次数
			if is_quick_swipe:
				move_count += quick_swipe_move_count
		
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

# 添加旋转后重置状态的函数
func reset_after_rotation(current_time):
	# 重置手势速度
	reset_gesture_speed()
	
	# 重置快速滑动模式
	quick_swipe_mode_active = false
	
	# 重置长按状态
	is_holding = false
	hold_direction = 0
	rapid_move_count = 0
	is_in_quick_move = false
	
	# 设置旋转后的精确移动锁定
	rotation_precision_lock = true
	rotation_precision_timeout = current_time + 0.5 # 旋转后0.5秒内强制使用精确移动
	
	# 记录旋转时间
	last_rotation_time = current_time
