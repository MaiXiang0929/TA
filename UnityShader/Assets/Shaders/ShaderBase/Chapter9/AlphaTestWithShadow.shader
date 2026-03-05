Shader "Custom/ShaderBase/Chapter9/AlphaTestWithShadow"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        _BaseMap ("Base Map", 2D) = "white" {}
        _SpecularColor ("Specular Color", Color) = (1, 1, 1, 1)
        _Gloss ("Gloss", Range(8.0, 256)) = 20
        _Cutoff ("Alpha Cutoff", Range(0, 1)) = 0.5
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "TransparentCutoff"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "AlphaTest"
        }

        HLSLINCLUDE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)

                float4 _BaseColor;
                float4 _BaseMap_ST;
                float4 _SpecularColor;
                float _Gloss;
                float _Cutoff;

            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float2 uv : TEXCOORD2;
            };

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                // position
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInput.positionCS;
                output.positionWS = vertexInput.positionWS;

                // normal
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);
                output.normalWS = normalInput.normalWS;

                // uv
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);

                return output;
            }

            half3 DirectLightBP(Light light, half3 normalWS, half3 viewDirWS, half3 albedo)
            {
                half3 lightDirWS = normalize(light.direction);
                half3 halfDirWS = normalize(viewDirWS + lightDirWS);

                // Diffuse
                float diff = saturate(dot(normalWS, lightDirWS));
                half3 diffuse = light.color * albedo * diff;

                // Specular
                float spec = pow(saturate(dot(normalWS, halfDirWS)), _Gloss);
                half3 specular = light.color * _SpecularColor.rgb * spec;

                half3 blinnPhong = (diffuse + specular) * light.distanceAttenuation * light.shadowAttenuation;

                return blinnPhong;
            }

        ENDHLSL
        
        Pass // Main Lighting
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}
            
            HLSLPROGRAM

                #pragma vertex vert
                #pragma fragment frag

                // URP 的附加光源多编译宏
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS // 主光源阴影开关
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE // 主光源级联阴影开关
                #pragma multi_compile _ _ADDITIONAL_LIGHTS // 像素级附加光照计算开关
                #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS // 附加光源阴影开关
                #pragma multi_compile _ _SHADOWS_SOFT // 阴影平滑开关

                half4 frag(Varyings input) : SV_Target
                {
                    // Light Info
                    float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                    Light mainLight = GetMainLight(shadowCoord);

                    // Texture Info
                    half4  baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);

                    // Normalize Vector
                    half3 normalWS = normalize(input.normalWS);
                    half3 viewDirWS = normalize(GetWorldSpaceViewDir(input.positionWS));

                    // Alpha Test
                    clip(baseMap.a - _Cutoff);

                    // Albedo
                    half4 albedo = baseMap * _BaseColor;

                    // Ambient
                    half3 ambient = SampleSH(normalWS) * albedo.rgb;


                    // Main Light
                    half3 finalColor = ambient + DirectLightBP(mainLight, normalWS, viewDirWS, albedo);

                    // Additional Light
                    int pixelLightCount = GetAdditionalLightsCount();
                    for (int i = 0; i < pixelLightCount; ++i)
                    {
                        Light addLight = GetAdditionalLight(i, input.positionWS);
                        finalColor += DirectLightBP(addLight, normalWS, viewDirWS, albedo);
                    }

                    return half4(finalColor, 1.0);
                }

            ENDHLSL
        }

        Pass // Shadow Caster
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            struct ShadowVaryings
            {
                float4 positionCS   : SV_POSITION;
                float2 uv           : TEXCOORD0; // 传递 UV
            };

            float3 _LightDirection;

            ShadowVaryings ShadowPassVertex(Attributes input)
            {
                ShadowVaryings output = (ShadowVaryings)0;

                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                
                // 使用 URP 专用的阴影偏移裁剪坐标计算
                output.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                return output;
            }

            half4 ShadowPassFragment(ShadowVaryings input) : SV_Target
            { 
                // 在阴影 Pass 中也要进行裁剪，否则影子是实心的
                float alpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a;
                clip(alpha - _Cutoff);
                return 0; 
            }

            ENDHLSL
        }
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    //项目中用
    //FallBack "Universal Render Pipeline/Lit"
}
