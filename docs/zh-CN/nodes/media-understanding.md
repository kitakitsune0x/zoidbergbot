---
read_when:
  - 设计或重构媒体理解功能
  - 调优入站音频/视频/图片预处理
summary: 入站图片/音频/视频理解（可选），支持提供商 + CLI 回退
title: 媒体理解
x-i18n:
  generated_at: "2026-02-01T21:18:50Z"
  model: claude-opus-4-5
  provider: pi
  source_hash: f6c575662b7fcbf0b62c46e3fdfa4cdb7cfd455513097e4a2cdec8a34cbdbd48
  source_path: nodes/media-understanding.md
  workflow: 15
---

# 媒体理解（入站） — 2026-01-17

ZoidbergBot 可以在回复管道运行之前**总结入站媒体**（图片/音频/视频）。它会在本地工具或提供商密钥可用时自动检测，也可以禁用或自定义。如果理解功能关闭，模型仍会照常接收原始文件/URL。

## 目标

- 可选：将入站媒体预处理为简短文本，以加快路由 + 改善命令解析。
- 始终保留原始媒体向模型的传递。
- 支持**提供商 API** 和 **CLI 回退**。
- 允许多个模型按顺序回退（错误/大小/超时）。

## 高层行为

1. 收集入站附件（`MediaPaths`、`MediaUrls`、`MediaTypes`）。
2. 对每个已启用的能力（图片/音频/视频），按策略选择附件（默认：**第一个**）。
3. 选择第一个符合条件的模型条目（大小 + 能力 + 认证）。
4. 如果模型失败或媒体过大，**回退到下一个条目**。
5. 成功时：
   - `Body` 变为 `[Image]`、`[Audio]` 或 `[Video]` 块。
   - 音频设置 `{{Transcript}}`；命令解析在有说明文字时使用说明文字，否则使用转录文本。
   - 说明文字作为 `User text:` 保留在块内。

如果理解失败或已禁用，**回复流程继续**使用原始正文 + 附件。

## 配置概览

`tools.media` 支持**共享模型**加每能力覆盖：

- `tools.media.models`：共享模型列表（使用 `capabilities` 进行能力筛选）。
- `tools.media.image` / `tools.media.audio` / `tools.media.video`：
  - 默认值（`prompt`、`maxChars`、`maxBytes`、`timeoutSeconds`、`language`）
  - 提供商覆盖（`baseUrl`、`headers`、`providerOptions`）
  - Deepgram 音频选项通过 `tools.media.audio.providerOptions.deepgram` 设置
  - 可选的**每能力 `models` 列表**（优先于共享模型）
  - `attachments` 策略（`mode`、`maxAttachments`、`prefer`）
  - `scope`（可选，按渠道/聊天类型/会话键筛选）
- `tools.media.concurrency`：最大并发能力运行数（默认 **2**）。

```json5
{
  tools: {
    media: {
      models: [
        /* 共享列表 */
      ],
      image: {
        /* 可选覆盖 */
      },
      audio: {
        /* 可选覆盖 */
      },
      video: {
        /* 可选覆盖 */
      },
    },
  },
}
```

### 模型条目

每个 `models[]` 条目可以是**提供商**或 **CLI** 类型：

```json5
{
  type: "provider", // 省略时默认
  provider: "openai",
  model: "gpt-5.2",
  prompt: "Describe the image in <= 500 chars.",
  maxChars: 500,
  maxBytes: 10485760,
  timeoutSeconds: 60,
  capabilities: ["image"], // 可选，用于多模态条目
  profile: "vision-profile",
  preferredProfile: "vision-fallback",
}
```

```json5
{
  type: "cli",
  command: "gemini",
  args: [
    "-m",
    "gemini-3-flash",
    "--allowed-tools",
    "read_file",
    "Read the media at {{MediaPath}} and describe it in <= {{MaxChars}} characters.",
  ],
  maxChars: 500,
  maxBytes: 52428800,
  timeoutSeconds: 120,
  capabilities: ["video", "image"],
}
```

CLI 模板还可以使用：

- `{{MediaDir}}`（包含媒体文件的目录）
- `{{OutputDir}}`（为本次运行创建的临时目录）
- `{{OutputBase}}`（临时文件基础路径，无扩展名）

## 默认值和限制

推荐默认值：

- `maxChars`：图片/视频为 **500**（简短，适合命令解析）
- `maxChars`：音频**未设置**（完整转录，除非你设置限制）
- `maxBytes`：
  - 图片：**10MB**
  - 音频：**20MB**
  - 视频：**50MB**

规则：

- 如果媒体超过 `maxBytes`，该模型被跳过，**尝试下一个模型**。
- 如果模型返回超过 `maxChars`，输出会被裁剪。
- `prompt` 默认为简单的"描述该 {媒体}。"加上 `maxChars` 指导（仅图片/视频）。
- 如果 `<capability>.enabled: true` 但未配置模型，ZoidbergBot 会在其提供商支持该能力时尝试**当前回复模型**。

### 自动检测媒体理解（默认）

如果 `tools.media.<capability>.enabled` **未**设置为 `false` 且你未配置模型，ZoidbergBot 会按以下顺序自动检测，并在**找到第一个可用选项时停止**：

1. **本地 CLI**（仅音频；如已安装）
   - `sherpa-onnx-offline`（需要 `SHERPA_ONNX_MODEL_DIR` 包含 encoder/decoder/joiner/tokens）
   - `whisper-cli`（`whisper-cpp`；使用 `WHISPER_CPP_MODEL` 或内置的 tiny 模型）
   - `whisper`（Python CLI；自动下载模型）
2. **Gemini CLI**（`gemini`）使用 `read_many_files`
3. **提供商密钥**
   - 音频：OpenAI → Groq → Deepgram → Google
   - 图片：OpenAI → Anthropic → Google → MiniMax
   - 视频：Google

要禁用自动检测，请设置：

```json5
{
  tools: {
    media: {
      audio: {
        enabled: false,
      },
    },
  },
}
```

注意：二进制检测在 macOS/Linux/Windows 上采用尽力而为的方式；请确保 CLI 在 `PATH` 中（我们会展开 `~`），或通过完整命令路径设置显式 CLI 模型。

## 能力（可选）

如果你设置了 `capabilities`，该条目仅针对指定的媒体类型运行。对于共享列表，ZoidbergBot 可以推断默认值：

- `openai`、`anthropic`、`minimax`：**图片**
- `google`（Gemini API）：**图片 + 音频 + 视频**
- `groq`：**音频**
- `deepgram`：**音频**

对于 CLI 条目，**请显式设置 `capabilities`** 以避免意外匹配。
如果省略 `capabilities`，该条目对其所在列表中的所有类型均有效。

## 提供商支持矩阵（ZoidbergBot 集成）

| 能力 | 提供商集成                                     | 说明                                    |
| ---- | ---------------------------------------------- | --------------------------------------- |
| 图片 | OpenAI / Anthropic / Google / 其他通过 `pi-ai` | 注册表中任何支持图片的模型均可使用。    |
| 音频 | OpenAI、Groq、Deepgram、Google                 | 提供商转录（Whisper/Deepgram/Gemini）。 |
| 视频 | Google（Gemini API）                           | 提供商视频理解。                        |

## 推荐提供商

**图片**

- 如果当前模型支持图片，优先使用当前模型。
- 推荐默认值：`openai/gpt-5.2`、`anthropic/claude-opus-4-5`、`google/gemini-3-pro-preview`。

**音频**

- `openai/gpt-4o-mini-transcribe`、`groq/whisper-large-v3-turbo` 或 `deepgram/nova-3`。
- CLI 回退：`whisper-cli`（whisper-cpp）或 `whisper`。
- Deepgram 设置：[Deepgram（音频转录）](/providers/deepgram)。

**视频**

- `google/gemini-3-flash-preview`（快速）、`google/gemini-3-pro-preview`（更丰富）。
- CLI 回退：`gemini` CLI（支持对视频/音频使用 `read_file`）。

## 附件策略

每能力的 `attachments` 控制处理哪些附件：

- `mode`：`first`（默认）或 `all`
- `maxAttachments`：处理数量上限（默认 **1**）
- `prefer`：`first`、`last`、`path`、`url`

当 `mode: "all"` 时，输出标记为 `[Image 1/2]`、`[Audio 2/2]` 等。

## 配置示例

### 1) 共享模型列表 + 覆盖

```json5
{
  tools: {
    media: {
      models: [
        { provider: "openai", model: "gpt-5.2", capabilities: ["image"] },
        {
          provider: "google",
          model: "gemini-3-flash-preview",
          capabilities: ["image", "audio", "video"],
        },
        {
          type: "cli",
          command: "gemini",
          args: [
            "-m",
            "gemini-3-flash",
            "--allowed-tools",
            "read_file",
            "Read the media at {{MediaPath}} and describe it in <= {{MaxChars}} characters.",
          ],
          capabilities: ["image", "video"],
        },
      ],
      audio: {
        attachments: { mode: "all", maxAttachments: 2 },
      },
      video: {
        maxChars: 500,
      },
    },
  },
}
```

### 2) 仅音频 + 视频（图片关闭）

```json5
{
  tools: {
    media: {
      audio: {
        enabled: true,
        models: [
          { provider: "openai", model: "gpt-4o-mini-transcribe" },
          {
            type: "cli",
            command: "whisper",
            args: ["--model", "base", "{{MediaPath}}"],
          },
        ],
      },
      video: {
        enabled: true,
        maxChars: 500,
        models: [
          { provider: "google", model: "gemini-3-flash-preview" },
          {
            type: "cli",
            command: "gemini",
            args: [
              "-m",
              "gemini-3-flash",
              "--allowed-tools",
              "read_file",
              "Read the media at {{MediaPath}} and describe it in <= {{MaxChars}} characters.",
            ],
          },
        ],
      },
    },
  },
}
```

### 3) 可选图片理解

```json5
{
  tools: {
    media: {
      image: {
        enabled: true,
        maxBytes: 10485760,
        maxChars: 500,
        models: [
          { provider: "openai", model: "gpt-5.2" },
          { provider: "anthropic", model: "claude-opus-4-5" },
          {
            type: "cli",
            command: "gemini",
            args: [
              "-m",
              "gemini-3-flash",
              "--allowed-tools",
              "read_file",
              "Read the media at {{MediaPath}} and describe it in <= {{MaxChars}} characters.",
            ],
          },
        ],
      },
    },
  },
}
```

### 4) 多模态单条目（显式能力）

```json5
{
  tools: {
    media: {
      image: {
        models: [
          {
            provider: "google",
            model: "gemini-3-pro-preview",
            capabilities: ["image", "video", "audio"],
          },
        ],
      },
      audio: {
        models: [
          {
            provider: "google",
            model: "gemini-3-pro-preview",
            capabilities: ["image", "video", "audio"],
          },
        ],
      },
      video: {
        models: [
          {
            provider: "google",
            model: "gemini-3-pro-preview",
            capabilities: ["image", "video", "audio"],
          },
        ],
      },
    },
  },
}
```

## 状态输出

当媒体理解运行时，`/status` 包含一行简短摘要：

```
📎 Media: image ok (openai/gpt-5.2) · audio skipped (maxBytes)
```

这显示了每个能力的结果以及适用时选择的提供商/模型。

## 注意事项

- 理解是**尽力而为**的。错误不会阻塞回复。
- 即使理解功能禁用，附件仍会传递给模型。
- 使用 `scope` 限制理解功能的运行范围（例如仅私聊）。

## 相关文档

- [配置](/gateway/configuration)
- [图片与媒体支持](/nodes/images)
