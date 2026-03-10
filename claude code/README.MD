## 安装
```fish
sudo pacman -S --needed curl bash git
curl -fsSL https://claude.ai/install.sh | bash
fish_add_path ~/.local/bin
exec fish
claude --version
claude
```

## 更新
```fish
curl -fsSL https://claude.ai/install.sh | bash
claude --version
```

## 卸载
```fish
rm -f ~/.local/bin/claude
rm -rf ~/.claude
```


````md
## Claude Code 环境变量配置（fish）

如果你使用的是 `fish` shell，那么环境变量的写法和 `bash` / `zsh` 不一样。

很多文档会写成下面这样：

```bash
export ANTHROPIC_BASE_URL="https://example.com"
export ANTHROPIC_AUTH_TOKEN="your_token_here"
````

但在 `fish` 中，不能直接使用 `export`，需要改成 `set` 的写法。

---

### 当前终端临时生效

如果只想让变量在**当前这个终端会话**中生效，可以执行：

```fish
set -x ANTHROPIC_BASE_URL "https://example.com"
set -x ANTHROPIC_AUTH_TOKEN "your_token_here"
set -x CLAUDE_CODE_ATTRIBUTION_HEADER "0"
```

#### 说明

* `set`：设置变量
* `-x`：将变量导出为环境变量，使子进程也能读取
* 这种方式只对**当前终端窗口**有效
* 关闭终端后，变量会失效

配置完成后，在同一个终端中启动 Claude Code，即可读取这些变量。

---

### fish 中永久生效（推荐）

在 `fish` 中，更推荐使用通用变量（universal variables）来持久保存配置。

执行以下命令：

```fish
set -Ux ANTHROPIC_BASE_URL "https://example.com"
set -Ux ANTHROPIC_AUTH_TOKEN "your_token_here"
set -Ux CLAUDE_CODE_ATTRIBUTION_HEADER "0"
```

#### 说明

* `-U`：设置为 universal variable（通用变量）
* `-x`：导出为环境变量
* 这种方式会被 fish 持久保存
* 重开终端后依然有效

这是 **fish 用户最推荐的方式**。

---

### 使用 `config.fish` 永久加载

另一种常见方式，是把配置写入 fish 的配置文件：

```text
~/.config/fish/config.fish
```

在文件中加入：

```fish
set -x ANTHROPIC_BASE_URL "https://example.com"
set -x ANTHROPIC_AUTH_TOKEN "your_token_here"
set -x CLAUDE_CODE_ATTRIBUTION_HEADER "0"
```

保存后执行：

```fish
source ~/.config/fish/config.fish
```

或者直接关闭终端并重新打开。

#### 这种方式和 `set -Ux` 的区别

`config.fish` 方式：

* 每次启动 fish 时都会执行
* 配置集中，便于查看
* 适合喜欢把 shell 配置统一写在配置文件中的用户

`set -Ux` 方式：

* 更符合 fish 的使用习惯
* 不需要手动编辑配置文件
* 更适合只想快速持久生效的用户

如果没有特殊需求，**优先推荐 `set -Ux`**。

---

### 如何验证环境变量是否生效

配置完成后，可以执行以下命令检查：

```fish
echo $ANTHROPIC_BASE_URL
echo $ANTHROPIC_AUTH_TOKEN
echo $CLAUDE_CODE_ATTRIBUTION_HEADER
```

如果输出了对应内容，说明变量已经存在。

也可以用更稳妥的写法：

```fish
set -q ANTHROPIC_BASE_URL; and echo $ANTHROPIC_BASE_URL
set -q ANTHROPIC_AUTH_TOKEN; and echo $ANTHROPIC_AUTH_TOKEN
set -q CLAUDE_CODE_ATTRIBUTION_HEADER; and echo $CLAUDE_CODE_ATTRIBUTION_HEADER
```

#### 说明

* `set -q`：检查变量是否存在
* `and echo ...`：如果存在，就输出它的值

---

### VS Code 中的 Claude Code 配置

如果你在 VS Code 中使用 Claude Code，也可以通过配置文件设置环境变量。

配置文件路径：

```text
~/.claude/settings.json
```

示例内容：

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://example.com",
    "ANTHROPIC_AUTH_TOKEN": "your_token_here",
    "CLAUDE_CODE_ATTRIBUTION_HEADER": "0"
  }
}
```

#### 说明

* `env` 中的变量会提供给 Claude Code 使用
* 这适用于 Claude Code 的配置环境
* 如果你既在终端中使用，也在 VS Code 中使用，建议两边都配置

---

### 终端变量与 VS Code 配置的区别

可以简单理解为：

#### 终端运行 Claude Code

如果你是在 `fish` 终端里直接启动 Claude Code，那么它主要依赖当前 shell 的环境变量。

例如：

```fish
set -Ux ANTHROPIC_BASE_URL "https://example.com"
set -Ux ANTHROPIC_AUTH_TOKEN "your_token_here"
claude
```

#### VS Code 中使用 Claude Code

如果你主要在 VS Code 中使用 Claude Code，那么 `~/.claude/settings.json` 里的 `env` 配置通常更直接。

因此，最稳妥的方式是：

* 终端环境变量配置一份
* `~/.claude/settings.json` 再配置一份

这样无论在哪个入口启动 Claude Code，都不容易出问题。

---

### 删除变量

如果之后需要删除这些变量，可以执行：

```fish
set -e ANTHROPIC_BASE_URL
set -e ANTHROPIC_AUTH_TOKEN
set -e CLAUDE_CODE_ATTRIBUTION_HEADER
```

#### 说明

* `set -e` 用于删除变量
* 对 `set -Ux` 创建的持久变量同样有效

删除后可以再次执行：

```fish
echo $ANTHROPIC_BASE_URL
echo $ANTHROPIC_AUTH_TOKEN
echo $CLAUDE_CODE_ATTRIBUTION_HEADER
```

如果没有输出，说明变量已经被删除。

---

### 推荐配置方式

对于 `fish` 用户，推荐直接执行：

```fish
set -Ux ANTHROPIC_BASE_URL "https://example.com"
set -Ux ANTHROPIC_AUTH_TOKEN "your_token_here"
set -Ux CLAUDE_CODE_ATTRIBUTION_HEADER "0"
```

如果你还要在 VS Code 中使用 Claude Code，再补充配置：

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://example.com",
    "ANTHROPIC_AUTH_TOKEN": "your_token_here",
    "CLAUDE_CODE_ATTRIBUTION_HEADER": "0"
  }
}
```

---

### 安全提示

**不要把真实的 token 直接写进公开仓库的 README、截图或示例代码中。**

错误示例：

```fish
set -Ux ANTHROPIC_AUTH_TOKEN "sk-xxxxxxxxxxxxxxxxxxxxxxxx"
```

正确示例应使用占位符：

```fish
set -Ux ANTHROPIC_AUTH_TOKEN "your_token_here"
```

或者：

```fish
set -Ux ANTHROPIC_AUTH_TOKEN "<YOUR_TOKEN>"
```

如果 token 已经泄露，建议立即到对应服务后台撤销并重新生成新的 token。

---

### 完整示例

#### fish 中永久配置

```fish
set -Ux ANTHROPIC_BASE_URL "https://example.com"
set -Ux ANTHROPIC_AUTH_TOKEN "<YOUR_TOKEN>"
set -Ux CLAUDE_CODE_ATTRIBUTION_HEADER "0"
```

#### 检查是否生效

```fish
echo $ANTHROPIC_BASE_URL
echo $ANTHROPIC_AUTH_TOKEN
echo $CLAUDE_CODE_ATTRIBUTION_HEADER
```

#### VS Code Claude Code 配置

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://example.com",
    "ANTHROPIC_AUTH_TOKEN": "<YOUR_TOKEN>",
    "CLAUDE_CODE_ATTRIBUTION_HEADER": "0"
  }
}
```

---

### 常见问题

#### 为什么 `export` 不能用？

因为 `export` 是 `bash` / `zsh` 的写法，`fish` 使用的是 `set` 语法。

#### 为什么我配置了还是没生效？

常见原因有：

* 变量只设置在旧终端，当前终端没有重新加载
* 使用了 `set -x`，但关闭终端后变量丢失
* 只配了 shell，没有配 VS Code
* `settings.json` 格式错误，导致 Claude Code 未正确读取

#### 应该选 `set -Ux` 还是 `config.fish`？

日常使用推荐 `set -Ux`。
如果你喜欢把所有 shell 配置统一写进配置文件，可以使用 `config.fish`。

