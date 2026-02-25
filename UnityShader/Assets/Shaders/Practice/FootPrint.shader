Shader "Custom/Practice/FootprintLineBox"
{
    Properties
    {
        _FootprintTex ("Footprint Texture", 2D) = "white" {}
        _FootprintColor ("Footprint Color", Color) = (1,1,1,1)
        _FootprintSize ("Footprint Size", Range(0.1, 2)) = 1.0 
        _DistPerFootprint ("Distance Per Footprint", Range(0.1, 10)) = 1.0 
        _Spacing ("Footprint Spacing", Range(0.01, 0.99)) = 0.5 
        _LineWidth ("Line Width", Range(0.1, 1)) = 0.5 
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "RenderPipeline"="UniversalPipeline" }
        Blend SrcAlpha OneMinusSrcAlpha 
        ZWrite Off 

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float worldScaleX : TEXCOORD1; 
                float3 normalWS : TEXCOORD2;
            };

            sampler2D _FootprintTex;
            float4 _FootprintTex_ST;
            float4 _FootprintColor;
            float _FootprintSize;
            float _DistPerFootprint; 
            float _Spacing;
            float _LineWidth;

            Varyings vert (Attributes input)
            {
                Varyings output;
                output.positionHCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;

                // 获取模型在 X 轴向的世界缩放
                float3 worldXDir = float3(GetObjectToWorldMatrix()[0].x, GetObjectToWorldMatrix()[1].x, GetObjectToWorldMatrix()[2].x);
                output.worldScaleX = length(worldXDir);

                output.normalWS = TransformObjectToWorldNormal(input.normalOS);

                return output;
            }

            half4 frag (Varyings input) : SV_Target
            {
                // 判断是否是顶部面（世界空间法线朝上，即 Y 分量接近 1）
                float isTopFace = step(0.9, input.normalWS.y); // 法线Y>0.9则判定为顶部面
                if (isTopFace < 0.5) {
                    discard; // 不是顶部面，直接丢弃像素（透明）
                }
                
                //  计算总共可以容纳多少个完整的足迹单元
                float unitDist = _DistPerFootprint * _FootprintSize;
                float totalUnits = input.worldScaleX / unitDist;
                float fullUnitsCount = floor(totalUnits); // 取整，得到完整足迹的数量

                // 当前像素在重复序列中的位置
                float currentRepeatPos = input.uv.x * totalUnits;
                
                // 舍弃不完整的足迹
                // 如果当前位置超过了完整足迹的总数，则遮罩设为 0
                float completeMask = step(currentRepeatPos, fullUnitsCount);

                // 计算单个足迹内的局部 UV
                float localX = frac(currentRepeatPos);
                
                // 间隔
                float footprintMask = step(_Spacing, localX); 
                float correctedX = (localX - _Spacing) / (1.0 - _Spacing);
                
                // 宽度控制 (V方向)
                float correctedY = (input.uv.y - 0.5) / _LineWidth + 0.5;
                float2 finalUV = float2(correctedX, correctedY);
                
                half4 footprint = tex2D(_FootprintTex, finalUV * _FootprintTex_ST.xy + _FootprintTex_ST.zw);
                
                float edgeMask = step(0, correctedY) * step(correctedY, 1);
                float finalAlphaMask = edgeMask * footprintMask * completeMask;
                
                half4 finalColor = footprint * _FootprintColor;
                finalColor.a *= finalAlphaMask;

                return finalColor;
            }
            ENDHLSL
        }
    }
    FallBack "Universal Render Pipeline/Unlit"
}