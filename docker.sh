#!/bin/bash
#
# docker.sh - build / run / clean 這個 lab 的 Docker 環境
#
# 用法:
#   ./docker.sh run   [--mount <主機路徑>]...   建立並進入 container
#   ./docker.sh clean                           刪除 container 與 image
#   ./docker.sh rebuild                         刪除後重新 build
#
# 可用參數: --cont-name --hostname --image-name --username --mount
#
# 註: 本機 docker 跑在 WSL2 Linux engine，掛載 Windows 路徑 (C:/Users/...)
#     會自動轉成 Linux 看得到的 /mnt/c/Users/... 格式。

CONT_HOSTNAME="summer-training"
IMAGE_NAME="summer-training-lab1"
CONT_NAME="summer-training-container"
USERNAME="xuemanjiu"
MOUNTS=()

COMMAND=$1
shift

# 若 image 不存在就 build
build_image() {
    if docker image inspect "$IMAGE_NAME:latest" &>/dev/null; then
        echo "[info] Image '$IMAGE_NAME:latest' 已存在（要重建請先 ./docker.sh clean）"
    else
        echo "[info] Image 不存在，開始 build..."
        docker build -t "$IMAGE_NAME:latest" .
    fi
}

# 把 Windows 路徑 C:/... 或 C:\... 轉成 WSL 的 /mnt/c/...；其他路徑原樣/解析
to_wsl_path() {
    local p="$1"
    if [[ "$p" =~ ^([A-Za-z]):[\\/](.*)$ ]]; then
        local drive="${BASH_REMATCH[1],,}"      # 碟號轉小寫
        local rest="${BASH_REMATCH[2]//\\//}"    # 反斜線換斜線
        echo "/mnt/${drive}/${rest}"
    else
        realpath "$p" 2>/dev/null || echo "$p"
    fi
}

# 依 container 目前狀態決定：進入 / 啟動後進入 / 新建後進入
run_container() {
    local status
    status=$(docker inspect -f '{{.State.Status}}' "$CONT_NAME" 2>/dev/null || echo "not_existed")

    if [[ "$status" == "running" ]]; then
        echo "[info] Container '$CONT_NAME' 執行中，登入..."
        docker exec -it "$CONT_NAME" bash
    elif [[ "$status" == "exited" || "$status" == "created" ]]; then
        echo "[info] Container '$CONT_NAME' 已停止，啟動並登入..."
        docker start "$CONT_NAME"
        docker exec -it "$CONT_NAME" bash
    else
        echo "[info] 建立新 container '$CONT_NAME'..."
        local mount_args=()
        for path in "${MOUNTS[@]}"; do
            local host name
            host=$(to_wsl_path "$path")
            name=$(basename "$host")
            mount_args+=("-v" "${host}:/home/${USERNAME}/${name}")
            echo "-> mount: ${host} -> /home/${USERNAME}/${name}"
        done
        # -d 讓 container 保持在背景執行，之後可用 docker exec 重複進入
        docker run -it -d --name "$CONT_NAME" --hostname "$CONT_HOSTNAME" \
            "${mount_args[@]}" "${IMAGE_NAME}:latest" bash
        docker exec -it "$CONT_NAME" bash
    fi
}

# 刪除 container 與 image
clean() {
    echo "[info] 刪除 container: $CONT_NAME"
    docker rm -f "$CONT_NAME" 2>/dev/null
    echo "[info] 刪除 image: $IMAGE_NAME"
    docker rmi "$IMAGE_NAME:latest" 2>/dev/null
}

# 解析 CLI 參數
while [[ $# -gt 0 ]]; do
    case $1 in
        --cont-name)  CONT_NAME=$2;     shift 2 ;;
        --hostname)   CONT_HOSTNAME=$2; shift 2 ;;
        --image-name) IMAGE_NAME=$2;    shift 2 ;;
        --username)   USERNAME=$2;      shift 2 ;;
        --mount)      MOUNTS+=("$2");   shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

case $COMMAND in
    run)     build_image && run_container ;;
    clean)   clean ;;
    rebuild) clean && build_image ;;
    *)       echo "Usage: ./docker.sh [run|clean|rebuild] [--mount <path>] ..." ;;
esac
