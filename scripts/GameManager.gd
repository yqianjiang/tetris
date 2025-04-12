extends Node2D

# 定义游戏状态枚举
enum GameState {
	MENU,       # 游戏开始菜单状态
	PLAYING,    # 游戏进行中状态
	PAUSED,     # 游戏暂停状态
	GAME_OVER   # 游戏结束状态
}

@export var tetromino_scene: PackedScene
@onready var grid_manager = $GridManager  # 获取 GridManager 节点
@onready var grid_renderer = $GridRenderer/TileMap  # 获取 GridRenderer 节点
@onready var score_label = $UI/ScoreLabel  # 获取 ScoreLabel 节点
@onready var lines_label = $UI/LinesLabel  # 获取 LinesLabel 节点
@onready var level_label = $UI/LevelLabel  # 获取 LevelLabel 节点
@onready var pause_menu = $UI/GameMenu  # 获取暂停菜单
@onready var pause_button = $UI/PauseButton  # 获取暂停按钮
@onready var next_piece_preview = $UI/NextPiecePreview  # 获取下一个方块预览区域

# 添加分数和消除行数变量
var score = 0
var lines_cleared = 0
var level = 1  # 添加等级变量，初始为1级
var start_level = 1  # 初始等级

# 添加一个变量来跟踪当前是否有活动的方块
var has_active_tetromino = false
var game_state = GameState.MENU

# 添加变量来存储下一个方块的形状索引
var next_shape_index = 0

func _ready():
	# 初始化第一个下一个方块形状
	generate_next_shape()
	
	# 设置起始状态 - 游戏处于菜单状态
	game_state = GameState.MENU
	get_tree().paused = true
	update_pause_button_visible()
	
	# 准备游戏组件但不立即开始
	grid_renderer.grid_manager = grid_manager
	grid_manager.connect("grid_updated", Callable(grid_renderer, "_on_grid_updated"))
	grid_manager.connect("lines_to_clear", Callable(grid_renderer, "_on_lines_to_clear"))
	
	# 初始化UI显示
	update_score_display()
	
	# 设置暂停菜单的z_index为较高值，确保它始终显示在最顶层
	pause_menu.z_index = 5
	
	# 连接按钮信号
	pause_button.pressed.connect(toggle_pause)
	
	# 创建开始菜单
	setup_game_menu()
	
	# 显示开始菜单
	show_game_menu()

func update_pause_button_visible():
	pause_button.visible = game_state == GameState.PLAYING

# 设置游戏菜单
func setup_game_menu():
	var vbox = $UI/GameMenu/VBoxContainer
	
	# 连接开始游戏按钮
	var start_button = vbox.get_node_or_null("StartButton")
	start_button.pressed.connect(start_game)
	
	# 连接继续游戏按钮
	var resume_button = vbox.get_node_or_null("ResumeButton")
	resume_button.pressed.connect(resume_game)
	
	# 连接重新开始按钮
	var restart_button = vbox.get_node_or_null("RestartButton")
	restart_button.pressed.connect(restart_game)
	
	# 连接退出按钮
	var exit_button = vbox.get_node_or_null("ExitButton") 
	exit_button.pressed.connect(exit_game)
	
	# 添加等级选择器
	var level_selector = vbox.get_node_or_null("LevelSelector")
	if level_selector:		
		# 添加等级选择下拉菜单
		var option_button = level_selector.get_node("LevelOption")
		for i in range(1, 11): # 允许选择1-10级
			option_button.add_item(str(i), i-1)

# 开始游戏函数
func start_game():
	# 获取选择的等级
	var level_option = $UI/GameMenu/VBoxContainer/LevelSelector/LevelOption
	if level_option:
		level = level_option.selected + 1
		start_level = level  # 保存初始等级
	
	# 开始游戏
	game_state = GameState.PLAYING
	get_tree().paused = false
	update_pause_button_visible()
	hide_pause_ui()
	update_score_display()
	
	# 如果是首次开始游戏，则生成第一个方块
	if not has_active_tetromino:
		spawn_new_tetromino()

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
	if game_state == GameState.PLAYING:
		pause_game()
	elif game_state == GameState.PAUSED:
		resume_game()

# 暂停游戏
func pause_game():
	if game_state == GameState.PLAYING:
		game_state = GameState.PAUSED
		get_tree().paused = true
		update_pause_button_visible()
		show_game_menu()

# 继续游戏
func resume_game():
	if game_state == GameState.PAUSED:
		game_state = GameState.PLAYING
		update_pause_button_visible()
		hide_pause_ui()
		
		# 重置触摸输入处理器状态，避免暂停前的触摸状态影响恢复后的操作
		get_node('Tetromino/TouchInputHandler').reset_touch_state()
		
		get_tree().paused = false

# 重新开始游戏
func restart_game():
	# 重置游戏状态
	score = 0
	lines_cleared = 0
	level = 1
	has_active_tetromino = false
	# 清空网格
	grid_manager.clear_grid()
	# 清除旧的方块
	for child in get_children():
		if child is Tetromino:
			child.queue_free()
	# 清除下一个方块预览
	for child in next_piece_preview.get_children():
		if child is Sprite2D:
			child.queue_free()

	start_game()

# 退出游戏
func exit_game():
	get_tree().quit()

# 统一显示游戏菜单的函数
func show_game_menu():
	if pause_menu:
		pause_menu.visible = true
		
		var vbox = $UI/GameMenu/VBoxContainer

		# 获取菜单标题节点
		var menu_title = vbox.get_node_or_null("Title")
		if menu_title:
			menu_title.visible = true
			match game_state:
				GameState.MENU:
					menu_title.visible = false
				GameState.GAME_OVER:
					menu_title.text = "Game over"
				GameState.PAUSED:
					menu_title.text = "Paused"
		
		# 设置各按钮的可见性
		
		var start_button = vbox.get_node_or_null("StartButton")
		if start_button:
			start_button.visible = game_state == GameState.MENU
			
		var resume_button = vbox.get_node_or_null("ResumeButton")
		if resume_button:
			resume_button.visible = game_state == GameState.PAUSED
			
		var restart_button = vbox.get_node_or_null("RestartButton")
		if restart_button:
			restart_button.visible = game_state != GameState.MENU
			
		var level_selector = vbox.get_node_or_null("LevelSelector")
		if level_selector:
			level_selector.visible = game_state == GameState.MENU or game_state == GameState.GAME_OVER
		

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
	game_state = GameState.GAME_OVER
	
	get_tree().paused = true  # 暂停游戏
	update_pause_button_visible()
	
	# 显示游戏结束菜单
	show_game_menu()

# 处理行消除事件
func _on_lines_cleared(count):
	lines_cleared += count
	
	# 更新等级 - 每消除10行升一级
	level = (lines_cleared / 10) + start_level
	
	# 根据消除的行数计算得分，并乘以当前等级
	var line_score = 0
	match count:
		1: line_score = 100
		2: line_score = 300
		3: line_score = 700
		4: line_score = 1500
	
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
