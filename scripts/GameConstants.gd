extends Node

# 俄罗斯方块形状定义
const TETROMINO_SHAPES = [
	[Vector2(0, 0), Vector2(1, 0), Vector2(-1, 0), Vector2(-2, 0)], # I 形
	[Vector2(0, 0), Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1)], # T 形
	[Vector2(0, 0), Vector2(1, 0), Vector2(-1, 0), Vector2(-1, -1)], # L 形
	[Vector2(0, 0), Vector2(1, 0), Vector2(-1, 0), Vector2(1, -1)], # J 形
	[Vector2(0, 0), Vector2(1, 0), Vector2(0, -1), Vector2(1, -1)], # O 形
	[Vector2(0, 0), Vector2(1, 0), Vector2(1, -1), Vector2(2, -1)], # S 形
	[Vector2(0, 0), Vector2(-1, 0), Vector2(-1, -1), Vector2(-2, -1)] # Z 形
]

const TETROMINO_SHAPES_PREVIEW = [
	[Vector2(0, 1), Vector2(1, 1), Vector2(2, 1), Vector2(3, 1)], # I 形：水平四格，在第二行
	[Vector2(0, 1), Vector2(1, 1), Vector2(2, 1), Vector2(1, 0)], # T 形：水平三格，中间向上一格
	[Vector2(0, 1), Vector2(1, 1), Vector2(2, 1), Vector2(0, 0)], # L 形：水平三格，左端向上一格
	[Vector2(0, 1), Vector2(1, 1), Vector2(2, 1), Vector2(2, 0)], # J 形：水平三格，右端向上一格
	[Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)], # O 形：2x2正方形
	[Vector2(1, 0), Vector2(2, 0), Vector2(0, 1), Vector2(1, 1)], # S 形：右侧两格在上，左侧两格在下
	[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(2, 1)]  # Z 形：左侧两格在上，右侧两格在下
]

# 其他游戏常量可以在这里添加
const CELL_SIZE = 87
