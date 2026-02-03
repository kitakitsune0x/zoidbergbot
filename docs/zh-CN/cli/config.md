---
read_when:
  - 你想以非交互方式读取或编辑配置
summary: "`zoidbergbot config` 的 CLI 参考（获取/设置/删除配置值）"
title: config
x-i18n:
  generated_at: "2026-02-01T19:58:45Z"
  model: claude-opus-4-5
  provider: pi
  source_hash: d60a35f5330f22bc99a0df090590586109d329ddd2ca294aeed191a22560c1c2
  source_path: cli/config.md
  workflow: 14
---

# `zoidbergbot config`

配置辅助工具：通过路径获取/设置/删除值。不带子命令运行时将打开配置向导（与 `zoidbergbot configure` 相同）。

## 示例

```bash
zoidbergbot config get browser.executablePath
zoidbergbot config set browser.executablePath "/usr/bin/google-chrome"
zoidbergbot config set agents.defaults.heartbeat.every "2h"
zoidbergbot config set agents.list[0].tools.exec.node "node-id-or-name"
zoidbergbot config unset tools.web.search.apiKey
```

## 路径

路径使用点号或方括号表示法：

```bash
zoidbergbot config get agents.defaults.workspace
zoidbergbot config get agents.list[0].id
```

使用智能体列表索引来指定特定智能体：

```bash
zoidbergbot config get agents.list
zoidbergbot config set agents.list[1].tools.exec.node "node-id-or-name"
```

## 值

值会尽可能按 JSON5 解析；否则视为字符串。
使用 `--json` 强制要求 JSON5 解析。

```bash
zoidbergbot config set agents.defaults.heartbeat.every "0m"
zoidbergbot config set gateway.port 19001 --json
zoidbergbot config set channels.whatsapp.groups '["*"]' --json
```

编辑后请重启 Gateway网关。
