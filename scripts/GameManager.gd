extends Node2D

@export var tetromino_scene: PackedScene
@onready var grid_manager = $GridManager  # 获取 GridManager 节点
@onready var grid_renderer = $GridRenderer/TileMap  # 获取 GridRenderer 节点
@onready var score_label = $UI/ScoreLabel  # 获取 ScoreLabel 节点
@onready var lines_label = $UI/LinesLabel  # 获取 LinesLabel 节点

# 添加分数和消除行数变量
var score = 0
var lines_cleared = 0

func _ready():
	spawn_new_tetromino()
	grid_renderer.grid_manager = grid_manager  # 将 GridManager 传递给 GridRenderer
	# 连接 grid_manager 的 grid_updated 信号
	grid_manager.connect("grid_updated", Callable(grid_renderer, "_on_grid_updated"))
	
	# 初始化UI显示
	update_score_display()

func spawn_new_tetromino():
	var new_tetromino = tetromino_scene.instantiate()
	new_tetromino.grid_manager = grid_manager  # 将 GridManager 传递给方块
	new_tetromino.connect("tetromino_locked", Callable(self, "_on_tetromino_locked"))
	new_tetromino.connect("game_over", Callable(self, "_on_game_over"))
	new_tetromino.connect("lines_cleared", Callable(self, "_on_lines_cleared"))
	new_tetromino.connect("piece_dropped", Callable(self, "_on_piece_dropped"))
	add_child(new_tetromino)

func _on_tetromino_locked():
	spawn_new_tetromino()

func _on_game_over():
	print("游戏结束")
	print("最终得分: %d, 消除行数: %d" % [score, lines_cleared])
	get_tree().paused = true  # 暂停游戏，或者执行其他游戏结束逻辑

	# get_tree().reload_current_scene()

# 处理行消除事件
func _on_lines_cleared(count):
	lines_cleared += count
	
	# 根据消除的行数计算得分
	# 经典俄罗斯方块得分规则: 1行=100, 2行=300, 3行=500, 4行=800
	var line_score = 0
	match count:
		1: line_score = 100
		2: line_score = 300
		3: line_score = 500
		4: line_score = 800  # 一次消4行（俄罗斯方块）
	
	score += line_score
	update_score_display()

# 处理方块下落得分
func _on_piece_dropped(height):
	# 下落得分通常很少，每下落一格得2分
	score += height * 2
	update_score_display()

# 更新分数显示
func update_score_display():
	if score_label:
		score_label.text = str(score)
	if lines_label:
		lines_label.text = str(lines_cleared)
