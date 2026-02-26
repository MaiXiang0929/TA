// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

Shader "Custom/ShaderBase/Chapter6/DiffuseVertexLevel"
{
    Properties
    {
        _Diffuse ("Diffuse", Color) = (1, 1, 1, 1)
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
            CBUFFER_END

        ENDHLSL

        Pass 
        {
            Tags { "LightMode"="UniversalForward" }
        
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
                float4 positionCS : POSITION;
                float3 color : COLOR;
            };

            Varyings vert(Attributes input) {
                Varyings output;
                
                VertexPositionInputs posInputs = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS);
                
                output.positionCS = posInputs.positionCS;
                
                // 逐顶点光照计算
                half3 ambient = SampleSH(normalInputs.normalWS);
                half3 normalWS = normalize(normalInputs.normalWS);

                Light light = GetMainLight();
                half3 lightDirWS = normalize(light.direction);
                
                half NdotL = saturate(dot(normalWS, lightDirWS));
                half3 diffuse = light.color * _Diffuse.rgb * NdotL;
                
                output.color = ambient + diffuse;

                return output;
                }

            half4 frag(Varyings input) : SV_Target {
                return float4(input.color, 1.0);
                }

            ENDHLSL
        }
    }
    FallBack "Universal Render Pipeline/Simple Lit"
}
