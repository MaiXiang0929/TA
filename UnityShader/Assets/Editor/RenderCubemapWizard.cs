using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

public class RenderCubeWizard : ScriptableWizard
{
    public Transform renderFromPosition; // 渲染起始位置的transform
    public Cubemap cubemap; // 目标立方体贴图资源

    private void OnWizardUpdate()
    {
        helpString = "Select transfrom to render from and cubemap to render into";
        isValid = (renderFromPosition != null) && (cubemap  != null);
    }

    private void OnWizardCreate()
    {
        GameObject go = new GameObject("CubemaoCamera"); // create temporary camera for rendering
        go.AddComponent<Camera>();

        go.transform.position = renderFromPosition.position; // place it on the object
        go.GetComponent<Camera>().RenderToCubemap(cubemap); // render into cubemap	

        DestroyImmediate(go); // destroy temporary camera
    }

    [MenuItem("GameObject/Render into Cubemap")]
    static void RenderCubemap()
    {
        ScriptableWizard.DisplayWizard<RenderCubeWizard>("Render cubemap", "Render");
    }
}
