using System;
using UnityEngine;

[ExecuteInEditMode]
public class ProceduralTextureGeneration : MonoBehaviour
{
    public Material material = null;

    #region Material properties
    [SerializeField, SetProperty("textureWidth")]
    private int m_textureWidth = 512;
    public int textureWidth
    {
        get { return m_textureWidth; }
        set
        {
            m_textureWidth = value;
            _UpdateMaterial();
        }
    }

    [SerializeField, SetProperty("backgroundColor")]
    private Color m_backgroundColor = Color.white;
    public Color backgroundColor
    {
        get { return m_backgroundColor; }
        set
        {
            m_backgroundColor = value;
            _UpdateMaterial();
        }
    }

    [SerializeField, SetProperty("circleColor")]
    private Color m_circleColor = Color.yellow;
    public Color circleColor
    {
        get { return m_circleColor; }
        set
        {
            m_circleColor = value;
            _UpdateMaterial();
        }
    }

    [SerializeField, SetProperty("blurFactor")]
    private float m_blurFactor = 2.0f;
    public float blurFactor
    {
        get { return m_blurFactor; }
        set
        {
            m_blurFactor = value;
            _UpdateMaterial();
        }
    }
    #endregion

    private Texture2D m_generatedTexture = null;

    void Start()
    {
        if (material == null)
        {
            Renderer renderer = gameObject.GetComponent<Renderer>();
            if (renderer == null)
            {
                Debug.LogWarning("Cannot find a renderer.");
            }

            material = renderer.sharedMaterial;
        }

        _UpdateMaterial();
    }

    private void _UpdateMaterial()
    {
        if (material != null)
        {
            // 如果旧纹理存在，先销毁它释放内存，防止内存泄漏
            if (m_generatedTexture != null)
            {
                if (Application.isPlaying) Destroy(m_generatedTexture);
                else DestroyImmediate(m_generatedTexture);
            }
            m_generatedTexture = _GenerateProceduralTexture();
            m_generatedTexture.hideFlags = HideFlags.DontSave;
            material.SetTexture("_MainTex", m_generatedTexture);
        }
    }

    private Texture2D _GenerateProceduralTexture()
    {
        Texture2D proceduralTexture = new Texture2D(textureWidth, textureWidth);

        float circleInterval = textureWidth / 4.0f; // 定义圆与圆之间的间距
        float radius = textureWidth / 10.0f; // 定义圆的半径
        float edgeBlur = 1.0f / blurFactor; // 定义模糊系数

        for (int w = 0; w < textureWidth; w++)
        {
            for (int h = 0; h < textureWidth; h++)
            {
                Color pixel = backgroundColor;

                for (int i = 0; i < 3; i++)
                {
                    for (int j = 0; j < 3; j++)
                    {
                        Vector2 circleCenter = new Vector2(circleInterval * (i +1), circleInterval * (j +1));
                        float dist= Vector2.Distance(new Vector2(w, h), circleCenter) - radius;
                        Color color = _MixColor(circleColor, new Color(pixel.r, pixel.g, pixel.b, 0.0f), Mathf.SmoothStep(0f, 1.0f, dist * edgeBlur));

                        pixel = _MixColor(pixel, color, color.a);
                    }
                }

                proceduralTexture.SetPixel(w, h, pixel);
            }
        }

        proceduralTexture.hideFlags = HideFlags.DontSave; // 核心：防止保存场景时被清理
        proceduralTexture.Apply();

        return proceduralTexture;
    }

    private Color _MixColor(Color c1, Color c2, float t)
    {
        return Color.Lerp(c1, c2, t);
    }

    void Update()
    {
        // 如果是编辑模式，且材质丢失了纹理，重新赋一遍值
        if (!Application.isPlaying && material != null && material.GetTexture("_MainTex") == null)
        {
            _UpdateMaterial();
        }
    }
}