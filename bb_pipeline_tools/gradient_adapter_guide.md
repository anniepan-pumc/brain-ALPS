# 3T MRI梯度系数文件适配指南

## 概述
本指南说明如何修改 `shunyi_coeff.grad` 文件以适配不同的3T MRI设备。

## 1. 获取目标设备参数

### 1.1 设备信息收集
需要获取以下信息：
- **设备制造商**: Siemens/GE/Philips
- **设备型号**: 具体型号名称
- **梯度强度**: 通常为40-80 mT/m
- **参考半径**: 通常为0.25-0.30 m
- **设备ID**: 制造商提供的设备标识符

### 1.2 获取梯度系数的方法

#### 方法A: 从制造商获取
```bash
# Siemens设备
# 联系Siemens技术支持获取 .grad 文件
# 通常在设备安装时提供

# GE设备  
# 获取GE设备的梯度系数文件
# 格式可能略有不同

# Philips设备
# 获取Philips设备的相应参数
```

#### 方法B: 通过校准扫描获取
```bash
# 运行梯度校准序列
# 使用专门的梯度场测量序列
# 分析校准数据提取系数
```

## 2. 文件修改步骤

### 2.1 修改文件头部信息
```grad
#*[ Script ****************************************************************\
#
# Name        : [NEW_DEVICE_NAME].grad (Design per [DATE])
#
# Author      : [YOUR_NAME]
#
# Language    : 
#
# Description : Defines Legendre coefficients in spherical harmonics for
#               Gradient Coil [NEW_DEVICE_MODEL] (r0=[NEW_RADIUS]m) 
#               
#****************************************************************************/
```

### 2.2 修改设备参数
```grad
 [NEW_DEVICE_ID], Gradientsystem [NEW_DEVICE_MODEL] , Gx,y,z = [NEW_GRADIENT_STRENGTH] mT/m
 win_low = 0, win_high = 0, win_algo = 0, win_dummy = 2;
 [NEW_RADIUS] m = R0, lnorm = 4? A(1,0) = B(1,1) = A(1,1) = 0;
```

### 2.3 替换系数值
需要替换所有27个系数值：
- A(n,0) 系数 (4个): z方向
- A(n,m) 系数 (11个): x方向  
- B(n,m) 系数 (12个): y方向

## 3. 常见设备参数示例

### 3.1 Siemens设备
```grad
# Siemens Prisma
 flagship 098, Gradientsystem Prisma_3T , Gx,y,z = 80 mT/m
 0.250 m = R0, lnorm = 4? A(1,0) = B(1,1) = A(1,1) = 0;

# Siemens Skyra  
 flagship 098, Gradientsystem Skyra_3T , Gx,y,z = 50 mT/m
 0.250 m = R0, lnorm = 4? A(1,0) = B(1,1) = A(1,1) = 0;
```

### 3.2 GE设备
```grad
# GE Discovery MR750
 flagship 098, Gradientsystem Discovery_MR750 , Gx,y,z = 50 mT/m
 0.250 m = R0, lnorm = 4? A(1,0) = B(1,1) = A(1,1) = 0;
```

### 3.3 Philips设备
```grad
# Philips Ingenia
 flagship 098, Gradientsystem Ingenia_3T , Gx,y,z = 45 mT/m
 0.250 m = R0, lnorm = 4? A(1,0) = B(1,1) = A(1,1) = 0;
```

## 4. 验证和测试

### 4.1 文件格式验证
```bash
# 检查文件格式是否正确
grep -E "^[[:space:]]*[0-9]+[[:space:]]+[AB]\([[:space:]]*[0-9]+,[[:space:]]*[0-9]+\)" new_device.grad
```

### 4.2 功能测试
```bash
# 使用新文件运行测试扫描
# 比较校正前后的图像质量
# 检查几何畸变校正效果
```

## 5. 注意事项

### 5.1 系数精度
- 保持系数的精度（通常6位小数）
- 不要随意修改系数的数量级
- 确保正负号正确

### 5.2 文件命名
- 建议使用设备型号作为文件名
- 例如: `prisma_coeff.grad`, `skyra_coeff.grad`

### 5.3 备份原始文件
```bash
# 备份原始文件
cp shunyi_coeff.grad shunyi_coeff.grad.backup
```

## 6. 故障排除

### 6.1 常见问题
1. **系数值过大/过小**: 检查单位换算
2. **校正效果不佳**: 验证设备参数准确性
3. **文件格式错误**: 检查空格和换行符

### 6.2 调试命令
```bash
# 检查文件语法
head -20 new_device.grad

# 验证系数数量
grep -c "^[[:space:]]*[0-9]" new_device.grad

# 检查数值范围
grep -o "[-]*[0-9]\+\.[0-9]\+" new_device.grad | sort -n
```

## 7. 自动化脚本示例

```bash
#!/bin/bash
# 自动适配脚本示例

DEVICE_NAME=$1
GRADIENT_STRENGTH=$2
DEVICE_RADIUS=$3

# 创建新文件
cp shunyi_coeff.grad ${DEVICE_NAME}_coeff.grad

# 替换设备参数
sed -i "s/daVinci_3T_Espresso/${DEVICE_NAME}/g" ${DEVICE_NAME}_coeff.grad
sed -i "s/45 mT\/m/${GRADIENT_STRENGTH} mT\/m/g" ${DEVICE_NAME}_coeff.grad
sed -i "s/0\.250 m/${DEVICE_RADIUS} m/g" ${DEVICE_NAME}_coeff.grad

echo "Created ${DEVICE_NAME}_coeff.grad"
echo "Please update the coefficients manually based on device specifications"
```

## 8. 参考资料

- FSL文档: https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/
- 梯度场校正原理: 相关MRI物理教材
- 设备制造商技术文档 