extends TileMap

# 瓦片类型常量
const TILE_OCCUPIED := 0
const TILE_EMPTY := 1
const TILE_BLINK := 2  # 新增：闪烁瓦片类型
const TILE_PLACED := 2  # 新增：方块放置效果瓦片类型

var grid_manager: Node2D  # 引用 GridManager
var lines_to_blink = []   # 存储需要闪烁的行
var blink_timer = 0.0     # 闪烁计时器
var blink_count = 0       # 闪烁次数
const BLINK_DURATION = 0.15 # 每次闪烁持续时间
const MAX_BLINKS = 3      # 最大闪烁次数
var is_blinking = false   # 是否正在闪烁

# 新增：放置效果相关变量
var placed_blocks = []    # 存储刚刚放置的方块位置
var placed_effect_timer = 0.0  # 放置效果计时器
const PLACED_EFFECT_DURATION = 0.2  # 放置效果持续时间
var is_showing_placed_effect = false  # 是否正在显示放置效果

func _process(delta):
	if is_blinking:
		blink_timer += delta
		if blink_timer >= BLINK_DURATION:
			blink_timer = 0
			blink_count += 1
			render_grid()  # 重新渲染网格以更新闪烁效果
			
			if blink_count >= MAX_BLINKS:
				is_blinking = false
				grid_manager.clear_marked_lines()  # 闪烁结束后清除行
				lines_to_blink.clear()
	
	# 处理放置效果
	if is_showing_placed_effect:
		placed_effect_timer += delta
		if placed_effect_timer >= PLACED_EFFECT_DURATION:
			# 放置效果结束
			is_showing_placed_effect = false
			placed_blocks.clear()
			render_grid()  # 更新显示，移除放置效果

func _on_grid_updated():
	render_grid()

func _on_lines_to_clear(lines):
	lines_to_blink = lines
	is_blinking = true
	blink_timer = 0
	blink_count = 0
	render_grid()  # 立即更新显示

# 新增：处理方块放置效果
func _on_block_placed(positions):
	placed_blocks = positions
	is_showing_placed_effect = true
	placed_effect_timer = 0
	render_grid()  # 立即更新显示

func render_grid():
	# 清除当前的所有瓦片
	clear()
	
	# 遍历 grid_manager 的 grid 数组
	for y in range(grid_manager.GRID_HEIGHT):
		for x in range(grid_manager.GRID_WIDTH):
			var tile_index = TILE_EMPTY  # 默认为空白格子
			
			# 检查是否是刚放置的方块
			var is_placed = false
			if is_showing_placed_effect:
				for pos in placed_blocks:
					if pos.x == x and pos.y == y:
						tile_index = TILE_PLACED
						is_placed = true
						break
			
			# 如果不是刚放置的方块，检查是否是需要闪烁的行
			if not is_placed:
				if lines_to_blink.has(y):
					if is_blinking and (blink_count % 2 == 0):  # 偶数次闪烁时显示高亮
						tile_index = TILE_BLINK if grid_manager.grid[y][x] != 0 else TILE_EMPTY
					elif grid_manager.grid[y][x] != 0:
						tile_index = TILE_OCCUPIED
				elif grid_manager.grid[y][x] != 0:
					tile_index = TILE_OCCUPIED  # 占据的格子
			
			# 设置瓦片
			set_cell(0, Vector2i(x, y), tile_index, Vector2i(0, 0))
