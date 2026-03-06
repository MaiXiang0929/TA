print("--- PYTHON START ---")
import os
from UnityEditor import AssetDatabase, Selection

def fix_selected_material_prefixes():

    is_confirmed = EditorUtility.DisplayDialog(
        "TA Rename Tool", 
        "你确定要重命名选中文件夹下的所有材质球吗？", 
        "确定", 
        "取消"
    )
    
    if not is_confirmed:
        print("[TA] Operation cancelled by user.")
        return
    
    selected_guids = Selection.assetGUIDs
    print("Selected GUIDs Count: " + str(len(selected_guids)))
    
    if not selected_guids:
        print("[TA] Error: No selection detected by Python!")
        return

    renamed_count = 0
    
    for folder_guid in selected_guids:
        folder_path = AssetDatabase.GUIDToAssetPath(folder_guid)
        print("Processing Folder: " + folder_path) 
        

        guids = AssetDatabase.FindAssets("t:Material", [folder_path])
        print("Materials found in this folder: " + str(len(guids)))
        
        for guid in guids:
            path = AssetDatabase.GUIDToAssetPath(guid)
            if not path.lower().endswith(".mat"):
                continue
                
            filename = os.path.basename(path)
            if not filename.startswith("M_"):
                new_name = "M_" + filename
                error = AssetDatabase.RenameAsset(path, new_name)
                if not error:
                    renamed_count += 1
                else:
                    print("Rename Error: " + error)

    if renamed_count > 0:
        AssetDatabase.SaveAssets()
        AssetDatabase.Refresh()
    
    print("TA Task: Renamed " + str(renamed_count) + " materials.")

print("--- PYTHON START ---")
fix_selected_material_prefixes()