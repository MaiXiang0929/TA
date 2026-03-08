Shader "Custom/ShaderBase/Standard/BumpedDiffuse"
{
    Properties
    {
        _BaseColor("Base Color", Color) = (1,1,1,1)
        _BaseMap("Albedo (RGB)", 2D) = "white" {}
        [Normal] _NormalMap("Normal Map", 2D) = "bump" {}
        // "bump"默认颜色(0.5, 0.5, 1.0)  解压后法线向量(0, 0, 1)  视觉效果：平滑、圆润（正常）  "normal"可能为 (1, 1, 1) 或其他    解压后法线向量(1, 1, 1)或偏差值    视觉效果拉伸、扭曲、断裂
    }
    SubShader
    {
        Tags
        { 
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue"="Geometry"
        }

        HLSLINCLUDE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _BaseMap_ST;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float4 tangentWS : TEXCOORD3; // xyz: tangentWS, w: bitangent sign
            };

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                // Position
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInput.positionCS;
                output.positionWS = vertexInput.positionWS;

                // Normal
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                output.normalWS = normalInput.normalWS;
                output.tangentWS = float4(normalInput.tangentWS, input.tangentOS.w);
                
                // UV
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);

                return output;
            }

            half3 DirectLightLambert(Light light, half3 normalWS, half3 albedo)
            {
                half3 lightDirWS = normalize(light.direction);

                // Diffuse
                float diff = saturate(dot(normalWS, lightDirWS));
                half3 diffuse = light.color * albedo * diff;

                half3 lambert = diffuse * light.distanceAttenuation * light.shadowAttenuation;

                return lambert;
            }

        ENDHLSL

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM

                #pragma vertex vert
                #pragma fragment frag

                // Variant Keywords
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE // 无阴影/普通阴影/级联阴影
                #pragma multi_compile _ _ADDITIONAL_LIGHTS // 像素级附加光照开关
                #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS // 附加光源阴影开关
                #pragma multi_compile _ _SHADOWS_SOFT // 阴影平滑开关
             
                half4 frag(Varyings input) : SV_Target
                {
                    // Light Info
                    float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                    #if defined(_MAIN_LIGHT_SHADOWS_CASCADE)
                        shadowCoord.w = ComputeCascadeIndex(input.positionWS);
                    #endif
                    Light mainLight = GetMainLight(shadowCoord);

                    // Texture Info
                    half4 albedoMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                    half4 normalMap = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv);
                    
                    // Normlize Vector
                    // TBN
                    float3 n = normalize(input.normalWS);
                    float3 t = normalize(input.tangentWS.xyz);
                    float3 b = cross(n, t) * input.tangentWS.w;
                    float3x3 TBN = float3x3(t, b, n);
                    
                    half3 normalTS = UnpackNormal(normalMap);
                    half3 normalWS = normalize(mul(normalTS, TBN));

                    // Albedo
                    half3 albedo = albedoMap.rgb * _BaseColor.rgb;

                    // Ambient
                    half3 ambient = SampleSH(normalWS) * albedo;

                    // Main Light
                    half3 finalColor = ambient + DirectLightLambert(mainLight, normalWS, albedo);

                    // Additional Light
                    int pixelLightCount = GetAdditionalLightsCount();
                    for (int i = 0; i < pixelLightCount; ++i)
                    {
                        Light addLight = GetAdditionalLight(i, input.positionWS);
                        finalColor += DirectLightLambert(addLight, normalWS, albedo);
                    }

                    return half4(finalColor, albedoMap.a);
                }
            
            ENDHLSL
        }

        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    //项目中用
    //FallBack "Universal Render Pipeline/Lit"
}
