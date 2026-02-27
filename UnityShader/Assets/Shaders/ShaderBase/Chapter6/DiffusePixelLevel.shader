// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

Shader "Custom/ShaderBase/Chapter6/DiffusePixelLevel"
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
                float4 positionCS : SV_POSITION;
                float3 normalWS : TEXCOORD0;
            };

            Varyings vert(Attributes input) 
            {
                Varyings output;

               // position
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInput.positionCS;

                // normal
                VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(input.normalOS);
                output.normalWS = vertexNormalInput.normalWS;

                return output;
            }

            half4 frag(Varyings input) : SV_Target 
            {
                Light light = GetMainLight();

                // Normalize Vector
                half3 N = normalize(input.normalWS);
                half3 L = normalize(light.direction);
                half NoL = dot(N, L);

                half3 ambient = SampleSH(N);

                half3 diffuse = light.color * _Diffuse.rgb * saturate(NoL);

                half3 color = ambient + diffuse;

                return float4(color, 1.0);
            }

            ENDHLSL
        }
    }
    FallBack "Universal Render Pipeline/Simple Lit"
}
