# Agent 说明

> 此为新公开分发副本。后续修改继续按分支 → Pull Request → 审查 → 合并流程进行；保留地图生成器、模块依赖与素材授权约定。

给在本仓库里工作的 AI 编程工具（Claude Code、Codex、Cursor 等）看。

- 用中文交流。代码、标识符和提交说明可以用英文。
- 动手前先读 `ARCHITECTURE.md`（依赖规则）和 `GLOSSARY.md`（术语），并遵守 `COLLABORATE.md` 的协作流程：不直接提交到 `main`，提交前检查 `git diff`，地图改 `tools/gen_zones.py` 后重新生成。
- 引擎是 Godot 4.7.2。`../origin/` 旧工程只作参考：可以迁移代码，不能拷素材。
