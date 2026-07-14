# AlohaMini GUI

AlohaMini GUI 是 `lerobot_alohamini` 的图形界面辅助项目。机器人控制代码仍由原仓库提供，本项目负责安装检查、连接配置、相机预览、遥操作、校准入口、数据采集和部署入口。

支持 Ubuntu/Linux、Conda 和 LeRobot 0.6 AlohaMini。PC 与树莓派应使用同一版本的 `lerobot_alohamini`。

## 1. 准备

需要知道：

- 树莓派用户名，出厂系统通常为 `pi5`
- 树莓派 IP
- 树莓派登录密码
- PC 和树莓派处于同一局域网

先设置本次终端使用的变量。把 `192.168.x.x` 换成机器人实际 IP：

```bash
PI_USER="pi5"
PI_IP="192.168.x.x"
```

## 2. 下载代码

在 PC 执行：

```bash
cd ~
git clone https://github.com/liyiteng/lerobot_alohamini.git
git clone https://github.com/annncatto/alohamini_gui.git
cd ~/alohamini_gui
chmod +x *.sh scripts/*.sh alohamini_ops/*.sh
```

树莓派也需要原始仓库：

```bash
ssh "$PI_USER@$PI_IP"
git clone https://github.com/liyiteng/lerobot_alohamini.git ~/lerobot_alohamini
exit
```

如果树莓派已经有该目录，不要再次克隆。

## 3. 配置 SSH

### 长期使用

自己的电脑和机器人建议配置 SSH 密钥：

```bash
ssh-keygen -t ed25519
ssh-copy-id "$PI_USER@$PI_IP"
ssh "$PI_USER@$PI_IP"
```

最后一条命令能直接登录，说明配置完成。

### 临时调试

维修或出厂测试时可以不写入 SSH 密钥。安装时按提示输入密码；启动 GUI 后，在连接页点击“建立临时 SSH 会话”，再输入一次密码。密码不会保存，临时会话默认最多保留 8 小时。

## 4. 安装 GUI

在 PC 执行：

```bash
cd ~/alohamini_gui
./install_gui.sh \
  --repo ~/lerobot_alohamini \
  --pi "$PI_USER@$PI_IP" \
  --conda-env lerobot_alohamini
```

安装器会：

- 复用已有的 `lerobot_alohamini` Conda 环境，缺失时再创建
- 安装原项目依赖和 Qt
- 生成本机 `alohamini_ops/config.env`
- 检查 PC、树莓派代码和相机兼容层
- 保留原项目 CLI 的默认行为

`config.env` 含本机路径和机器人 IP，已被 Git 忽略，不会上传到 GitHub。

## 5. 第一次启动和遥操作

启动 GUI：

```bash
cd ~/alohamini_gui
./start_gui.sh
```

按顺序操作：

1. 打开“连接”，确认 Pi 用户、Pi IP 和机器人型号。
2. 点击“应用连接配置”；长期保存可点击“保存连接配置”。
3. 临时调试模式先点击“建立临时 SSH 会话”。
4. 点击“启动树莓派 Host”，等待状态显示“运行中”。
5. 打开“相机”，选择相机并点击“保存配置”。
6. 相机配置发生变化时，停止并重新启动 Host。
7. 点击“打开相机”，确认所选画面正常，再关闭单独相机预览。
8. 确认左右 Leader 已供电、校准，并存在以下设备：

```bash
ls -l /dev/am_arm_leader_left /dev/am_arm_leader_right
```

9. 回到“连接”，点击“连接 GUI 遥操”。

连接前 GUI 会检查当前 Pi 的 `5555` 和 `5556` 端口。失败时先检查 Host、IP 和网络，不会扫描其他地址。

## 6. 相机配置

可用名称：

```text
forward, backward, chest, wrist_left, wrist_right
```

保存相机选项后必须重启 Host。`/dev/video*` 编号可能随插拔变化，正式部署应由树莓派 udev 规则提供稳定的 `/dev/am_camera_*` 名称。

新版使用 multipart JPEG；新版 PC 可兼容新版和旧版树莓派图像流，旧版 PC 不能接收新版树莓派图像流。

## 7. 数据采集

采集前确认：

- Host 正在运行，相机画面正常
- 左右 Leader 已连接并校准
- 数据集名称没有与已有目录重复
- 磁盘空间充足

在“数据”页填写 `repo_id`、段数、FPS、时长、任务描述和保存目录，然后开始采集。默认只保存到本地；需要上传时再启用 Hugging Face 上传。

采集帧率不足时，可先在 `alohamini_ops/config.env` 设置 `ALOHAMINI_RECORD_PREVIEW_FPS=0` 做对照测试。该设置只关闭 GUI 预览，不会关闭数据集中的相机画面。

默认数据目录：

```text
~/alohamini_gui/datasets/lerobot/<repo_id>
```

## 8. 检查环境

```bash
cd ~/alohamini_gui
./scripts/doctor.sh \
  --repo ~/lerobot_alohamini \
  --pi "$PI_USER@$PI_IP" \
  --pi-repo "/home/$PI_USER/lerobot_alohamini" \
  --mode gui
```

PC/Pi commit、Qt、AlohaMini import、相机协议和兼容层应显示 `[OK]`。临时调试模式需要先建立临时 SSH 会话。

## 9. 只安装 CLI 环境

不使用 GUI 时执行：

```bash
cd ~/alohamini_gui
./install_cli_env.sh \
  --repo ~/lerobot_alohamini \
  --pi "$PI_USER@$PI_IP" \
  --conda-env lerobot_alohamini
```

该模式不安装 Qt，也不修改原项目源文件。

## 10. 更新

停止遥操作、采集和 Host，再检查并更新两端：

```bash
git -C ~/lerobot_alohamini status --short
git -C ~/alohamini_gui status --short
git -C ~/lerobot_alohamini pull --ff-only
git -C ~/alohamini_gui pull --ff-only
ssh "$PI_USER@$PI_IP" 'git -C ~/lerobot_alohamini status --short && git -C ~/lerobot_alohamini pull --ff-only'
```

如果 `status --short` 有输出，先确认并备份自己的修改。更新后重新运行 `install_gui.sh`，让安装器复查兼容性。

## 11. 常见问题

### SSH 返回 255

检查 Pi 用户、IP、网络和树莓派 SSH 服务：

```bash
ip -br addr
ip route
ssh -v "$PI_USER@$PI_IP"
```

不使用密钥时，先在 GUI 建立临时 SSH 会话。

### 遥操作连接超时

通常是 Host 未运行、Pi IP 填错、PC 与 Pi 不在同一网络，或防火墙阻止 `5555/5556`。先在 GUI 刷新状态并查看 Host 日志，再重新启动 Host。

### 相机显示 `Frame is None`

确认相机已选择并保存，然后重启 Host。再检查 `/dev/am_camera_*`、PC/Pi 版本和 MJPG 配置。

### 换电脑后仍显示旧路径

```bash
cd ~/alohamini_gui
./start_gui.sh --repo ~/lerobot_alohamini
```

启动器会更新当前机器的仓库、Conda、数据集和校准路径。

### 兼容修改无法应用

不要覆盖原项目。先运行：

```bash
./scripts/doctor.sh --repo ~/lerobot_alohamini --pi "$PI_USER@$PI_IP" --mode gui
./scripts/patch_repo.sh --repo ~/lerobot_alohamini --target pc
./scripts/sync_pi.sh --pi "$PI_USER@$PI_IP" --pi-repo "/home/$PI_USER/lerobot_alohamini"
```

仍失败时记录原项目 commit 和完整错误信息。兼容工具会先检查现有代码，不会强行覆盖无法识别的版本。
