# AlohaMini GUI 使用说明

这个项目给 `lerobot_alohamini` 增加图形界面。原始机器人代码仍放在 `~/lerobot_alohamini`，GUI 建议放在 `~/alohamini_gui`。

支持 Ubuntu/Linux、Conda 和 LeRobot 0.6 AlohaMini。PC 与树莓派应使用同一版本的原始代码。

## 先准备这些信息

- 树莓派用户名，例如 `pi5`
- 树莓派 IP，例如 `192.168.8.71`
- 树莓派登录密码
- PC 和树莓派已连接到同一个局域网

下面命令中的 `192.168.8.71` 请换成自己机器人的 IP。

## 1. 拉取最新代码

第一次安装，在 PC 终端执行：

```bash
cd ~
git clone https://github.com/liyiteng/lerobot_alohamini.git
git clone https://github.com/annncatto/alohamini_gui.git
cd alohamini_gui
chmod +x ~/alohamini_gui/*.sh ~/alohamini_gui/scripts/*.sh ~/alohamini_gui/alohamini_ops/*.sh
```

已经下载过时，更新代码：

```bash
git -C ~/lerobot_alohamini status --short
git -C ~/lerobot_alohamini pull --ff-only
git -C ~/alohamini_gui pull --ff-only
```

如果 `status --short` 显示修改内容，先备份这些修改，不要强行覆盖。

树莓派也要更新原始代码：

```bash
ssh pi5@192.168.8.71
git -C ~/lerobot_alohamini status --short
git -C ~/lerobot_alohamini pull --ff-only
exit
```

如果树莓派没有 GitHub 密钥，可把仓库地址改为 HTTPS：

```bash
git -C ~/lerobot_alohamini remote set-url origin https://github.com/liyiteng/lerobot_alohamini.git
git -C ~/lerobot_alohamini pull --ff-only
```

## 2. 选择一种连接方式

### A. 本地长期使用：配置 SSH 密钥

适合自己的电脑和自己的机器人。配置一次，以后启动 Host、查看日志时不用重复输入密码。

在 PC 执行：

```bash
ssh-keygen -t ed25519
ssh-copy-id pi5@192.168.8.71
ssh pi5@192.168.8.71
```

第一次执行 `ssh-keygen` 时可以连续按 Enter 使用默认设置。最后一条命令能直接登录，说明密钥配置成功。

安装 GUI：

```bash
cd ~/alohamini_gui
./install_gui.sh \
  --repo ~/lerobot_alohamini \
  --pi pi5@192.168.8.71 \
  --conda-env lerobot_alohamini
```

启动：

```bash
cd ~/alohamini_gui
./start_gui.sh
```

### B. 临时调试：不配置 SSH 密钥

适合维修、出厂测试或临时连接客户机器人。不会向树莓派写入 PC 公钥。

先安装 GUI：

```bash
cd ~/alohamini_gui
./install_gui.sh \
  --repo ~/lerobot_alohamini \
  --pi pi5@192.168.8.71 \
  --conda-env lerobot_alohamini
```

安装过程中需要连接树莓派时，按提示输入密码。

启动 GUI：

```bash
cd ~/alohamini_gui
./start_gui.sh
```

进入 GUI 后：

1. 在连接页填写 Pi 用户和 IP，点击“应用连接配置”。
2. 点击“建立临时 SSH 会话”。
3. 在打开的终端中输入一次树莓派密码。
4. 调试完成后点击“断开临时 SSH 会话”。

密码不会保存。临时连接文件放在 PC 的 `/tmp`，默认最长保留 8 小时。

## 3. 第一次启动检查

在 PC 执行：

```bash
cd ~/alohamini_gui
./scripts/doctor.sh \
  --repo ~/lerobot_alohamini \
  --pi pi5@192.168.8.71 \
  --pi-repo /home/pi5/lerobot_alohamini \
  --mode gui
```

重点检查以下项目是否显示 `[OK]`：

- PC/Pi source commits match
- PC client supports multipart JPEG and legacy base64 observations
- Pi source uses multipart JPEG observations
- Pi multi-camera override uses MJPG
- Qt binding import works

如果 PC 与 Pi 提交不同，先停止遥操和采集，再更新两端代码。

## 4. 启动机器人和相机

1. 在连接页确认机器人型号、Pi 用户和 IP。
2. 启动 Pi Host。
3. 在相机页勾选需要的相机。
4. 点击“保存配置”。
5. 重启 Pi Host，使新的相机列表生效。
6. 点击打开相机。

相机可选名称：

```text
forward, backward, chest, wrist_left, wrist_right
```

新版使用 multipart JPEG 二进制图像传输。新版 PC 可以连接新版或旧版 Pi；旧版 PC 不能连接新版 Pi，因此推荐始终同步更新 PC 与 Pi。

## 5. 数据采集

采集前确认：

- Pi Host 正在运行
- 左右 Leader 已连接并完成校准
- `/dev/am_arm_leader_left` 和 `/dev/am_arm_leader_right` 存在
- 相机画面正常
- 数据集名称没有和旧数据集重复

在“数据”页填写：

- 数据集 `repo_id`，例如 `local/pick_test_01`
- 采集段数
- FPS
- 每段时长
- 重置时长
- 任务描述
- 保存根目录

点击“开始数据采集”。一段动作完成后可以保存当前段、废弃重录或停止采集。默认只保存到本地；需要上传 Hugging Face 时再勾选上传选项。

数据集默认保存在：

```text
~/alohamini_gui/datasets/lerobot/<repo_id>
```

GUI 采集兼容新版点号参数和旧参数，例如：

```text
--dataset.repo_id / --dataset
--dataset.root / --root
--robot.remote_ip / --remote_ip
--robot.robot_model / --robot_model
```

二进制图像由新版 `AlohaMiniClient` 解码后再写入数据集，不需要修改采集页面的使用方法。

## 6. 只安装命令行环境

不需要 GUI 和 Qt 时执行：

```bash
cd ~/alohamini_gui
./install_cli_env.sh \
  --repo ~/lerobot_alohamini \
  --pi pi5@192.168.8.71 \
  --conda-env lerobot_alohamini
```

这个命令不会替换原项目的 CLI 采集脚本。

## 7. 常见问题

### SSH 返回 255

检查 IP、用户名、网线或 Wi-Fi、树莓派 SSH 服务。只测试已知 IP：

```bash
ssh -v pi5@192.168.8.71
```

### 相机显示 `Frame is None`

先确认该相机已勾选并保存，然后重启 Pi Host。再运行 `doctor.sh`，确认 PC/Pi 版本一致且 Pi 使用 MJPG。

### 安装时补丁无法应用

不要手动覆盖原项目。执行：

```bash
cd ~/alohamini_gui
./scripts/patch_repo.sh --repo ~/lerobot_alohamini --target pc
./scripts/sync_pi.sh --pi pi5@192.168.8.71 --pi-repo /home/pi5/lerobot_alohamini
```

### 换电脑后路径还是旧用户名

指定原项目路径启动：

```bash
cd ~/alohamini_gui
./start_gui.sh --repo ~/lerobot_alohamini
```

主要配置文件位于：

```text
~/alohamini_gui/alohamini_ops/config.env
```
