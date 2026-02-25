Shader "Toon/Body"
{
    Properties
    {
        [Header(Texture)]
        _BaseMap ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags
        {
            "RenderPipleLine" = "UniversalRenderPipleLine"
            "RenderType" = "Opaque"
        }

        HLSLINCLUDE // 公共代码块
        
            #pragma multi_compile _MAIN_LIGHT_SHADOWS // 主光源阴影
            #pragma multi_compile _MAIN_LIGHT_SHADOWS_CASCADE // 主光源阴影级联
            #pragma multi_compile _MAIN_LIGHT_SHADOWS_SCREEN // 主光源阴影屏幕空间

            #pragma multi_compile_fragment _LIGHT_LAYERS // 光照层
            #pragma multi_compile_fragment _LIGHT_COOKIES // 光照饼干
            #pragma multi_compile_fragment _SCREEN_SPACE_OCCLUSION // 屏幕空间遮挡
            #pragma multi_compile_fragment _ADDITIONAL_LIGHT_SHADOWS // 额外光源阴影
            #pragma multi_compile_fragment _SHADOWS_SOFT // 阴影软化
            #pragma multi_compile_fragment _REFLECTION_PROBE_BLENDING // 反射探针混合
            #pragma multi_compile_fragment _REFLECTION_PROBE_BOX_PROJECTION // 反射探针盒投影

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" // 核心库
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" // 光照库

            CBUFFER_START(UnityPerMaterial) // 每材质常量缓冲区开始

                sampler2D _BaseMap;

            CBUFFER_END
        
        ENDHLSL

        Pass
        {
            Name "UniversalForward"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM // 着色器程序
                
                #pragma vertex MainVertexShader // 顶点着色器入口
                #pragma fragment MainFragmentShader // 片元着色器入口
                
                // 顶点着色器输入参数
                struct Attributes
                {
                    float4 positionOS : POSITION;
                    float2 uv0 : TEXCOORD0;
                    float3 normalOS : NORMAL;
                };

                // 片元着色器输入参数
                struct Varyings
                {
                    float4 positionCS : SV_POSITION;
                    float2 uv0 : TEXCOORD0;
                    float3 normalWS : TEXCOORD1;
                };

                // 顶点着色器
                Varyings MainVertexShader(Attributes input)
                {
                    Varyings output;

                    // position
                    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                    output.positionCS = vertexInput.positionCS;

                    // normal
                    VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(input.normalOS);
                    output.normalWS = vertexNormalInput.normalWS;

                    // uv
                    output.uv0 = input.uv0;

                    return output;
                }

                // 片元着色器
                float4 MainFragmentShader(Varyings input) : SV_TARGET
                {
                    Light light = GetMainLight();

                    // Normalize Vector
                    half3 N = normalize(input.normalWS);
                    half3 L = normalize(light.direction);
                    half NoL = dot(N, L);

                    // Texture Info
                    float4 baseMap = tex2D(_BaseMap, input.uv0);

                    // Lambert
                    half lambert = NoL; // Lambert (-1, 1)
                    half halflambert = lambert * 0.5 + 0.5; // Half lambert (0, 1)
                    halflambert *= pow(halflambert, 2);

                    // Merge Color
                    float3 finalColor = baseMap.rgb * halflambert;

                    return float4(finalColor, 1);
                }

            ENDHLSL
        }
    }
}
