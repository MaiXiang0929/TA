Shader "Custom/ShaderBase/Chapter9/ForwardRendering"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
        _SpecularColor ("Specular Color", Color) = (1, 1, 1, 1)
        _Gloss ("Gloss", Range(8.0, 256)) = 20
    }
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque" 
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }

        HLSLINCLUDE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)

                float4 _BaseColor;
                float4 _SpecularColor;
                float _Gloss;

            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
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

                return output;
            }

            half3 DirectLightBP(Light light, half3 normalWS, half3 viewDirWS)
            {
                half3 lightDirWS = normalize(light.direction);
                half3 halfDirWS = normalize(viewDirWS + lightDirWS);

                // Diffuse
                float diff = saturate(dot(normalWS, lightDirWS));
                half3 diffuse = light.color * _BaseColor.rgb * diff;

                // Specular
                float spec = pow(saturate(dot(normalWS, halfDirWS)), _Gloss);
                half3 specular = light.color * _SpecularColor.rgb * spec;

                half3 blinnPhong = (diffuse + specular) * light.distanceAttenuation * light.shadowAttenuation;

                return blinnPhong;
            }

        ENDHLSL

        Pass // 主光照
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

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

                    // Normalize Vector
                    half3 normalWS = normalize(input.normalWS);
                    half3 viewDirWS = normalize(GetWorldSpaceViewDir(input.positionWS));

                    // Ambient
                    half3 ambient = SampleSH(normalWS) * _BaseColor.rgb;

                    // Main Light
                    half3 finalColor = ambient + DirectLightBP(mainLight, normalWS, viewDirWS);

                    // Additional Light
                    int pixelLightCount = GetAdditionalLightsCount();
                    for (int i = 0; i < pixelLightCount; ++i)
                    {
                        Light addLight = GetAdditionalLight(i, input.positionWS);
                        finalColor += DirectLightBP(addLight, normalWS, viewDirWS);
                    }
                    
                    return half4(finalColor, 1.0);
                }

            ENDHLSL
        }     
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    //项目中用
    //FallBack "Universal Render Pipeline/Lit"
}
