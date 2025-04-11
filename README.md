# 俄罗斯方块

demo 链接：https://tetris.webgames.fun

实现了经典俄罗斯方块的核心玩法，包括方块下落、旋转、消除等功能。

设计：
- GridManager，维护 grid 数组，检测 grid 坐标内是否被占据、grid 边界，进行消除检查、消除等。
- Tetromino，下落中的方块，随机生成形状，处理渲染和移动，加速下落，落到最底部 store_block 把每个 block 交给 grid 接管。
- Renderer，根据 grid 数组渲染 TileMap（游戏背景网格）、Sprite（Block）。
- GameManager，控制游戏主循环，例如开始、暂停、结束等，并在消除完成后生成新的Tetromino

## 项目结构

```
├── assets/                  # 游戏资源
├── docs/                    # 导出的游戏文件
├── scripts/                 # 游戏脚本
├── Game.tscn                # 主游戏场景
├── GridRenderer.tscn        # 网格渲染场景
├── Tetromino.tscn           # 方块场景
└── project.godot            # Godot项目文件
```

## 开发说明
1. 项目使用 Godot 引擎开发
2. 主要使用 GDScript 编写游戏逻辑
3. 使用信号（Signal）机制实现组件间通信

## 如何运行
1. 安装 Godot 引擎
2. 打开 Godot，导入项目
3. 点击"运行"按钮启动游戏

## 导出版本
已导出的网页版本可在 docs 目录找到。
