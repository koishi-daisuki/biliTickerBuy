#!/bin/bash

# biliTickerBuy Docker 构建和运行脚本
# 使用方法: ./docker-run.sh [选项]

set -e  # 遇到错误立即退出

# 默认配置
IMAGE_NAME="bilitickerbuy"
IMAGE_TAG="latest"
CONTAINER_NAME="bilitickerbuy-container"
DEFAULT_PORT=7860
HOST_PORT=""
CONTAINER_PORT=""
PORT_RANGE=""
NETWORK_MODE=""
REBUILD=false
DETACH=false
REMOVE_EXISTING=false
SHOW_LOGS=false

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印帮助信息
show_help() {
    echo "biliTickerBuy Docker 构建和运行脚本"
    echo ""
    echo "使用方法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help              显示此帮助信息"
    echo "  -b, --build             重新构建镜像"
    echo "  -p, --port PORT         指定主机端口 (默认: 7860)"
    echo "  -r, --port-range START-END  端口范围映射 (例如: 7860-7900)"
    echo "  -n, --network host      使用主机网络模式"
    echo "  -d, --detach            后台运行容器"
    echo "  -l, --logs              显示容器日志"
    echo "  --remove                删除已存在的同名容器"
    echo "  --name NAME             指定容器名称 (默认: bilitickerbuy-container)"
    echo "  --tag TAG               指定镜像标签 (默认: latest)"
    echo ""
    echo "示例:"
    echo "  $0                      # 使用默认设置构建并运行"
    echo "  $0 -b -p 8080          # 重新构建并映射到8080端口"
    echo "  $0 -r 7860-7900        # 映射端口范围7860-7900"
    echo "  $0 -n host -d          # 使用主机网络后台运行"
    echo "  $0 --remove -l         # 删除旧容器并显示日志"
}

# 打印彩色信息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 Docker 是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装或不在 PATH 中"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker 服务未运行，请启动 Docker"
        exit 1
    fi
}

# 检查 Dockerfile 是否存在
check_dockerfile() {
    if [ ! -f "Dockerfile" ]; then
        print_error "当前目录下未找到 Dockerfile"
        exit 1
    fi
}

# 构建 Docker 镜像
build_image() {
    print_info "开始构建 Docker 镜像: ${IMAGE_NAME}:${IMAGE_TAG}"
    
    if docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .; then
        print_success "镜像构建完成: ${IMAGE_NAME}:${IMAGE_TAG}"
    else
        print_error "镜像构建失败"
        exit 1
    fi
}

# 检查镜像是否存在
check_image_exists() {
    if docker image inspect "${IMAGE_NAME}:${IMAGE_TAG}" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# 停止并删除已存在的容器
remove_existing_container() {
    if docker ps -a --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        print_warning "发现已存在的容器: ${CONTAINER_NAME}"
        
        if [ "$REMOVE_EXISTING" = true ]; then
            print_info "正在停止并删除已存在的容器..."
            docker stop "${CONTAINER_NAME}" &> /dev/null || true
            docker rm "${CONTAINER_NAME}" &> /dev/null || true
            print_success "已删除旧容器"
        else
            print_error "容器 ${CONTAINER_NAME} 已存在，使用 --remove 选项删除或更改容器名称"
            exit 1
        fi
    fi
}

# 运行容器
run_container() {
    local docker_cmd="docker run"
    
    # 添加容器名称
    docker_cmd+=" --name ${CONTAINER_NAME}"
    
    # 后台运行
    if [ "$DETACH" = true ]; then
        docker_cmd+=" -d"
    fi
    
    # 网络模式
    if [ -n "$NETWORK_MODE" ]; then
        docker_cmd+=" --network ${NETWORK_MODE}"
        print_info "使用网络模式: ${NETWORK_MODE}"
    else
        # 端口映射
        if [ -n "$PORT_RANGE" ]; then
            docker_cmd+=" -p ${PORT_RANGE}:${PORT_RANGE}"
            print_info "映射端口范围: ${PORT_RANGE}"
        elif [ -n "$HOST_PORT" ] && [ -n "$CONTAINER_PORT" ]; then
            docker_cmd+=" -p ${HOST_PORT}:${CONTAINER_PORT}"
            print_info "映射端口: ${HOST_PORT} -> ${CONTAINER_PORT}"
        else
            docker_cmd+=" -p ${DEFAULT_PORT}:${DEFAULT_PORT}"
            print_info "映射默认端口: ${DEFAULT_PORT}"
        fi
    fi
    
    # 添加镜像名称
    docker_cmd+=" ${IMAGE_NAME}:${IMAGE_TAG}"
    
    print_info "运行容器命令: ${docker_cmd}"
    
    if eval "$docker_cmd"; then
        print_success "容器启动成功: ${CONTAINER_NAME}"
        
        if [ "$NETWORK_MODE" = "host" ]; then
            print_info "应用访问地址: http://localhost:${DEFAULT_PORT}"
        elif [ -n "$HOST_PORT" ]; then
            print_info "应用访问地址: http://localhost:${HOST_PORT}"
        else
            print_info "应用访问地址: http://localhost:${DEFAULT_PORT}"
        fi
        
        if [ "$DETACH" = true ]; then
            print_info "容器在后台运行，使用 'docker logs ${CONTAINER_NAME}' 查看日志"
            print_info "使用 'docker stop ${CONTAINER_NAME}' 停止容器"
        fi
    else
        print_error "容器启动失败"
        exit 1
    fi
}

# 显示容器日志
show_logs() {
    if docker ps -a --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        print_info "显示容器日志: ${CONTAINER_NAME}"
        docker logs -f "${CONTAINER_NAME}"
    else
        print_warning "容器 ${CONTAINER_NAME} 不存在"
    fi
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -b|--build)
            REBUILD=true
            shift
            ;;
        -p|--port)
            HOST_PORT="$2"
            CONTAINER_PORT="$2"
            shift 2
            ;;
        -r|--port-range)
            PORT_RANGE="$2"
            shift 2
            ;;
        -n|--network)
            NETWORK_MODE="$2"
            shift 2
            ;;
        -d|--detach)
            DETACH=true
            shift
            ;;
        -l|--logs)
            SHOW_LOGS=true
            shift
            ;;
        --remove)
            REMOVE_EXISTING=true
            shift
            ;;
        --name)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        --tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        *)
            print_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 主执行流程
main() {
    print_info "biliTickerBuy Docker 管理脚本启动"
    
    # 检查环境
    check_docker
    check_dockerfile
    
    # 如果只是显示日志
    if [ "$SHOW_LOGS" = true ] && [ "$REBUILD" = false ]; then
        show_logs
        exit 0
    fi
    
    # 构建镜像
    if [ "$REBUILD" = true ] || ! check_image_exists; then
        if [ "$REBUILD" = false ]; then
            print_info "镜像 ${IMAGE_NAME}:${IMAGE_TAG} 不存在，开始构建..."
        fi
        build_image
    else
        print_info "使用已存在的镜像: ${IMAGE_NAME}:${IMAGE_TAG}"
    fi
    
    # 处理已存在的容器
    remove_existing_container
    
    # 运行容器
    run_container
    
    # 显示日志
    if [ "$SHOW_LOGS" = true ]; then
        echo ""
        show_logs
    fi
}

# 执行主函数
main "$@"
