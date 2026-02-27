// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'


Shader "Custom/ShaderBase/Chapter5/SimpleShader"
{
    Properties
    {
        _Color("Color Tint", Color) = (1.0, 1.0, 1.0, 1.0)
    }
    
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline" 
        }

        HLSLINCLUDE

            // URP核心库
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            // 材质属性声明在CBUFFER中（SRP Batcher兼容性）
            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
            CBUFFER_END

        ENDHLSL

        Pass
        {
            Tags { "LightMode" = "UniversalForward" }  // URP前向渲染

            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
               
            // 输入结构（原a2v）
            struct Attributes
            {
                float4 positionOS : POSITION;    // OS = Object Space
                float3 normalOS : NORMAL;
                float2 texcoord : TEXCOORD0;     // 保留但本例未使用
            };
            
            // 输出结构（原v2f）
            struct Varyings
            {
                float4 positionCS : SV_POSITION; // CS = Clip Space
                float3 color : COLOR0;
            };
            
            // 顶点着色器
            Varyings vert(Attributes input)
            {
                Varyings output;
                
                // URP坐标转换：模型空间 → 裁剪空间
                // position
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInput.positionCS;
                
                // 法线可视化（和原逻辑一致）
                output.color = input.normalOS * 0.5 + float3(0.5, 0.5, 0.5);
                
                return output;
            }
            
            // 片元着色器
            float4 frag(Varyings input) : SV_Target
            {
                float3 c = input.color;
                c *= _Color.rgb;
                return float4(c, 1.0);
            }
            
            ENDHLSL
        }
    }
    FallBack "Universal Render Pipeline/Unlit"
}
