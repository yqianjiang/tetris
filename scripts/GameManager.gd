extends Node2D

@export var tetromino_scene: PackedScene
@onready var grid_manager = $GridManager  # 获取 GridManager 节点
@onready var grid_renderer = $GridRenderer/TileMap  # 获取 GridRenderer 节点
@onready var score_label = $UI/ScoreLabel  # 获取 ScoreLabel 节点
@onready var lines_label = $UI/LinesLabel  # 获取 LinesLabel 节点
@onready var level_label = $UI/LevelLabel  # 获取 LevelLabel 节点
@onready var pause_menu = $UI/PauseMenu  # 获取暂停菜单
@onready var pause_button = $UI/PauseButton  # 获取暂停按钮
@onready var next_piece_preview = $UI/NextPiecePreview  # 获取下一个方块预览区域

# 添加分数和消除行数变量
var score = 0
var lines_cleared = 0
var level = 1  # 添加等级变量，初始为1级

# 添加一个变量来跟踪当前是否有活动的方块
var has_active_tetromino = false
# 添加游戏暂停状态变量
var game_paused = false

# 添加变量来存储下一个方块的形状索引
var next_shape_index = 0

func _ready():
	# 初始化第一个下一个方块形状
	generate_next_shape()
	
	spawn_new_tetromino()
	grid_renderer.grid_manager = grid_manager  # 将 GridManager 传递给 GridRenderer
	# 连接 grid_manager 的 grid_updated 信号
	grid_manager.connect("grid_updated", Callable(grid_renderer, "_on_grid_updated"))
	grid_manager.connect("lines_to_clear", Callable(grid_renderer, "_on_lines_to_clear"))
	
	# 初始化UI显示
	update_score_display()
	
	# 设置暂停菜单的z_index为较高值，确保它始终显示在最顶层
	pause_menu.z_index = 5
	
	# 连接暂停按钮信号
	pause_button.pressed.connect(toggle_pause)
	$UI/PauseMenu/VBoxContainer/ResumeButton.pressed.connect(resume_game)
	$UI/PauseMenu/VBoxContainer/ExitButton.pressed.connect(exit_game)

# 生成下一个方块的形状
func generate_next_shape():
	randomize()
	next_shape_index = randi() % GameConstants.TETROMINO_SHAPES_PREVIEW.size()
	update_next_piece_preview()

# 更新下一个方块的预览显示
func update_next_piece_preview():
	# 清除现有的预览
	for child in next_piece_preview.get_children():
		if child is Sprite2D:
			child.queue_free()
	
	# 获取下一个形状并在预览区域显示
	var next_shape = GameConstants.TETROMINO_SHAPES_PREVIEW[next_shape_index]
	
	# 为每个方块创建一个精灵
	for block_pos in next_shape:
		var block = Sprite2D.new()
		block.texture = load("res://assets/web_theme/block.png")  # 假设有一个方块贴图
		
		# 调整预览区域中方块的位置
		var offset = Vector2(1, 1)
		block.position = (block_pos + offset) * 40  # 使用较小尺寸
		block.scale = Vector2(0.45, 0.45)  # 缩小预览块的大小
		
		next_piece_preview.add_child(block)

# 添加输入处理函数
func _input(event):
	if event.is_action_pressed("ui_cancel"):  # ESC键
		toggle_pause()

# 暂停/继续游戏切换函数
func toggle_pause():
	if game_paused:
		resume_game()
	else:
		pause_game()

# 暂停游戏
func pause_game():
	if not game_paused:
		game_paused = true
		get_tree().paused = true
		show_pause_ui()

# 继续游戏
func resume_game():
	if game_paused:
		game_paused = false
		get_tree().paused = false
		hide_pause_ui()

# 退出游戏
func exit_game():
	get_tree().quit()

# 显示暂停UI
func show_pause_ui():
	if pause_menu:
		pause_menu.visible = true

# 隐藏暂停UI
func hide_pause_ui():
	if pause_menu:
		pause_menu.visible = false

func spawn_new_tetromino():
	# 如果已经有一个活动的方块，则不创建新的
	if has_active_tetromino:
		return
		
	var new_tetromino = tetromino_scene.instantiate()
	new_tetromino.grid_manager = grid_manager  # 将 GridManager 传递给方块
	new_tetromino.connect("tetromino_locked", Callable(self, "_on_tetromino_locked"))
	new_tetromino.connect("game_over", Callable(self, "_on_game_over"))
	new_tetromino.connect("lines_cleared", Callable(self, "_on_lines_cleared"))
	new_tetromino.connect("piece_dropped", Callable(self, "_on_piece_dropped"))
	
	# 设置tetromino的等级
	if "set_level" in new_tetromino:
		new_tetromino.set_level(level)
	
	# 使用预先生成的下一个方块形状
	new_tetromino.set_shape(next_shape_index)
	
	add_child(new_tetromino)
	
	# 设置活动方块标志
	has_active_tetromino = true
	
	# 生成新的下一个方块形状
	generate_next_shape()

func _on_tetromino_locked():
	# 重置活动方块标志，表示当前没有活动方块
	has_active_tetromino = false
	
	# 使用延时调用来避免同一帧内处理多个事件
	call_deferred("spawn_new_tetromino")

func _on_game_over():
	# 重置活动方块标志
	has_active_tetromino = false
	
	print("游戏结束")
	print("最终得分: %d, 消除行数: %d, 最终等级: %d" % [score, lines_cleared, level])
	get_tree().paused = true  # 暂停游戏，或者执行其他游戏结束逻辑

	# get_tree().reload_current_scene()

# 处理行消除事件
func _on_lines_cleared(count):
	lines_cleared += count
	
	# 更新等级 - 每消除10行升一级
	level = (lines_cleared / 10) + 1
	
	# 根据消除的行数计算得分，并乘以当前等级
	var line_score = 0
	match count:
		1: line_score = 100
		2: line_score = 300
		3: line_score = 700
		4: line_score = 1500  # 一次消4行（俄罗斯方块）
	
	# 得分乘以当前等级
	score += line_score * (level + 1)
	update_score_display()

# 处理方块下落得分
func _on_piece_dropped(height):
	score += height
	update_score_display()

# 更新分数显示
func update_score_display():
	if score_label:
		score_label.text = str(score)
	if lines_label:
		lines_label.text = str(lines_cleared)
	if level_label:
		level_label.text = str(level)
