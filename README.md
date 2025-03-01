# 俄罗斯方块（练手项目）

设计：
- GridManager，维护 grid 数组，检测 grid 坐标内是否被占据、grid 边界，进行消除检查、消除等。
- Tetromino，下落中的方块，随机生成形状，处理渲染和移动，加速下落，落到最底部 store_block 把每个 block 交给 grid 接管。
- Renderer，根据 grid 数组渲染 TileMap（游戏背景网格）、Sprite（Block）。
- GameManager，控制游戏主循环，例如开始、暂停、结束等，并在消除完成后生成新的Tetromino
