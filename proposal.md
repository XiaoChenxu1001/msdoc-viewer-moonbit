# MS-DOC Viewer - MoonBit

## 项目仓库链接
- GitHub: https://github.com/XiaoChenxu1001/msdoc-viewer-moonbit
- Gitee: https://gitee.com/xcx-uming/msdoc-viewer-moonbit

## 项目名称
MS-DOC Viewer - MoonBit

## 项目摘要
高性能 MS-DOC (.doc binary Word) 解析器和渲染器，使用 MoonBit 编写，支持多目标编译（JS、WASM、WASM-GC）。

## 项目方向
MoonBit 生态系统工具库 - 文档处理

## 目标用例
在浏览器中解析和渲染传统的 Microsoft Word .doc 二进制格式文档。

## 核心功能
1. 多目标编译：JS (ESM)、WASM (线性内存)、WASM-GC 后端
2. Web Worker 支持：后台线程解析
3. 丰富内容解析：文本、表格、图片、页眉页脚、文本框、脚注尾注
4. OLE 对象提取：OLE10Native 附件、EPRINT 流、PSD 包装的 EMF
5. 文档元数据：摘要信息（标题、作者、主题）
6. 页面布局：节属性（边距、方向、列）

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
本项目为原创项目，基于对 MS-DOC 二进制格式的深入研究实现。参考了 Microsoft Office 文档格式规范，但所有代码均为独立实现。