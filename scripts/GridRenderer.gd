extends TileMap

# 瓦片类型常量
const TILE_OCCUPIED := 0
const TILE_EMPTY := 1

var grid_manager: Node2D  # 引用 GridManager

func _ready() -> void:
	pass

func _on_grid_updated():
	render_grid()

func render_grid():
		# 清除当前的所有瓦片
		clear()
		
		# 遍历 grid_manager 的 grid 数组
		for y in range(grid_manager.GRID_HEIGHT):
				for x in range(grid_manager.GRID_WIDTH):
						var tile_index = TILE_EMPTY  # 默认为空白格子
						
						if grid_manager.grid[y][x] != 0:
								tile_index = TILE_OCCUPIED  # 占据的格子
						
						# 设置瓦片
						set_cell(0, Vector2i(x, y), tile_index, Vector2i(0, 0))
