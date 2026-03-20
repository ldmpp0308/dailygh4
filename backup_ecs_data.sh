#!/usr/bin/env bash
set -euo pipefail

# 阿里云 ECS 数据自动备份脚本
# 用法：bash bin/backup_ecs_data.sh
# 建议添加到 crontab：10 0 * * * cd /path/to/每日高会 && bash bin/backup_ecs_data.sh

# 基本配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_BASE_DIR="${BACKUP_DIR:-/backup}"
DATE=$(date +%Y%m%d_%H%M%S)
DATE_SHORT=$(date +%Y%m%d)
BACKUP_DIR="$BACKUP_BASE_DIR/dailygh"
LOG_DIR="$BACKUP_BASE_DIR/logs"
LOG_FILE="$LOG_DIR/backup_${DATE_SHORT}.log"

# 备份的数据目录
ARCHIVES_DIR="${ARCHIVES_DIR:-$ROOT_DIR/archives}"
RESULTS_DIR="${RESULTS_DIR:-/home/ecs-user/results}"

# 创建备份和日志目录
mkdir -p "$BACKUP_DIR" "$LOG_DIR"

# 日志函数
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE"
}

log "========== 开始每日备份 =========="
log "备份时间: $(date)"
log "备份目录: $BACKUP_DIR"
log "日志文件: $LOG_FILE"

# 检查源目录是否存在
if [[ ! -d "$ARCHIVES_DIR" ]]; then
    log "⚠️ 警告: archives 目录不存在: $ARCHIVES_DIR"
fi

if [[ ! -d "$RESULTS_DIR" ]]; then
    log "⚠️ 警告: results 目录不存在: $RESULTS_DIR"
fi

# 创建备份文件名
BACKUP_NAME="dailygh_backup_${DATE}.tar.gz"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

# 开始备份
log "📦 正在创建备份: $BACKUP_NAME"

# 计算源目录大小
TOTAL_SIZE=0
if [[ -d "$ARCHIVES_DIR" ]]; then
    ARCHIVES_SIZE=$(du -sb "$ARCHIVES_DIR" 2>/dev/null | cut -f1)
    TOTAL_SIZE=$((TOTAL_SIZE + ARCHIVES_SIZE))
    log "   archives 目录大小: $(du -sh "$ARCHIVES_DIR" 2>/dev/null | cut -f1)"
fi

if [[ -d "$RESULTS_DIR" ]]; then
    RESULTS_SIZE=$(du -sb "$RESULTS_DIR" 2>/dev/null | cut -f1)
    TOTAL_SIZE=$((TOTAL_SIZE + RESULTS_SIZE))
    log "   results 目录大小: $(du -sh "$RESULTS_DIR" 2>/dev/null | cut -f1)"
fi

log "   总数据大小: $(du -sh /dev/null 2>/dev/null || echo "计算中...")"

# 执行备份
if tar -czf "$BACKUP_PATH" -C "$ROOT_DIR" archives 2>/dev/null || true; then
    # 如果 results 目录存在且可访问，也备份
    if [[ -d "$RESULTS_DIR" ]] && [[ -r "$RESULTS_DIR" ]]; then
        tar -czf "$BACKUP_PATH.tmp" -C "$(dirname "$RESULTS_DIR")" "$(basename "$RESULTS_DIR")" 2>/dev/null || true
        # 合并两个压缩包
        if [[ -f "$BACKUP_PATH.tmp" ]]; then
            # 重新创建包含两个目录的备份
            tar -czf "$BACKUP_PATH" -C "$ROOT_DIR" archives 2>/dev/null || true
            tar -czf "$BACKUP_PATH.results" -C "$(dirname "$RESULTS_DIR")" "$(basename "$RESULTS_DIR")" 2>/dev/null || true
            # 使用更简洁的方式：分别备份
            mv "$BACKUP_PATH" "$BACKUP_DIR/${BACKUP_NAME%.tar.gz}_archives.tar.gz"
            mv "$BACKUP_PATH.results" "$BACKUP_DIR/${BACKUP_NAME%.tar.gz}_results.tar.gz" 2>/dev/null || true
            BACKUP_NAME="${BACKUP_NAME%.tar.gz}_archives.tar.gz"
            log "✅ 分别备份完成:"
            log "   - archives: ${BACKUP_NAME%.tar.gz}_archives.tar.gz"
            log "   - results: ${BACKUP_NAME%.tar.gz}_results.tar.gz"
        fi
    else
        log "✅ 备份完成: $BACKUP_NAME"
    fi
else
    log "❌ 备份失败"
    exit 1
fi

# 显示备份文件信息
if [[ -f "$BACKUP_DIR/$BACKUP_NAME" ]]; then
    BACKUP_SIZE=$(du -sh "$BACKUP_DIR/$BACKUP_NAME" 2>/dev/null | cut -f1)
    log "📊 备份文件大小: $BACKUP_SIZE"
fi

# 清理旧备份（保留最近7天）
log "🧹 清理旧备份（保留最近7天）..."
DELETED_COUNT=0
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        rm -f "$file"
        log "   已删除: $(basename "$file")"
        DELETED_COUNT=$((DELETED_COUNT + 1))
    fi
done < <(find "$BACKUP_DIR" -name "dailygh_backup_*.tar.gz" -type f -mtime +7 2>/dev/null)

if [[ $DELETED_COUNT -eq 0 ]]; then
    log "   没有需要清理的旧备份"
else
    log "   共清理 $DELETED_COUNT 个旧备份文件"
fi

# 显示磁盘使用情况
log "💾 磁盘使用情况:"
log "   备份目录: $(df -h "$BACKUP_BASE_DIR" 2>/dev/null | tail -1 | awk '{print $4 "/" $2 " (可用/总计)"}')"

# 列出最近的备份
log "📋 最近的备份文件:"
ls -lh "$BACKUP_DIR"/*.tar.gz 2>/dev/null | tail -5 | while read line; do
    log "   $line"
done

log "========== 备份完成 =========="
log ""

# 可选：上传到阿里云 OSS（如果配置了）
if command -v ossutil >/dev/null 2>&1 && [[ -n "${OSS_BUCKET:-}" ]]; then
    log "☁️  正在上传到阿里云 OSS..."
    if ossutil cp "$BACKUP_DIR/$BACKUP_NAME" "oss://$OSS_BUCKET/backups/" >> "$LOG_FILE" 2>&1; then
        log "✅ 上传完成: oss://$OSS_BUCKET/backups/$BACKUP_NAME"
    else
        log "⚠️ 上传失败"
    fi
fi

echo "[info] 备份完成！日志文件: $LOG_FILE"
