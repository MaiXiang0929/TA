Shader "Toon/Body"
{
    Properties
    {
        [Header(Texture)]
        _BaseMap ("Base Map", 2D) = "white" {}
        _LightMap ("Light Map", 2D) = "white" {}
        [Toggle(_USE_LIGHTMAP_AO)] _UseLightMapAO ("Use LightMap AO", Range(0, 1)) = 1 // AO开关

        [Header(Ramp Shaodw)]
        _RampTex ("Ramp Tex", 2D) = "white" {} // 色阶阴影贴图
        [Toggle(_USE_RAMP_SHADOW)] _UseRampShadow ("Use Ramp Shadow", Range(0, 1)) = 1 // 色阶阴影开关
        _ShadowRampWidth ("Shadow Ramp Width", float) = 1
        _ShadowPosition ("Shadow Position", float) = 0.55
        _ShadowSoftness ("_ShadowSoftness", float) = 0.5
        [Toggle] _UseRampShadow2 ("Use Ramp Shadow 2", Range(0, 1)) = 1 // 使用第2行Ramp阴影开关
        [Toggle] _UseRampShadow3 ("Use Ramp Shadow 3", Range(0, 1)) = 1 // 使用第3行Ramp阴影开关
        [Toggle] _UseRampShadow4 ("Use Ramp Shadow 4", Range(0, 1)) = 1 // 使用第4行Ramp阴影开关
        [Toggle] _UseRampShadow5 ("Use Ramp Shadow 5", Range(0, 1)) = 1 // 使用第5行Ramp阴影开关

        [Header(Lighting Options)]
        _DayOrNight ("Day Or Night", Range(0, 1)) = 0 // 日夜切换参数
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
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

            #pragma shader_feature_local _USE_LIGHTMAP_AO // A0开关
            #pragma shader_feature_local _USE_RAMP_SHADOW // 色阶阴影开关

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" // 核心库
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" // 光照库

            CBUFFER_START(UnityPerMaterial) // 每材质常量缓冲区开始

                // Textures
                sampler2D _BaseMap;
                sampler2D _LightMap;


                // Ramp Shadow
                sampler2D _RampTex;
                float _ShadowRampWidth;
                float _ShadowPosition;
                float _ShadowSoftness;
                float _UseRampShadow2;
                float _UseRampShadow3;
                float _UseRampShadow4;
                float _UseRampShadow5;

                // Lighting Options
                float _DayOrNight;

            CBUFFER_END
        
            // 官方版本的RampShadowID函数
            float RampShadowID(float input, float useShadow2, float useShadow3, float useShadow4, float useShadow5, 
                float shadowValue1, float shadowValue2, float shadowValue3, float shadowValue4, float shadowValue5)
            {
                // 根据input值将模型分为5个区域
                float v1 = step(0.6, input) * step(input, 0.8); // 0.6-0.8区域
                float v2 = step(0.4, input) * step(input, 0.6); // 0.4-0.6区域
                float v3 = step(0.2, input) * step(input, 0.4); // 0.2-0.4区域
                float v4 = step(input, 0.2);                    // 0-0.2区域

                // 根据开关控制是否使用不同材质的值
                float blend12 = lerp(shadowValue1, shadowValue2, useShadow2);
                float blend15 = lerp(shadowValue1, shadowValue5, useShadow5);
                float blend13 = lerp(shadowValue1, shadowValue3, useShadow3);
                float blend14 = lerp(shadowValue1, shadowValue4, useShadow4);

                // 根据区域选择对应的材质值
                float result = blend12;                // 默认使用材质1或2
                result = lerp(result, blend15, v1);    // 0.6-0.8区域使用材质5
                result = lerp(result, blend13, v2);    // 0.4-0.6区域使用材质3
                result = lerp(result, blend14, v3);    // 0.2-0.4区域使用材质4
                result = lerp(result, shadowValue1, v4); // 0-0.2区域使用材质1

                return result;
            }

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
                    float4 color : COLOR0;
                };

                // 片元着色器输入参数
                struct Varyings
                {
                    float4 positionCS : SV_POSITION;
                    float2 uv0 : TEXCOORD0;
                    float3 normalWS : TEXCOORD1;
                    float color : TEXCOORD2;
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

                    // color
                    output.color = input.color;

                    return output;
                }

                // 片元着色器
                half4 MainFragmentShader(Varyings input) : SV_TARGET
                {
                    Light light = GetMainLight();
                    half4 vertexColor = input.color;

                    // Normalize Vector
                    half3 N = normalize(input.normalWS);
                    half3 L = normalize(light.direction);
                    half NoL = dot(N, L);

                    // Texture Info
                    half4 baseMap = tex2D(_BaseMap, input.uv0);
                    half4 lightMap = tex2D(_LightMap, input.uv0);

                    // Lambert
                    half lambert = NoL; // Lambert (-1, 1)
                    half halflambert = lambert * 0.5 + 0.5; // Half lambert (0, 1)
                    halflambert *= pow(halflambert, 2);
                    half lambertstep = smoothstep(0.01, 0.4, halflambert);
                    half shadowFactor = lerp(0, halflambert, lambertstep);

                    // AO
                    #if _USE_LIGHTMAP_AO
                        half ambient = lightMap.g;
                    #else
                        half ambient = halflambert;
                    #endif
                    half shadow = (ambient + halflambert) * 0.5; // 环境光遮蔽
                    shadow = lerp(shadow, 1, step(0.95, ambient));
                    shadow = lerp(shadow, 0, step(ambient,0.05));
                    half isShadowArea = step(shadow, _ShadowPosition);
                    half shadowDepth = saturate((_ShadowPosition - shadow) / _ShadowPosition);
                    shadowDepth = pow(shadowDepth, _ShadowSoftness);
                    shadowDepth = min(shadowDepth, 1);
                    half rampWidthFactor = vertexColor.g * 2 * _ShadowRampWidth;
                    half shadowPosition = (_ShadowPosition - shadowFactor) / _ShadowPosition;

                    // Ramp
                    half rampU = 1 - saturate(shadowDepth / rampWidthFactor);
                    half rampID = RampShadowID(lightMap.a, _UseRampShadow2, _UseRampShadow3, _UseRampShadow4, _UseRampShadow5, 1, 2, 3, 4, 5);
                    half rampV = 0.45 - (rampID - 1) * 0.1;
                    half2 rampDayUV = half2(rampU, rampV + 0.5);
                    half3 rampDayColor = tex2D(_RampTex, rampDayUV);
                    half2 rampNightUV = half2(rampU, rampV);
                    half3 rampNightColor = tex2D(_RampTex, rampNightUV);
                    half3 rampColor = lerp(rampDayColor, rampNightColor, _DayOrNight);

                    // Merge Color
                    #if _USE_RAMP_SHADOW
                        half3 finalColor = baseMap.rgb * rampColor * (isShadowArea ? 1 : 1.2);
                    #else
                        half3 finalColor = baseMap.rgb * halflambert * (shadow + 0.2);
                    #endif

                    return float4(finalColor.rgb, 1);
                }
                
            ENDHLSL
        }

        Pass // 渲染通道 阴影渲染
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            Zwrite  On 
            ZTest LEqual 
            ColorMask 0
            Cull Off 

            HLSLPROGRAM

                #pragma multi_compile_instancing // 启用GPU实例化编译
                #pragma multi_compile _ DOTS_INSTANCING_ON // 启用DOTS实例化编译
                #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW // 启用点光源阴影

                #pragma vertex ShadowVertexShader // 顶点着色器入口
                #pragma fragment ShadowFragmentShader // 片元着色器入口

                float3 _LightDirection;
                float3 _LightPosition;

                // 顶点着色器输入参数
                struct Attributes 
                {
                    float4 positionOS : POSITION;
                    float3 normalOS : NORMAL;
                };

                // 片元着色器输入参数
                struct Varyings
                {
                    float4 positionCS : SV_POSITION;
                };


                // 将阴影的世界空间顶点位置转换为适合阴影投射的裁剪空间位置
                half4 GetShadowPositionHClip(Attributes input)
                {
                    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz); // 将本地空间顶点坐标转换为世界空间顶点坐标
                    float3 normalWS = TransformObjectToWorldNormal(input.normalOS); // 将本地空间法线转换为世界空间法线

                    #if _CASTING_PUNCTUAL_LIGHT_SHADOW // 点光源
                        float3 lightDirectionWS = normalize(_LightPosition - positionWS); // 计算光源方向
                    #else // 平行光
                        float3 lightDirectionWS = _LightDirection; // 使用预定义的光源方向
                    #endif

                    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS)); // 应用阴影偏移

                    // 根据平台的Z缓冲区方向调整Z值
                    #if UNITY_REVERSED_Z // 反转Z缓冲区
                        positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE); // 限制Z值在近裁剪平面以下
                    #else // 正向Z缓冲区
                        positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE); // 限制Z值在远裁剪平面以上
                    #endif

                    return positionCS; // 返回裁剪空间顶点坐标
                }

                // 顶点着色器
                Varyings ShadowVertexShader(Attributes input)
                {
                    Varyings output;
                    output.positionCS = GetShadowPositionHClip(input);
                    return output;
                }

                // 片元着色器
                half4 ShadowFragmentShader(Varyings input) : SV_TARGET
                {
                    return 0;
                }

            ENDHLSL
        }
        
    }
    FallBack "Universal Render Pipeline/Lit"
}
