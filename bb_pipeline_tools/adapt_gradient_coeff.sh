#!/bin/bash

# 3T MRI梯度系数文件自动适配脚本
# 用法: ./adapt_gradient_coeff.sh <设备名称> <梯度强度> <参考半径> [系数文件路径]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 默认参数
DEFAULT_SOURCE_FILE="shunyi_coeff.grad"
DEFAULT_GRADIENT_STRENGTH="45"
DEFAULT_RADIUS="0.250"

# 帮助信息
show_help() {
    echo "3T MRI梯度系数文件自动适配脚本"
    echo ""
    echo "用法: $0 <设备名称> [梯度强度] [参考半径] [源文件路径]"
    echo ""
    echo "参数:"
    echo "  设备名称      目标MRI设备名称 (必需)"
    echo "  梯度强度     梯度强度，单位mT/m (默认: $DEFAULT_GRADIENT_STRENGTH)"
    echo "  参考半径     参考半径，单位m (默认: $DEFAULT_RADIUS)"
    echo "  源文件路径   源梯度系数文件路径 (默认: $DEFAULT_SOURCE_FILE)"
    echo ""
    echo "示例:"
    echo "  $0 Prisma_3T 80 0.250"
    echo "  $0 Skyra_3T 50 0.250 shunyi_coeff.grad"
    echo ""
    echo "注意事项:"
    echo "  - 脚本会创建新的梯度系数文件"
    echo "  - 系数值需要手动更新"
    echo "  - 建议备份原始文件"
}

# 检查参数
if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# 解析参数
DEVICE_NAME="$1"
GRADIENT_STRENGTH="${2:-$DEFAULT_GRADIENT_STRENGTH}"
DEVICE_RADIUS="${3:-$DEFAULT_RADIUS}"
SOURCE_FILE="${4:-$DEFAULT_SOURCE_FILE}"

# 验证源文件存在
if [[ ! -f "$SOURCE_FILE" ]]; then
    echo -e "${RED}错误: 源文件 '$SOURCE_FILE' 不存在${NC}"
    exit 1
fi

# 验证参数
if [[ ! "$GRADIENT_STRENGTH" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo -e "${RED}错误: 梯度强度必须是数字${NC}"
    exit 1
fi

if [[ ! "$DEVICE_RADIUS" =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}错误: 参考半径格式不正确，应为 x.xxx${NC}"
    exit 1
fi

# 生成输出文件名
OUTPUT_FILE="${DEVICE_NAME}_coeff.grad"
BACKUP_FILE="${SOURCE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

echo -e "${GREEN}开始适配梯度系数文件...${NC}"
echo "设备名称: $DEVICE_NAME"
echo "梯度强度: $GRADIENT_STRENGTH mT/m"
echo "参考半径: $DEVICE_RADIUS m"
echo "源文件: $SOURCE_FILE"
echo "输出文件: $OUTPUT_FILE"
echo ""

# 备份原始文件
if [[ ! -f "$BACKUP_FILE" ]]; then
    echo -e "${YELLOW}备份原始文件到: $BACKUP_FILE${NC}"
    cp "$SOURCE_FILE" "$BACKUP_FILE"
fi

# 创建新文件
echo -e "${GREEN}创建新的梯度系数文件...${NC}"
cp "$SOURCE_FILE" "$OUTPUT_FILE"

# 替换设备参数
echo "更新设备参数..."
sed -i.bak "s/daVinci_3T_Espresso/${DEVICE_NAME}/g" "$OUTPUT_FILE"
sed -i.bak "s/45 mT\/m/${GRADIENT_STRENGTH} mT\/m/g" "$OUTPUT_FILE"
sed -i.bak "s/0\.250 m/${DEVICE_RADIUS} m/g" "$OUTPUT_FILE"

# 更新文件头部信息
CURRENT_DATE=$(date +%m/%d/%y)
sed -i.bak "s|AS098_3T\.grad (Design per 11/11/08)|${DEVICE_NAME}.grad (Design per ${CURRENT_DATE})|g" "$OUTPUT_FILE"
sed -i.bak "s/R\.Kimmlingen/Adapted from original/g" "$OUTPUT_FILE"

# 清理临时文件
rm -f "$OUTPUT_FILE.bak"

# 验证文件
echo ""
echo -e "${GREEN}验证文件格式...${NC}"

# 检查系数数量
COEFF_COUNT=$(grep -c "^[[:space:]]*[0-9]" "$OUTPUT_FILE")
echo "检测到 $COEFF_COUNT 个系数"

# 检查文件结构
if grep -q "Expansion in.*Spherical.*Harmonics" "$OUTPUT_FILE"; then
    echo -e "${GREEN}✓ 文件结构正确${NC}"
else
    echo -e "${RED}✗ 文件结构可能有问题${NC}"
fi

# 显示文件预览
echo ""
echo -e "${YELLOW}文件预览 (前20行):${NC}"
echo "=================================="
head -20 "$OUTPUT_FILE"
echo "=================================="

echo ""
echo -e "${GREEN}✓ 适配完成!${NC}"
echo ""
echo -e "${YELLOW}重要提醒:${NC}"
echo "1. 文件 '$OUTPUT_FILE' 已创建"
echo "2. 原始文件已备份到 '$BACKUP_FILE'"
echo "3. 请手动更新系数值以匹配目标设备"
echo "4. 建议进行功能测试验证校正效果"
echo ""
echo "下一步操作:"
echo "- 从设备制造商获取准确的系数值"
echo "- 替换文件中的系数"
echo "- 运行测试扫描验证校正效果" 