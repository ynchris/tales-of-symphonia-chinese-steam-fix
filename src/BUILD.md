# 构建说明

玩家直接下载 Release，无需构建。

转发器使用 Windows x86 TinyCC 0.9.27 构建；Python 需安装 pefile。建议在纯英文路径下操作：

```bat
tcc -m32 -shared -o wrapped.dll clean_proxy.c
python make_forwarders.py wrapped.dll 3dmgame.dll
python adapt_translation.py 原始3dm32.dll 3dm32.dll
```

最后一条命令要求输入来自 3DM v2.0 的原始 DLL，并校验其 SHA-256。它仅将文件偏移 0x1DDD 的 C8 改为 CA，将字体尺寸钩子向后调整两字节，避免覆盖新版函数中间的指令。其余汉化资源使用原补丁文件。

安装脚本位于 installer，校验受支持的游戏版本及各载荷的完整哈希。游戏主程序只修改文件偏移 22550528 处的 DLL 加载名称，不替换原版 steam_api.dll。

若更换编译器产生不同 DLL，必须审核产物后同步安装脚本的载荷哈希，不能取消校验。
