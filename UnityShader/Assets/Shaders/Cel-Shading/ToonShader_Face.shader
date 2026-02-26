Shader "Cel-Shading/ToonFace"
{
    Properties
    {
        [Header(Textures)]
        _BaseMap ("Base Map", 2D) = "white" {}

        [Header(Shadow Options)]
        [Toggle(_USE_SDF_SHADOW)] _UseSDFShadow ("Use SDF Shadow", Range(0, 1)) = 1 // SDF开关
        _SDF ("SDF", 2D) = "white" {} // 距离场纹理
        _ShadowMask ("Shadow Mask", 2D) = "white" {} // 阴影遮罩
        _ShadowColor ("Shadow Color", Color) = (1, 0.87, 0.87, 1) // 阴影颜色

        [Header(Head Direction)]
        [HideInInspector] _HeadForward ("Head Forward", Vector) = (0, 0, 1, 0) // 面部前方
        [HideInInspector] _HeadRight ("Head Right", Vector) = (1, 0, 0, 0) // 面部右侧
        [HideInInspector] _HeadUp ("Head Up", Vector) = (0, 1, 0, 0) // 面部上方
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

            #pragma shader_feature_local _USE_SDF_SHADOW // SDF开关

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" // 核心库
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" // 光照库

            CBUFFER_START(UnityPerMaterial) // 每材质常量缓冲区开始

                // Textures
                sampler2D _BaseMap;

                // Shadow Options
                sampler2D _SDF;
                sampler2D _ShadowMask;
                float4 _ShadowColor;

                // Head Direction
                float3 _HeadForward;
                float3 _HeadRight;
                float3 _HeadUp;

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
                    half3 headForwardDir = normalize(_HeadForward);
                    half3 headRightDir = normalize(_HeadRight);
                    half3 headUpDir = normalize(_HeadUp);

                    // Texture Info
                    half4 baseMap = tex2D(_BaseMap, input.uv0);
                    half4 shadowMask = tex2D(_ShadowMask, input.uv0);

                    // Lambert
                    half lambert = NoL; // Lambert (-1, 1)
                    half halflambert = lambert * 0.5 + 0.5; // Half lambert (0, 1)
                    halflambert *= pow(halflambert, 2);

                    // Face Shadow
                    half3 LpU = dot(L, headUpDir) / pow(length(headUpDir), 2) * headUpDir; // 计算光源方向在面部上方的投影
                    half3 LpHeadHorizon = normalize(L- LpU); // 光照方向在头部水平面上的投影
                    half value = acos(dot(LpHeadHorizon, headRightDir)) / 3.141592654; // 计算光照方向与面部右方的夹角
                    half exposeRight = step(value, 0.5); // 判断光照是来自右侧还是左侧
                    half valueR = pow(1 - value * 2, 3); // 右侧阴影强度
                    half valueL = pow(value * 2 - 1, 3); // 左侧阴影强度
                    half mixValue = lerp(valueL, valueR, exposeRight); // 混合阴影强度
                    half sdfLeft = tex2D(_SDF, half2(1 - input.uv0.x, input.uv0.y)).r; // 左侧距离场
                    half sdfRight = tex2D(_SDF, input.uv0).r; // 右侧距离场
                    half mixSdf = lerp(sdfLeft, sdfRight, exposeRight); // 采样SDF纹理
                    half sdf = step(mixValue, mixSdf); // 计算硬边界阴影
                    sdf = lerp(0, sdf, step(0, dot(LpHeadHorizon, headForwardDir))); // 计算右侧阴影
                    sdf *= shadowMask.g; // 使用G通道控制阴影强度
                    sdf = lerp(sdf, 1, shadowMask.a); // 使用A通道作为阴影遮罩

                    // Merge Color
                    #if _USE_SDF_SHADOW
                        half3 finalColor = lerp(_ShadowColor.rgb * baseMap.rgb, baseMap.rgb, sdf);
                    #else
                        half3 finalColor = baseMap.rgb * halflambert;
                    #endif

                    return float4(finalColor, 1);
                }

            ENDHLSL
        }
    }
}
