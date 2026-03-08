Shader "Custom/ShaderBase/Standard/BumpedSpecular"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        _BaseMap ("Albedo (RGB)", 2D) = "white" {}
        [Normal] _NormalMap ("Normal Map", 2D) = "bump" {}
        _SpecularColor ("Specular Color", Color) = (1, 1, 1, 1)
        _Gloss ("Gloss", Range(8.0, 256)) = 20
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
                float4 _SpecularColor;
                float _Gloss;
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


            half3 DirectLightBP(Light light, half3 normalWS, half3 viewDirWS, half3 abledo)
            {
                half3 lightDirWS = normalize(light.direction);
                half3 halfDirWS = normalize(viewDirWS + lightDirWS);

                // Diffuse
                float diff = saturate(dot(normalWS, lightDirWS));
                half3 diffuse = light.color * abledo * diff;

                // Specular
                float spec = pow(saturate(dot(normalWS, halfDirWS)), _Gloss);
                half3 specular = light.color * _SpecularColor.rgb * spec;

                half3 blinnPhong = (diffuse + specular) * light.distanceAttenuation * light.shadowAttenuation;

                return blinnPhong;
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
                    half3 viewDirWS = normalize(GetWorldSpaceViewDir(input.positionWS));

                    // Albedo
                    half3 albedo = albedoMap.rgb * _BaseColor.rgb;

                    // Ambient
                    half3 ambient = SampleSH(normalWS) * albedo;
                    
                    // Main Light
                    half3 finalColor = ambient + DirectLightBP(mainLight, normalWS, viewDirWS, albedo);

                    // Additional Light
                    int pixelLightCount = GetAdditionalLightsCount();
                    for (int i = 0; i < pixelLightCount; ++i)
                    {
                        Light addLight = GetAdditionalLight(i, input.positionWS);
                        finalColor += DirectLightBP(addLight, normalWS, viewDirWS, albedo);
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
