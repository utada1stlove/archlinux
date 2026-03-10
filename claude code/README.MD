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
