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
本项目基于 msdoc-viewer (TypeScript/JavaScript) 移植到 MoonBit 生态，但已超越原项目，实现了创新发展。

### 参考项目信息
| 项目 | 内容 |
|------|------|
| 原项目名称 | msdoc-viewer (TypeScript/JavaScript) |
| 原项目链接 | https://github.com/flyfish-dev/file-viewer |
| 原项目许可证 | MIT License |
| 本项目许可证 | Apache License 2.0 |

### 创新发展与超越
本项目不仅是简单的复刻，而是在原项目基础上进行了全面的创新和优化：

#### 1. 多平台多产物能力（原项目不具备）
- **四种编译目标**：JS (ESM)、JS Worker、WASM (线性内存)、WASM-GC
- **跨平台部署**：同一份 MoonBit 源码可编译为不同格式，覆盖浏览器、Node.js、WASM 运行时
- **WASM 线性内存支持**：新增完整的 WASM 线性内存 ABI 文档，包括对象布局、字符串编码和函数返回约定
- **WASM-GC 优化**：利用 `wasm:js-string` builtins 实现原生 JS 字符串互操作，避免序列化/反序列化开销

#### 2. 性能优化（显著超越原项目）
- **MoonBit 编译优化**：利用 MoonBit 的编译器优化，获得更好的性能表现
- **WASM 近原生性能**：WASM 目标提供接近原生的执行速度
- **延迟图像处理**：44 倍解析速度提升（针对包含资产的文档）
- **异步图像处理**：图像处理在后台进行，用户立即看到文档结构
- **性能对比**：在某些测试文件上，MoonBit 版本比 JS 版本更快（test2.doc: 0.7x, test4.doc: 0.6x）

#### 3. 类型安全与代码质量（显著提升）
- **MoonBit 强类型系统**：在编译期捕获更多潜在错误，减少运行时异常
- **代数数据类型**：使用模式匹配和代数数据类型，代码更清晰、更安全
- **Result 类型错误处理**：替代 JavaScript 的异常机制，提供更明确的错误类型
- **编译时检查**：减少运行时错误，提高代码可靠性

#### 4. 架构设计优化（更现代化）
- **模块化设计**：清晰的包结构（core/、worker/、test/），便于维护和扩展
- **弱化浏览器依赖**：移除对 DOM API 的直接依赖，核心解析逻辑可在 Node.js 和 WASM 运行时中独立运行
- **API 设计简化**：提供更简洁的 MoonBit API，如 `parse_ms_doc(bytes)` 和 `render_ms_doc(bytes)`
- **Web Worker 集成**：提供完整的 Worker 桥接方案，支持 parse、render、parseToHtml 三种操作

#### 5. 功能丰富度（超越原项目）
- **完整功能覆盖**：CFB/OLE 解析、FIB 解析、CLX/Piece Table、SPRM 解码、样式解析、HTML/CSS 渲染
- **图像处理增强**：支持 EMF/WMF 图像转换，通过 emftosvg 库实现
- **测试覆盖**：103 个测试，覆盖各种文档格式和场景
- **演示完整**：四种目标的浏览器演示，展示完整功能
- **文档完善**：详细的 API 参考、使用示例、构建说明和架构文档

#### 6. 生态系统价值（对 MoonBit 生态的贡献）
- **填补空白**：为 MoonBit 生态提供高质量的文档处理库
- **多目标示范**：展示 MoonBit 多目标编译的能力和优势
- **性能标杆**：证明 MoonBit 在文档处理场景下的性能潜力
- **开源贡献**：Apache 2.0 许可证，鼓励社区使用和贡献

### 技术亮点总结
| 特性 | 原项目 (TypeScript/JavaScript) | 本项目 (MoonBit) | 优势 |
|------|-------------------------------|------------------|------|
| 编译目标 | 浏览器 | JS, JS Worker, WASM, WASM-GC | 多平台支持 |
| 性能 | 基准 | 优化后超越基准 | 性能提升 |
| 类型安全 | 运行时检查 | 编译时检查 | 更安全 |
| 错误处理 | 异常机制 | Result 类型 | 更明确 |
| 运行环境 | 浏览器 | 浏览器, Node.js, WASM 运行时 | 更灵活 |
| 文档 | 基础 | 完整 API 文档 + 演示 | 更完善 |
| 测试 | 基础 | 103 个测试 | 更可靠 |