# MS-DOC Viewer MoonBit：高性能 MS-DOC 文档解析与渲染引擎

## 项目仓库链接
- GitHub: https://github.com/XiaoChenxu1001/msdoc-viewer-moonbit
- Gitee: https://gitee.com/xcx-uming/msdoc-viewer-moonbit

## 项目名称
MS-DOC Viewer MoonBit：高性能 MS-DOC 文档解析与渲染引擎

## 项目摘要
将 TypeScript/JavaScript 版 msdoc-viewer 的核心 MS-DOC 文档解析与渲染能力移植到 MoonBit 生态，为 .doc 格式文档查看、内容提取、格式转换、在线预览、办公自动化工具和文档分析系统提供高性能的跨平台解析引擎。

## 项目方向
MoonBit MS-DOC 文档解析与渲染基础库 / 文档处理基础设施

## 目标用例
在 MoonBit 中处理 MS-DOC (.doc) 二进制 Word 文档，提供完整的 CFB/OLE 容器解析、FIB 文件信息块解析、CLX Piece Table 文本恢复、SPRM 属性解码、样式解析以及 HTML/CSS 渲染能力。

## 核心功能
1. 多目标编译架构：一套 MoonBit 源码，支持 JS (ESM)、JS Worker、WASM (线性内存)、WASM-GC 四种编译目标
2. CFB/OLE 容器解析：完整解析 Compound File Binary 格式，提取核心流
3. FIB (File Information Block) 解析：读取文件头部信息，定位关键数据结构
4. CLX / Piece Table 文本恢复：通过 Piece Table 正确重组被分割的文本段落
5. SPRM (Single Property Modifier) 解码：解码 Word 格式的属性修改器
6. FKP (Formatted Disk Page) 读取：获取段落和字符的格式化属性
7. 字体与样式解析：解析文档字体表和样式定义
8. HTML/CSS 渲染器：将解析后的文档数据转换为语义化的 HTML 和 CSS
9. Web Worker 支持：文档解析可在后台线程执行，UI 保持响应
10. WASM 浏览器支持：WASM 和 WASM-GC 目标直接在浏览器运行
11. EMF/WMF 图像转换：支持 Windows 元文件格式转换为 SVG
12. 测试套件：提供 10 个 .doc 测试文档
13. 浏览器演示：提供四种目标的完整演示页面

## 实现计划
1. 核心解析器：CFB 容器解析、FIB 解析、CLX/Piece Table 解析
2. 渲染引擎：HTML/CSS 生成
3. 多目标构建：JS、WASM、WASM-GC 编译配置
4. 测试套件：单元测试和集成测试
5. 演示应用：浏览器端演示

## 预期交付物
1. 完整的 MoonBit 源代码
2. 多目标构建配置
3. 测试套件
4. 浏览器演示
5. 详细文档

## 项目原创性
本项目基于 msdoc-viewer (TypeScript/JavaScript) 移植到 MoonBit 生态。

### 参考项目信息
| 项目 | 内容 |
|------|------|
| 原项目名称 | msdoc-viewer (TypeScript/JavaScript) |
| 原项目链接 | https://github.com/flyfish-dev/file-viewer |
| 原项目许可证 | MIT License |
| 本项目许可证 | Apache License 2.0 |

### 与原项目的差异
1. **语言迁移**：使用 MoonBit 原生类型系统、模式匹配和代数数据类型重新实现核心解析逻辑
2. **包结构重组**：使用 MoonBit 原生包结构组织代码
3. **类型安全增强**：利用 MoonBit 的强类型系统，在编译期捕获更多潜在错误
4. **多目标优化**：针对四种编译目标分别优化
5. **WASM 线性内存支持**：新增 WASM 线性内存目标，提供完整的内存管理 ABI 文档
6. **WASM-GC 支持**：利用 WASM-GC 的 JS string builtins 实现原生字符串互操作
7. **弱化浏览器依赖**：移除对 DOM API 的直接依赖，核心解析逻辑可在 Node.js 和 WASM 运行时中独立运行
8. **API 设计简化**：提供更简洁的 MoonBit API
9. **错误处理改进**：使用 MoonBit 的 Result 类型替代 JavaScript 的异常机制
10. **性能优化**：利用 MoonBit 的编译优化和 WASM 的近原生性能