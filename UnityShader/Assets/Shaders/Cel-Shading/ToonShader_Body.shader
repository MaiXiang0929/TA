Shader "Cel-Shading/ToonBody"
{
    Properties
    {
        [Header(Textures)]
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

        [Header(Specular)]
        [Toggle(_USE_SPECULAR)] _UseSpecular ("Enable Specular", Float) = 1
        _SpecularColor ("Specular Color", Color) = (1, 1, 1, 1)
        _Shininess ("Shininess", Range(8, 256)) = 32
        _SpecularThreshold ("Specular Threshold", Range(0, 1)) = 0.5 // 控制高光大小
        _SpecularSoftness ("Specular Softness", Range(0, 0.5)) = 0.05 // 控制高光边缘软硬
        // Metal Specular
        _MetalIntensity ("Metal Intensity", Range(0, 5)) = 1.0
        _MetalShininess ("Metal Shininess", Range(8, 512)) = 256 // 金属高光通常更聚集

        [Header(Lighting Options)]
        _DayOrNight ("Day Or Night", Range(0, 1)) = 0 // 日夜切换参数

        [Header(Screen Space Rim)]
        [Toggle(_USE_RIM)] _UseRim ("Enable Rim Light", Float) = 1 // 轮廓光开关
        _RimColor ("Rim Color", Color) = (1,1,1,1)
        _RimPower ("Rim Power", Range(0.5,8)) = 4
        _RimIntensity ("Rim Intensity", Range(0,5)) = 1
        _RimThreshold ("Rim Threshold", Range(0,1)) = 0.5

        [Header(Outline)]
        [Toggle(_USE_OUTLINE)] _UseOutline ("Enable Outline", Float) = 1 // 描边开关
        _OutlineColor ("Outline Color", Color) = (0, 0, 0, 1)
        _OutlineWidth ("Outline Width", Range(0, 5)) = 0.2
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType" = "Opaque"
        }

        HLSLINCLUDE // 公共代码块

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" // 核心库
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" // 光照库

            #pragma multi_compile_instancing // 启用GPU实例化编译

            CBUFFER_START(UnityPerMaterial) // 每材质常量缓冲区开始

                // Ramp Shadow
                float _ShadowRampWidth;
                float _ShadowPosition;
                float _ShadowSoftness;
                float _UseRampShadow2;
                float _UseRampShadow3;
                float _UseRampShadow4;
                float _UseRampShadow5;

                // Specular
                float4 _SpecularColor;
                float _Shininess;
                float _SpecularThreshold;
                float _SpecularSoftness;
                float _MetalIntensity;
                float _MetalShininess;

                // Lighting Options
                float _DayOrNight;

                // Screen Space Rim
                float4 _RimColor;
                float _RimPower;
                float _RimIntensity;
                float _RimThreshold;

            CBUFFER_END

            // Textures
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_LightMap);
            SAMPLER(sampler_LightMap);
            TEXTURE2D(_RampTex);
            SAMPLER(sampler_RampTex);

            half3 CalculateCelAdditionalLight(Light light, half3 N, half3 V, half3 baseColor, float metalMask)
            {
                // 计算光照分量
                half3 L = normalize(light.direction);
                half3 H = normalize(L + V);
                half NoL = dot(N, L);
                half NoH = saturate(dot(N, H));
                
                // 衰减系数 (距离衰减 * 阴影衰减)
                half attenuation = light.distanceAttenuation * light.shadowAttenuation;
                
                // 附加光漫反射 (卡通化)
                half diffStep = smoothstep(0.4, 0.45, NoL * 0.5 + 0.5);
                half3 diffuse = diffStep * baseColor;
                
                //  附加光高光 (卡通化)
                float specBase = pow(NoH, _Shininess);
                float specStep = smoothstep(_SpecularThreshold, _SpecularThreshold + _SpecularSoftness, specBase);
                half3 specColor = lerp(_SpecularColor.rgb, baseColor * _MetalIntensity, metalMask);
                half3 specular = specStep * specColor;

                // 综合光照颜色
                return (diffuse + specular) * light.color * attenuation;
            }
        
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
        
        Pass // 描边
        {
            Name "Outline"
            Tags { "LightMode" = "SRPDefaultUnlit" } // URP 默认未着色光照模式
            Cull Front // 剔除正面，只画背面
            ZWrite On

            HLSLPROGRAM
            #pragma vertex OutlineVertex
            #pragma fragment OutlineFragment
            #pragma shader_feature_local _USE_OUTLINE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            float _OutlineWidth;
            float4 _OutlineColor;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 color : COLOR; // 获取顶点色
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

            Varyings OutlineVertex(Attributes input)
            {
                Varyings output;
                
                #if _USE_OUTLINE
                    // 1. 转换到世界空间
                    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                    float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                    
                    // 2. 距离修正（让远近描边看起来粗细均匀）
                    float dist = distance(_WorldSpaceCameraPos, positionWS);
                    float width = _OutlineWidth * 0.01 * (dist * 0.1 + 1.0); 

                    // 3. 顶点色控制描边粗细 (使用顶点色 Alpha 通道)
                    width *= input.color.a; 

                    // 4. 沿法线挤出
                    positionWS += normalWS * width;
                    output.positionCS = TransformWorldToHClip(positionWS);
                #else
                    // 如果关闭描边，把顶点缩减到 0，不渲染
                    output.positionCS = float4(0, 0, 0, 0);
                #endif
                
                return output;
            }

            half4 OutlineFragment(Varyings input) : SV_TARGET
            {
                return _OutlineColor;
            }
            ENDHLSL
        }

        Pass // 主光照
        {
            Name "UniversalForward"
            Tags { "LightMode" = "UniversalForward" }

            Cull Off  // 不裁剪

            HLSLPROGRAM // 着色器程序
                
                // Main Light
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS // 主光源阴影
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE // 主光源阴影级联
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_SCREEN // 主光源阴影屏幕空间
                // Additional Light
                #pragma multi_compile _ _ADDITIONAL_LIGHTS            // 支持点光源/聚光灯
                #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS // 额外光源阴影
                // Rendering Feature
                #pragma multi_compile_fragment _LIGHT_LAYERS // 光照层
                #pragma multi_compile_fragment _LIGHT_COOKIES // 光照饼干
                #pragma multi_compile_fragment _SCREEN_SPACE_OCCLUSION // 屏幕空间遮挡
                #pragma multi_compile_fragment _SHADOWS_SOFT // 阴影软化   
                
                #pragma shader_feature_local _USE_LIGHTMAP_AO // A0开关
                #pragma shader_feature_local _USE_RAMP_SHADOW // 色阶阴影开关
                #pragma shader_feature_local _USE_SPECULAR // 高光开关
                #pragma shader_feature_local _USE_RIM // 轮廓光开关
                #pragma shader_feature_loca _USE_OUTLINE // 描边开关

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
                    float3 positionWS : TEXCOORD2;
                    float4 color : TEXCOORD3;
                };

                // 顶点着色器
                Varyings MainVertexShader(Attributes input)
                {
                    Varyings output;

                    // position
                    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                    output.positionCS = vertexInput.positionCS;
                    output.positionWS = vertexInput.positionWS;

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
                    float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                    Light light = GetMainLight(shadowCoord);
                    half4 vertexColor = input.color;

                    // Normalize Vector
                    half3 N = normalize(input.normalWS);
                    half3 L = normalize(light.direction);
                    half3 V = normalize(GetWorldSpaceViewDir(input.positionWS));
                    half3 H = normalize(L + V); // 半角向量
                    half NoL = dot(N, L);
                    half NoH = saturate(dot(N, H));
                    half NoV = saturate(dot(N, V));

                    // Texture Info
                    half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv0);
                    half4 lightMap = SAMPLE_TEXTURE2D(_LightMap,sampler_LightMap, input.uv0);

                    // Half Lambert
                    half halflambert = NoL * 0.5 + 0.5; // Half lambert (0, 1)
                    halflambert *= pow(halflambert, 2);
                    // 实时阴影乘入光照项
                    half shadowAttenuation = light.shadowAttenuation;
                    half combinedLight = halflambert * shadowAttenuation; 
                    half lambertstep = smoothstep(0.01, 0.4, combinedLight);
                    half shadowFactor = lerp(0, combinedLight, lambertstep);

                    // AO
                    #if _USE_LIGHTMAP_AO
                        half ambient = lightMap.g;
                    #else
                        half ambient = halflambert;
                    #endif
                    
                    half shadow = (ambient + combinedLight) * 0.5; // 环境光遮蔽
                    shadow = lerp(shadow, 1, step(0.95, ambient));
                    shadow = lerp(shadow, 0, step(ambient,0.05));

                    half isShadowArea = step(shadow, _ShadowPosition);
                    half shadowDepth = saturate((_ShadowPosition - shadow) / _ShadowPosition);
                    shadowDepth = pow(shadowDepth, _ShadowSoftness);
                    shadowDepth = min(shadowDepth, 1);
                    half rampWidthFactor = vertexColor.g * 2 * _ShadowRampWidth;
                    half shadowPosition = (_ShadowPosition - shadowFactor) / _ShadowPosition;

                    // Ramp
                    half rampU = 1 - saturate(shadowDepth / max(0.001, rampWidthFactor));
                    half rampID = RampShadowID(lightMap.a, _UseRampShadow2, _UseRampShadow3, _UseRampShadow4, _UseRampShadow5, 1, 2, 3, 4, 5);
                    half rampV = 0.45 - (rampID - 1) * 0.1;
                    half2 rampDayUV = half2(rampU, rampV + 0.5);
                    half3 rampDayColor = SAMPLE_TEXTURE2D(_RampTex,sampler_RampTex, rampDayUV).rgb;
                    half2 rampNightUV = half2(rampU, rampV);
                    half3 rampNightColor = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, rampNightUV).rgb;
                    half3 rampColor = lerp(rampDayColor, rampNightColor, _DayOrNight);

                    // Merge Color
                    #if _USE_RAMP_SHADOW
                        half3 finalColor = baseMap.rgb * rampColor * (isShadowArea ? 1 : 1.2);
                    #else
                        half3 finalColor = baseMap.rgb * combinedLight * (shadow + 0.2);
                    #endif

                    // Specular
                    half3 finalSpecular = half3(0, 0, 0);
                    #if _USE_SPECULAR
                        //获取金属度遮罩 (从 LightMap 的 R 通道读取)    
                        float metalMask = lightMap.r;
                        // 基础 Blinn-Phong 高光
                        float specBase = pow(NoH, _Shininess);
                        // 卡通化处理：通过 smoothstep 限制高光范围，使其边缘变硬
                        // 使用 _SpecularThreshold 控制高光区域大小
                        float specStep = smoothstep(_SpecularThreshold, _SpecularThreshold + _SpecularSoftness, specBase);
                        half3 regularSpec = specStep * _SpecularColor.rgb;

                        // 金属高光(特点：高倍率 Shininess，且颜色受 BaseMap 影响)
                        float metalSpecBase = pow(NoH, _MetalShininess);
                        float metalSpecStep = smoothstep(_SpecularThreshold, _SpecularThreshold + _SpecularSoftness, metalSpecBase);
                        // 金属高光的颜色 = 基础贴图颜色 * 强度
                        half3 metalSpecColor = baseMap.rgb * _MetalIntensity; 
                        half3 metalSpec = metalSpecStep * metalSpecColor;

                        // 根据遮罩混合两种高光
                        finalSpecular = lerp(regularSpec, metalSpec, metalMask);
                        
                        // 结合光照信息 高光通常只在受光面出现 (NoL > 0)
                        finalSpecular *= light.color * light.distanceAttenuation * step(0.001, NoL);
                    #endif

                    //Rim Light
                    half3 rimLight = half3(0, 0, 0); // 初始化为0
                    #if _USE_RIM
                        float rim = pow(1 - NoV, _RimPower);
                        float backLight = step(0, -dot(N, L));
                        rim *= backLight;
                        rim = smoothstep(_RimThreshold, 1, rim);
                        rim *= shadow;

                        rimLight = rim * backLight * _RimColor.rgb * _RimIntensity;
                    #endif

                    finalColor += finalSpecular;
                    finalColor += rimLight;

                    // Additional Light 
                    #if defined(_ADDITIONAL_LIGHTS)
                        // 获取当前像素受影响的附加光数量
                        uint pixelLightCount = GetAdditionalLightsCount();
                        
                        for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
                        {
                            // 获取附加光信息
                            Light addLight = GetAdditionalLight(lightIndex, input.positionWS, shadowCoord);
                            
                            // 累加附加光贡献
                            finalColor += CalculateCelAdditionalLight(addLight, N, V, baseMap.rgb, lightMap.r);
                        }
                    #endif

                    return float4(finalColor, 1);
                }
                
            ENDHLSL
        }

        Pass // 渲染通道 阴影渲染
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster" // 光照模式：阴影投射
            }

            ZWrite  On // 写入深度缓冲区
            ZTest LEqual  // 深度测试：小于等于
            ColorMask 0 // 不写入颜色缓冲区
            Cull Off  // 不裁剪

            HLSLPROGRAM

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
