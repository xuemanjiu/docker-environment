# AOC 2026 Lab 0 — Docker Environment

為 AOC 2026 課程打包的統一實驗環境。透過 Docker 建立一致、可重現的開發環境，
內含 C/C++ 工具鏈、Verilator 與 SystemC，並提供 `docker.sh` 管理容器、
`eman` 驗證環境。

## 需求

- **Docker Desktop**（本設定實測於 WSL2 Linux engine）
- Windows 使用者：Docker Desktop 需啟用 **WSL Integration**
- 執行 `docker.sh` 需要 bash（Windows 可用 Git Bash 或 `bash docker.sh`）

## 檔案

| 檔案 | 用途 |
|------|------|
| `Dockerfile` | 多階段建置，產出 `aoc2026-env` image |
| `docker.sh`  | build / run / clean / rebuild 容器 |
| `eman`       | 在容器內驗證環境的 frontend script |

## 快速開始

在此資料夾下（Windows 用 PowerShell 或 Git Bash）：

```bash
# 建立 image 並進入容器（--mount 只需給主機路徑，會自動掛到 /home/<user>/<資料夾名>）
bash docker.sh run --mount "C:/Users/<你>/lab-0-tutorial"
```

進入容器後即可用 `eman` 驗證環境：

```bash
cd ~/docker-environment      # 若有把本資料夾一起掛入
./eman help
```

## docker.sh 用法

```text
./docker.sh run   [OPTIONS]   建立並進入容器（image 不存在會自動 build）
./docker.sh clean [OPTIONS]   刪除容器與 image
./docker.sh rebuild [OPTIONS] 刪除後重新 build
```

可用參數：

| 參數 | 說明 | 預設 |
|------|------|------|
| `--mount <path>`      | 掛載主機資料夾（可重複）；自動掛到 `/home/<user>/<資料夾名>` | — |
| `--image-name <name>` | image 名稱 | `aoc2026-env` |
| `--cont-name <name>`  | 容器名稱 | `aoc2026-container` |
| `--hostname <name>`   | 容器 hostname | `aoc2026` |
| `--username <name>`   | 容器內使用者 | `xuemanjiu` |

> **路徑說明**：本機 docker 跑在 WSL2 Linux engine，`docker.sh` 會自動把
> Windows 路徑 `C:/Users/...` 轉成 Linux 看得到的 `/mnt/c/Users/...`。
> 直接傳 `C:/...` 格式即可。

`run` 會依容器狀態自動處理：不存在就新建、已停止就啟動、執行中就直接登入。
容器以背景（`-d`）方式保持執行，離開後可再次 `./docker.sh run` 進入。

## eman 用法（在容器內執行）

```text
eman c-compiler-version    印 C 編譯器 (gcc/g++) 與 GNU Make 版本
eman c-compiler-example    編譯並執行 C/C++ 範例
eman check-verilator       印 Verilator 版本
eman verilator-example     編譯並執行 Verilator 範例
eman change-verilator <V>  切換 Verilator 版本（沒裝就從 source 編，例如 5.026）
eman help                  顯示說明
```

範例原始碼來自 [AOC Lab 0 Tutorial](https://gitlab.aislab.ee.ncku.edu.tw/aislab-internal/course/aoc/aoc2026/lab-0-tutorial)
repo，請 clone 後透過 `--mount` 掛入容器（預設 eman 會在 `~/lab-0-tutorial` 尋找）。

> `change-verilator` 會把新版編到 `~/.eman/verilator/<tag>` 並以 symlink
> 切換 `~/.local/bin/verilator`。若切換後 `verilator --version` 沒變，
> 執行 `export PATH="$HOME/.local/bin:$PATH"`（image 已預設將其加入 PATH）。

## 環境內容（image）

- 基底：**Ubuntu 26.04**，非 root 使用者 `xuemanjiu`（固定 UID/GID）
- 時區：Asia/Taipei，非互動安裝（適用 CI/CD）
- C/C++：`build-essential`（gcc、g++、make）
- Python：`python3` + `pip`（venv 於 `/opt/venv`）
- **Verilator**：由 source 編譯安裝
- **SystemC**：安裝於 `/opt/systemc`，已設好 `SYSTEMC_HOME`、`LD_LIBRARY_PATH`、
  `SYSTEMC_CXXFLAGS`、`SYSTEMC_LDFLAGS`

以多階段建置（base → common_pkg_provider → verilator_provider →
systemc_provider → release）分開編譯，release 階段僅彙整最終所需的產物與設定。
