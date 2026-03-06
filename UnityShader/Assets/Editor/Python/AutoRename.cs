using UnityEditor;
using UnityEditor.Scripting.Python;
using UnityEngine;
using System.IO;
using System.Text;

public class MenuItem_AutoRename_Class
{
    [MenuItem("Assets/TA Tools/Auto Rename Materials")]
    public static void AutoRenameSelected()
    {
        string scriptPath = "Assets/Editor/Python/AutoRename.py";

        // 检查文件是否存在
        if (!File.Exists(scriptPath))
        {
            Debug.LogError($"[TA] Script not found at: {scriptPath}");
            return;
        }

        try
        {
            // --- 核心修复步骤 ---
            // 1. 强制使用 UTF-8 编码读取文件内容为字符串
            string scriptContent = File.ReadAllText(scriptPath, Encoding.UTF8);

            // 2. 使用 RunString 代替 RunFile
            // RunString 会直接处理内存中的字符串，不会再触发文件流读取的 GBK 错误
            PythonRunner.RunString(scriptContent);
            
            Debug.Log("[TA] Python script executed via UTF-8 string.");
        }
        catch (System.Exception e)
        {
            Debug.LogError($"[TA] Failed to execute python script: {e.Message}");
        }
    }
}
