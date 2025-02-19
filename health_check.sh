#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# 图标定义
CHECK_MARK="\xE2\x9C\x94"
CROSS_MARK="\xE2\x9C\x98"
WARNING_MARK="⚠️"

# 日志文件
LOG_FILE="health_check.log"

# 时间戳
timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# 日志函数
log() {
    echo "$(timestamp) - $1" >> $LOG_FILE
    echo -e "$1"
}

# 检查Docker容器状态
check_docker_containers() {
    log "${BLUE}${BOLD}=== 检查 Docker 容器状态 ===${NC}"
    
    local containers=("ten_agent_dev" "ten_agent_demo" "ten_agent_playground")
    local all_healthy=true
    
    for container in "${containers[@]}"; do
        local status=$(docker ps -f name=$container --format "{{.Status}}" 2>/dev/null)
        if [ -n "$status" ] && [[ $status == *"Up"* ]]; then
            log "${GREEN}${CHECK_MARK} $container: 运行正常 - $status${NC}"
        else
            log "${RED}${CROSS_MARK} $container: 未运行或状态异常${NC}"
            all_healthy=false
        fi
    done
    
    return $all_healthy
}

# 检查端口状态
check_ports() {
    log "${BLUE}${BOLD}=== 检查端口状态 ===${NC}"
    
    local ports=(3000 3002 8080 49483)
    local all_ports_open=true
    
    for port in "${ports[@]}"; do
        if netstat -tuln | grep ":$port " > /dev/null; then
            log "${GREEN}${CHECK_MARK} 端口 $port: 正在监听${NC}"
        else
            log "${RED}${CROSS_MARK} 端口 $port: 未监听${NC}"
            all_ports_open=false
        fi
    done
    
    return $all_ports_open
}

# 检查系统资源
check_system_resources() {
    log "${BLUE}${BOLD}=== 检查系统资源 ===${NC}"
    
    # CPU 使用率
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1)
    if [ $cpu_usage -lt 80 ]; then
        log "${GREEN}${CHECK_MARK} CPU 使用率: $cpu_usage%${NC}"
    else
        log "${RED}${WARNING_MARK} CPU 使用率过高: $cpu_usage%${NC}"
    fi
    
    # 内存使用情况
    local mem_info=$(free -m | grep Mem)
    local mem_total=$(echo $mem_info | awk '{print $2}')
    local mem_used=$(echo $mem_info | awk '{print $3}')
    local mem_usage=$((mem_used * 100 / mem_total))
    
    if [ $mem_usage -lt 80 ]; then
        log "${GREEN}${CHECK_MARK} 内存使用率: $mem_usage%${NC}"
    else
        log "${RED}${WARNING_MARK} 内存使用率过高: $mem_usage%${NC}"
    fi
    
    # 磁盘使用情况
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | cut -d'%' -f1)
    if [ $disk_usage -lt 80 ]; then
        log "${GREEN}${CHECK_MARK} 磁盘使用率: $disk_usage%${NC}"
    else
        log "${RED}${WARNING_MARK} 磁盘使用率过高: $disk_usage%${NC}"
    fi
}

# 检查容器资源使用
check_container_resources() {
    log "${BLUE}${BOLD}=== 检查容器资源使用 ===${NC}"
    
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
}

# 检查服务可用性
check_service_availability() {
    log "${BLUE}${BOLD}=== 检查服务可用性 ===${NC}"
    
    local endpoints=(
        "http://localhost:3000"
        "http://localhost:3002"
        "http://localhost:8080"
    )
    
    for endpoint in "${endpoints[@]}"; do
        local start_time=$(date +%s%N)
        local http_code=$(curl -s -o /dev/null -w "%{http_code}" $endpoint)
        local end_time=$(date +%s%N)
        local duration=$(echo "scale=2; ($end_time - $start_time)/1000000" | bc)
        
        if [ "$http_code" -eq 200 ]; then
            log "${GREEN}${CHECK_MARK} $endpoint 响应正常 (${duration}ms)${NC}"
        else
            log "${RED}${CROSS_MARK} $endpoint 响应异常 (HTTP $http_code)${NC}"
        fi
    done
}

# 检查日志错误
check_logs() {
    log "${BLUE}${BOLD}=== 检查容器日志 ===${NC}"
    
    local containers=("ten_agent_dev" "ten_agent_demo" "ten_agent_playground")
    
    for container in "${containers[@]}"; do
        local error_count=$(docker logs $container --since 5m 2>&1 | grep -i "error" | wc -l)
        if [ $error_count -eq 0 ]; then
            log "${GREEN}${CHECK_MARK} $container: 最近5分钟无错误日志${NC}"
        else
            log "${YELLOW}${WARNING_MARK} $container: 最近5分钟发现 $error_count 条错误日志${NC}"
        fi
    done
}

# 主函数
main() {
    log "${BOLD}开始健康检查 - $(timestamp)${NC}"
    echo "----------------------------------------"
    
    check_docker_containers
    echo "----------------------------------------"
    
    check_ports
    echo "----------------------------------------"
    
    check_system_resources
    echo "----------------------------------------"
    
    check_container_resources
    echo "----------------------------------------"
    
    check_service_availability
    echo "----------------------------------------"
    
    check_logs
    echo "----------------------------------------"
    
    log "${BOLD}健康检查完成 - $(timestamp)${NC}"
}

# 执行主函数
main 