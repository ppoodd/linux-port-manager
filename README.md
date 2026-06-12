# Linux 端口管理工具 (dk)

一个简洁高效的 Linux 端口管理脚本，支持端口开放、关闭、查看等功能。

## 功能特性

- ✅ 开放端口（支持批量）
- ✅ 关闭端口（支持批量）
- ✅ 查看已使用端口
- ✅ 查看空闲端口
- ✅ 支持多种防火墙：iptables / ufw / firewalld

## 安装使用

### 一键安装

```bash
# 下载脚本
curl -o /root/dk.sh https://raw.githubusercontent.com/你的用户名/linux-port-manager/main/dk.sh

# 创建快捷命令
ln -sf /root/dk.sh /usr/local/bin/dk
chmod +x /root/dk.sh

# 运行
dk
```

### 手动安装

```bash
# 克隆仓库
git clone https://github.com/你的用户名/linux-port-manager.git

# 进入目录
cd linux-port-manager

# 创建软链接
ln -sf dk.sh /usr/local/bin/dk
chmod +x dk.sh

# 运行
dk
```

## 使用说明

```
╔════════════════════════════╗
║    端口管理工具 v2.0      ║
╚════════════════════════════╝

请选择操作:
  1) 开放端口 (支持批量)
  2) 关闭端口 (支持批量)
  3) 查看使用端口
  4) 查看空闲端口
  5) 退出
```

### 批量端口格式

| 格式 | 示例 | 说明 |
|------|------|------|
| 单个端口 | `8080` | 开放/关闭单个端口 |
| 多个端口 | `80,443,8080` | 用逗号分隔 |
| 端口范围 | `8000-8010` | 连续端口范围 |

### 协议选择

- `tcp` - TCP 协议（默认）
- `udp` - UDP 协议
- `both` - 同时开放 TCP 和 UDP

## 系统要求

- Linux 系统
- root 权限
- 支持 iptables / ufw / firewalld

## 截图示例

### 查看已使用端口

```
=== 已使用端口 ===

协议   端口     进程               PID
----------------------------------------
tcp      22         sshd                 689
tcp      10022      1panel-core          294121
tcp      20086      sing-box             21132
udp      20088      sing-box             21132
```

### 查看空闲端口

```
=== 查看空闲端口 ===

空闲端口 = 没有进程监听的端口

请输入起始端口 [1]: 1
请输入结束端口 [1024]: 1024

空闲端口数: 1019  已使用端口数: 5
```

## License

MIT License

## 作者

欢迎提交 Issue 和 PR！