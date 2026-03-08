Shader "Custom/ShaderBase/Chapter10/Mirror"
{
     Properties
    {
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _ReflectionTex("Reflection Texture", 2D) = "white" {}
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

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
            CBUFFER_END

            TEXTURE2D(_ReflectionTex);
            SAMPLER(sampler_ReflectionTex);

        ENDHLSL

        Pass
        {
            Name "Mirror"
            Tags {"LightMode" = "UniversalForward"}

            HLSLPROGRAM

                #pragma vertex vert
                #pragma fragment frag

                struct Attributes
                {
                    float4 positionOS : POSITION;
                    float3 normalOS : NORMAL;
                    float2 uv : TEXCOORD0;
                };

                struct Varyings
                {
                    float4 positionCS : SV_POSITION;
                    float2 uv : TEXCOORD0;
                    float4 screenPos : TEXCOORD1;
                    float3 normalWS : TEXCOORD2;
                    float3 viewDirWS : TEXCOORD3;
                };

                Varyings vert(Attributes input)
                {
                    Varyings output = (Varyings)0;

                    // position
                    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                    output.positionCS = vertexInput.positionCS;

                    // normal
                    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);
                    output.normalWS = normalInput.normalWS;

                    output.uv = input.uv;

                    output.screenPos = ComputeScreenPos(output.positionCS);

                    output.viewDirWS = GetWorldSpaceViewDir(vertexInput.positionWS);
                    
                    return output;
                }

                half4 frag(Varyings input) : SV_Target
                {
                    
                    float2 finalUV = (input.screenPos.xy / input.screenPos.w);

                    half4 reflection = SAMPLE_TEXTURE2D(_ReflectionTex, sampler_ReflectionTex, finalUV);
                    
                    half4 finalColor = reflection;

                    return finalColor;
                }
            ENDHLSL
        }
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    //项目中用
    //FallBack "Universal Render Pipeline/Lit"
}
