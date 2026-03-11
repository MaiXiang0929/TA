using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using SetPropertyExample;

[ExecuteInEditModel]
public class ProceduralTextureGeneration : MonoBehaviour
{
    public Material material = null;

    #region Material properties
    [SerializeField, SetProperty("textureWidth")]
    private int m_textureWidth = 512;
    public int textureWidth {}

    #endregion
}
