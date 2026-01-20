# 机器学习课程作业 - 基于YOLO-Pose的关键点检测与位姿解算


## 环境配置
pip install ultralytics

## 项目结构
```
.
├── runs/                       # 训练结果存储目录
│   └── pose/
│       ├── train18/            # YOLO-Pose模型训练结果
│       │   └── args.yaml       # 训练参数配置
│       └── train24/            # MobileNet模型训练结果
│           └── args.yaml       # 训练参数配置
├── block.py                    # 自定义网络模块实现
├── data.yaml                   # 数据集配置文件
├── mobilenet.yaml              # MobileNet模型配置
├── yolo-pose.yaml              # YOLO-Pose模型配置
├── train.py                    # 模型训练脚本
├── solvepnp.py                 # 识别和位姿解算可视化脚本
├── predictv.py                 # 视频预测脚本
└── ...                         # 其他资源文件
```

## 核心模块说明

## block.py
包含以下关键网络组件：
[ConvBNReLU]: 卷积+批归一化+激活函数组合模块
[h_swish]: H-Swish激活函数
[SE_Attention]: SE注意力机制模块
[InvertedResidual]: 倒残差块，MobileNet的核心组件

## 模型配置
[yolo-pose.yaml]: YOLO的模型配置
[mobilenet.yaml]: 使用倒残差块的模型配置

## 训练与推理
[train.py]: 模型训练入口
[solvepnp.py]: 识别和解算的可视化
[predictv.py]: 视频预测脚本

## 识别和姿态解算
[solvepnp.py]
- 加载训练好的模型检测关键点
- 使用solvePnP解算物体的位置和姿态
- 可视化检测结果和重投影结果
- 绘制坐标轴显示物体的方向

## 使用方法

### 训练模型
```bash
python train.py
```

### 运行识别和解算
```bash
python solvepnp.py
```



