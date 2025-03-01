extends Node2D

@export var tetromino_scene: PackedScene
@onready var grid_manager = $GridManager  # 获取 GridManager 节点
@onready var grid_renderer = $GridRenderer  # 获取 GridRenderer 节点

func _ready():
	spawn_new_tetromino()
	grid_renderer.grid_manager = grid_manager  # 将 GridManager 传递给 GridRenderer
	# 连接 grid_manager 的 grid_updated 信号
	grid_manager.connect("grid_updated", Callable(grid_renderer, "_on_grid_updated"))

func spawn_new_tetromino():
	var new_tetromino = tetromino_scene.instantiate()
	new_tetromino.grid_manager = grid_manager  # 将 GridManager 传递给方块
	new_tetromino.connect("tetromino_locked", Callable(self, "_on_tetromino_locked"))
	new_tetromino.connect("game_over", Callable(self, "_on_game_over"))
	add_child(new_tetromino)

func _on_tetromino_locked():
	spawn_new_tetromino()

func _on_game_over():
	print("游戏结束")
	get_tree().paused = true  # 暂停游戏，或者执行其他游戏结束逻辑

	# get_tree().reload_current_scene()
