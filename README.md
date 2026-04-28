# Emotion's blog

个人技术博客，基于 [Quartz v4](https://quartz.jzhao.xyz/) 构建，部署在 GitHub Pages。

站点地址：<https://emotion.github.io>

## 内容源

博客文章的源文件保存在本地 Obsidian vault 的 `Blog/` 目录中。
日常写作在 Obsidian 里完成，通过脚本同步到本仓库的 `content/`。

## 本地开发

```bash
# 从 Obsidian vault 同步博客内容
./scripts/sync-from-obsidian.sh

# 本地构建
npx quartz build

# 本地预览
npx quartz build --serve
```

## 发布流程

1. 在 Obsidian 的 `Blog/` 目录里写文章，设置 `draft: false` 表示可发布
2. 运行 `./scripts/sync-from-obsidian.sh` 同步到 `content/`
3. `git push` 到 master，GitHub Actions 自动构建并部署到 GitHub Pages
