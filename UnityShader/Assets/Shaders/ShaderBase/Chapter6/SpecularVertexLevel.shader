// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

Shader "Custom/ShaderBase/Chapter6/SpecularVertexLevel"
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
                float3 color : COLOR;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;
                
                // 顶点位置变换到裁剪空间
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                
                // 获取世界空间法线
                float3 worldNormal = normalize(TransformObjectToWorldNormal(input.normalOS));
                
                // 获取主光源
                Light mainLight = GetMainLight();
                half3 lightColor = mainLight.color;

                // 环境光
                float3 ambient = SampleSH(worldNormal); 
                
                // 漫反射
                float3 worldLightDir = normalize(mainLight.direction);
                float3 diffuse = mainLight.color * _Diffuse.rgb * saturate(dot(worldNormal, worldLightDir));
                
                // 镜面反射 (Phong模型)
                float3 worldPos = TransformObjectToWorld(input.positionOS.xyz);
                float3 viewDir = normalize(GetWorldSpaceNormalizeViewDir(worldPos));
                float3 reflectDir = normalize(reflect(-worldLightDir, worldNormal));
                float3 specular = lightColor * _Specular.rgb * pow(saturate(dot(reflectDir, viewDir)), _Gloss);
                
                output.color = ambient + diffuse + specular;
                
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                return half4(input.color, 1.0);
            }

            ENDHLSL
        }
    }
    FallBack "Universal Render Pipeline/Simple Lit"
}
