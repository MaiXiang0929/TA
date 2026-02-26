using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 设置面部材质的方向向量
/// </summary>
[ExecuteInEditMode]
public class SetFaceMaterialVector : MonoBehaviour
{
    public Transform Head;
    public Transform HeadForward;
    public Transform HeadRight;
    public Transform HeadUp;
    public Material FaceMaterial;

    void Update()
    {
        if (FaceMaterial != null && Head != null && HeadForward != null && HeadRight != null && HeadUp != null)
        {
            Vector3 headForward = (HeadForward.position - Head.position).normalized;
            Vector3 headRight = (HeadRight.position - Head.position).normalized;
            Vector3 headUp = (HeadUp.position - Head.position).normalized;
            FaceMaterial.SetVector("_HeadForward", headForward);
            FaceMaterial.SetVector("_HeadRight", headRight);
            FaceMaterial.SetVector("_HeadUp", headUp);
        }
    }
}
