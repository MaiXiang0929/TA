// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

Shader "Custom/ShaderBase/Chapter6/SpecularPixelLevel"
{
     Properties
    {
        _Diffuse ("Diffuse", Color) = (1, 1, 1, 1)
        _Specular ("Specular", Color) = (1, 1, 1, 1)
        _Gloss ("Gloss", Range(8.0, 256)) = 20
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }

        HLSLINCLUDE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


            CBUFFER_START(UnityPerMaterial)

                float4 _Diffuse;
                float4 _Specular;
                float _Gloss;

            CBUFFER_END

        ENDHLSL

        Pass
        {
            Tags {"LightMode" = "UniversalForward"}

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

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
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);

                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                // 环境光
                half3 ambient = unity_AmbientSky.rgb;
                
                // 归一化法线
                half3 normalWS = normalize(input.normalWS);
                
                // 获取主光源信息
                Light mainLight = GetMainLight();
                half3 lightColor = mainLight.color;
                half3 lightDirWS = normalize(mainLight.direction);

                half3 diffuse = lightColor * _Diffuse.rgb * saturate(dot(normalWS, lightDirWS));

                half3 reflectDir = normalize(reflect(-lightDirWS, normalWS));
                half3 viewDir = normalize(_WorldSpaceCameraPos.xyz - input.positionWS);
                half3 specular = lightColor * _Specular.rgb * pow(saturate(dot(reflectDir, viewDir)), _Gloss);

                // 合并光照
                half3 finalColor = ambient + diffuse + specular;

                return float4(finalColor, 1.0);
            }

            ENDHLSL
        }
    }
    FallBack "Universal Render Pipeline/Simple Lit"
}
