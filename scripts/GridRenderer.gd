extends Node2D

const CELL_SIZE = 32  # 确保使用正确的格子大小

var grid_manager: Node2D  # 引用 GridManager

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

func _draw():
	render_grid()

func _on_grid_updated():
	queue_redraw()

func render_grid():
	# 遍历 grid_manager 的 grid 数组
	for y in range(grid_manager.GRID_HEIGHT):
		for x in range(grid_manager.GRID_WIDTH):
			var rect = Rect2(Vector2(x, y) * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE))
			if grid_manager.grid[y][x] != 0:
				draw_rect(rect, Color(0.2, 0.2, 0.2))  # 绘制已占据的格子
			else:
				draw_rect(rect, Color(0.8, 0.8, 0.8))  # 绘制空白格子
			# 绘制黑色边框
			draw_rect(rect, Color(0.6, 0.6, 0.6), false, 1)
