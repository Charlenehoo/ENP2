#!/usr/bin/env python3
import os
import sys


def main():
    # 检查参数数量
    if len(sys.argv) < 3:
        print("Usage: python script.py <base_dir> <extension>")
        print("Example: python script.py /path/to/project lua")
        sys.exit(1)

    base_dir = os.path.abspath(sys.argv[1].strip())
    ext = sys.argv[2].strip().lower()

    # 验证目录是否存在
    if not os.path.isdir(base_dir):
        print(f"Error: Directory '{base_dir}' does not exist or is not a directory")
        sys.exit(1)

    # 处理扩展名（移除开头的点并转为小写）
    if ext.startswith("."):
        ext = ext[1:]

    if not ext:
        print("Error: Extension cannot be empty")
        sys.exit(1)

    print(f"Scanning for .{ext} files in {base_dir}...\n")

    # 遍历所有文件
    for root, _, files in os.walk(base_dir):
        for file in files:
            # 检查文件扩展名（不区分大小写）
            if os.path.splitext(file)[1][1:].lower() == ext:
                file_path = os.path.join(root, file)
                rel_path = os.path.relpath(file_path, base_dir)
                # 统一使用正斜杠（兼容 Windows/Mac/Linux）
                rel_path = rel_path.replace("\\", "/")

                # 打印 Markdown 格式标题
                print(f"# ./{rel_path}")
                print(f"```{ext}")

                # 读取并打印文件内容
                try:
                    with open(file_path, "r", encoding="utf-8") as f:
                        # 确保内容结尾有换行符
                        content = f.read()
                        if not content.endswith("\n"):
                            content += "\n"
                        print(content, end="")
                except Exception as e:
                    print(f"ERROR: Failed to read file - {str(e)}")
                    print("```\n")  # 确保错误后仍有代码块结束
                    continue

                print("```\n")  # 结束代码块并添加空行


if __name__ == "__main__":
    main()
