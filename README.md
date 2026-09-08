# JSON Lens

面向开发者和产品经理的原生 macOS JSON 工作台。所有数据只在本机处理，无网络请求和第三方依赖。

## 功能

- 实时语法校验，并显示错误行列
- 2/4 空格格式化、压缩、复制、打开、保存和文件拖放
- 可折叠树形结构，按字段、路径和值搜索
- 对象数组自动转换为表格并导出 CSV
- 节点、字段、深度、大小及值类型统计
- JSONPath 查询：字段、数组下标、通配符、括号字段和递归字段
- 双栏结构化 Diff，筛选新增、删除和变更
- 本地历史快照，快速恢复近期内容
- macOS 菜单快捷键和 `.json` 文件类型声明

## 运行

```bash
swift run
```

## 验证

当前环境只安装了 macOS Command Line Tools，未包含 XCTest。项目使用独立 Swift 检查程序覆盖核心逻辑：

```bash
./scripts/test.sh
```

## 构建应用

```bash
./scripts/build-app.sh
open "dist/JSON Lens.app"
```

生成的应用位于 `dist/JSON Lens.app`，使用本地 ad-hoc 签名。

## 生成 DMG

```bash
./scripts/package-dmg.sh
```

脚本会重新构建应用、创建带有 `Applications` 快捷方式的压缩镜像，并执行挂载回读和签名校验。产物位于 `dist/JSON-Lens-1.0.0-arm64.dmg`。

## JSONPath 范围

```text
$.project.name
$.users[0]
$.users[*].role
$['release']['flags']
$..id
```
