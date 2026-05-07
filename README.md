# Windows Update Disabler (WUD)

> 彻底关闭 Windows 10/11 自动更新的开源工具

## ✨ 特性

- **一键执行** — 复制一行命令到 PowerShell 即可完成所有操作
- **全方位禁用** — 从服务、注册表、组策略、任务计划四个维度彻底关闭更新
- **防复活机制** — 堵死微软埋设的所有自启动开关，更新不会再自动恢复
- **可逆操作** — 支持一键恢复 Windows 更新功能
- **状态检查** — 随时查看当前更新服务的状态
- **分步执行** — 高级用户可选择单独执行某个步骤
- **修复模式** — 专门修复"禁用了但更新又复活"的问题
- **零依赖** — 纯 Batch + PowerShell，无需安装任何额外软件
- **适配 Win10/11** — 完美兼容 Windows 10 和 Windows 11

## 🚀 一键使用

打开 **PowerShell（管理员）**，复制粘贴以下命令：

```powershell
irm https://raw.githubusercontent.com/dawncopper/WUD/main/WUD.ps1 | iex
```

## 📋 功能菜单

| 选项 | 功能 | 说明 |
|------|------|------|
| 1 | 一键彻底关闭 | 推荐！执行全部4步操作 |
| 2 | 分步执行 | 高级用户可逐步操作 |
| 3 | 恢复更新 | 一键恢复所有更新功能 |
| 4 | 检查状态 | 查看当前更新服务状态 |
| 5 | 仅禁用服务 | 只禁用服务+注册表 |
| 6 | 仅配置组策略 | 只配置组策略（仅Pro/Enterprise） |
| 7 | 仅清理任务计划 | 只清理后台任务 |
| 8 | 修复复活问题 | 专门修复更新自动恢复的问题 |

## 🔧 四步彻底关闭原理

### 第一步：服务禁用
- 停止并禁用 `Windows Update` 服务
- 停止并禁用 `UsoSvc` 服务
- 停止并禁用 `Windows Update Medic Service`
- 停止并禁用 `Update Orchestrator Service`
- 将所有服务的恢复操作设为"无操作"

### 第二步：注册表修改
- 将相关服务的 `Start` 值改为 `4`（禁用）
- 重置 `FailureActions`（禁用自动恢复机制）

### 第三步：组策略配置
- 禁用自动更新
- 禁用更新通知
- 禁用 Windows Update 功能访问
- 禁用"重启以更新"提示

### 第四步：任务计划清理
- 禁用 `Microsoft\Windows\WindowsUpdate` 下所有计划任务

## 📁 手动使用

如果无法使用一键命令，可以手动下载 `WUD.cmd` 文件：

1. 下载 [WUD.cmd](WUD.cmd)
2. 右键 → **以管理员身份运行**

## ⚠️ 注意事项

- 本工具会禁用所有 Windows 更新，包括安全更新
- 建议每月手动检查一次安全补丁
- 如果电脑中存有重要工作资料，请定期手动更新安全补丁
- 使用前建议创建系统还原点

## 🔄 恢复更新

如果需要恢复 Windows 更新，运行工具后选择选项 `3` 即可一键恢复所有功能。

## 🛡️ 安全说明

- 本工具为纯开源代码，所有操作均可审计
- 不收集任何用户数据
- 不连接任何外部服务器（仅首次下载时连接 GitHub）
- 所有修改均可通过"恢复更新"功能还原

## 📜 许可证

MIT License - 自由使用、修改和分发。

## 🙏 致谢

本项目架构参考了 [Microsoft-Activation-Scripts](https://github.com/massgravel/Microsoft-Activation-Scripts) 项目的设计模式。
## <img width="128" height="128" alt="微信图片_20260508013723_46_2" src="https://github.com/user-attachments/assets/ce8d934e-a3c1-46c2-a87c-b406f824ff4f" />
扫码关注微信公众号:爱修电脑的童哥
