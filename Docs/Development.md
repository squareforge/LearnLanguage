# 开发与验证

环境要求和启动步骤见 [README](../README.md)。

## 源码结构

| 路径 | 内容 |
| --- | --- |
| `LearnLanguage/Base/` | 基础模型、设置、存储与公共管理器 |
| `LearnLanguage/Modules/Learning/` | 统一学习项、课程、输入状态机和练习面板 |
| `LearnLanguage/Modules/Main/` | 主界面与导航 |
| `LearnLanguage/Modules/StatusBar/` | 菜单栏显示和交互 |
| `LearnLanguage/Modules/WordList/` | 词库管理 |
| `LearnLanguage/Modules/Progress/` | 学习记录与复习 |
| `LearnLanguage/Modules/Translation/` | 翻译、OCR 和剪贴板监听 |
| `LearnLanguage/Modules/Data/` | 数据备份、恢复与维护 |
| `LearnLanguage/Modules/Settings/` | 偏好设置 |
| `LearnLanguage/Resources/` | 词库、字体、音效等资源 |
| `Tools/` | 数据处理、资源校验与测试脚本 |

## 运行检查

在项目根目录执行。需要 Python 3；Swift 测试通过 Xcode 工具链编译。

```bash
python3 Tools/validate_resources.py
python3 Tools/test_learning.py
python3 Tools/test_translation.py
python3 Tools/test_storage.py
```

构建原生依赖后，可运行 WCDB / MMKV 集成测试和 AppKit 练习窗口测试：

```bash
xcodebuild -workspace LearnLanguage.xcworkspace -scheme LearnLanguage \
  -configuration Debug -derivedDataPath /tmp/LearnLanguageDerivedData \
  CODE_SIGNING_ALLOWED=NO build

python3 Tools/test_storage.py --derived-data /tmp/LearnLanguageDerivedData
python3 Tools/test_practice_ui.py --derived-data /tmp/LearnLanguageDerivedData
```

练习窗口测试需要已登录的 macOS 桌面，会短暂显示真实窗口。测试通过窗口事件验证输入、释义确认、课程切换与菜单栏衔接，音频输出使用静音替身。

存储测试覆盖归档校验、SQLite 快照、失败回滚、内容迁移、学习事务、跨天队列与分页。额外检查完整内置词库迁移：

```bash
python3 Tools/test_storage.py \
  --derived-data /tmp/LearnLanguageDerivedData --full-dictionary
```

这些测试使用临时目录或内存数据，不读写现有学习数据。资源校验读取仓库内置词库，完整迁移测试在临时副本上执行。

## 课程数据

课程资源位于 `LearnLanguage/Modules/Learning/Resources/`，导入时固定上游版本，保留文字、释义、音标与排列顺序。详见[来源说明](../LearnLanguage/Modules/Learning/Resources/Xingrong-SOURCE.md)。

```bash
python3 Tools/import_xingrong_courses.py
```

也可通过 `--source-dir /path/to/earthworm` 使用固定版本的干净上游仓库。

课程进度以课号和条目序号区分，保存在 MMKV 的 `learning.course_progress.v1`，随应用备份导出；词库学习沿用每日队列和 WCDB 学习记录。

## 内置词库

`LearnLanguage/Resources/InitialDicts/LearnLanguage.db` 约 95 MiB，与同目录的 `dictionary-manifest.json` 一起纳入版本管理。Xcode 构建时会校验资源的大小、SHA-256 和 SQLite 结构。

更新词库时，先生成不依赖 WAL 的完整数据库，再同步更新 manifest 中的内容版本、字节数与 SHA-256。应用按内容校验值执行事务迁移，保留已有学习进度。`db-wal`、`db-shm` 等运行文件不纳入仓库。

备份采用 SQLite 一致性快照与 MMKV 官方备份。恢复先校验并准备数据，再暂停练习、替换文件；失败保留回滚路径，未提交的替换在下次启动时恢复。
